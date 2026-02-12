import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

// Test types
enum MyState { root, a1, choice, targetB, targetD }

enum MyEvent { e1 }

void main() {
  group('PRD 2.0: ChoiceState Logic', () {
    late Machine<MyState, MyEvent> machine;
    int counter = 0;

    setUp(() {
      counter = 0;
      final machineDef = MachineBlueprint<MyState, MyEvent>(
        name: 'choice-test',
        root: .composite(
          id: MyState.root,
          initial: MyState.a1,
          children: [
            .composite(
              id: MyState.a1,
              on: {MyEvent.e1: .new(target: MyState.choice)},
            ),
            .composite(id: MyState.targetB),
            .composite(id: MyState.targetD),
            .choice(
              id: MyState.choice,
              defaultTransition: .new(
                target: MyState.targetD,
                action: (e, d) => counter++,
              ),
              options: [
                .new(target: MyState.targetB, guard: (e, d) => (d as int) > 10),
              ],
            ),
          ],
        ),
      );

      final (compiled, errors) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      expect(errors, isEmpty);
      machine = compiled!;
      machine.start();
    });

    test('Case 1: Dynamic Guard Selection (Happy Path)', () async {
      // 1. Start in A1
      expect(machine.stateString, contains('State(MyState.a1)'));

      // 2. Dispatch E1 with value 20 (> 10)
      await machine.handle(MyEvent.e1, 20);

      // 3. Should end up in TargetB
      expect(machine.stateString, contains('State(MyState.targetB)'));
      expect(counter, equals(0));
    });

    test('Case 2: Fallback to Default (Else Behavior)', () async {
      // 1. Start in A1
      expect(machine.stateString, contains('State(MyState.a1)'));

      // 2. Dispatch E1 with value 5 (<= 10)
      await machine.handle(MyEvent.e1, 5);

      // 3. Should end up in TargetD (Default)
      expect(machine.stateString, contains('State(MyState.targetD)'));
      // The default handler has the action attached
      expect(counter, equals(1));
    });
  });
}
