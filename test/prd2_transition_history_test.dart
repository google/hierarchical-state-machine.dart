import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

// Test types
enum MyState { root, s1, s11, s111, s112, s12, s121, s2 }

enum MyEvent {
  e1,
  e2,
  toS1,
  toS11,
  toS112,
  toS1HistoryShallow,
  toS1HistoryDeep,
}

void main() {
  group('PRD 2.0: Transition History Logic', () {
    late Machine<MyState, MyEvent> machine;

    setUp(() {
      final machineDef = MachineBlueprint<MyState, MyEvent>(
        name: 'history-test',
        root: .composite(
          id: MyState.root,
          on: {
            MyEvent.toS1: .new(target: MyState.s1),
            MyEvent.toS11: .new(target: MyState.s11),
            MyEvent.toS112: .new(target: MyState.s112),
            MyEvent.toS1HistoryShallow: .new(
              target: MyState.s1,
              history: HistoryType.shallow,
            ),
            MyEvent.toS1HistoryDeep: .new(
              target: MyState.s1,
              history: HistoryType.deep,
            ),
          },
          children: [
            .composite(
              id: MyState.s1,
              initial: MyState.s12,
              on: {
                MyEvent.e1: .new(target: MyState.s2),
                MyEvent.e2: .new(target: MyState.s11),
              },
              children: [
                .composite(
                  id: MyState.s11,
                  initial: MyState.s111,
                  children: [
                    .composite(id: MyState.s111),
                    .composite(id: MyState.s112),
                  ],
                ),
                .composite(id: MyState.s12),
              ],
            ),
            .composite(id: MyState.s2),
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

    test(
      'Shallow history restores direct child but follows child initialState',
      () async {
        // 1. Transition to s112
        await machine.handle(MyEvent.toS112);
        expect(
          machine.stateString,
          contains('s1)/State(MyState.s11)/State(MyState.s112)'),
        );

        // 2. Exit s1 to s2
        await machine.handle(MyEvent.e1);
        expect(machine.stateString, contains('s2)'));

        // 3. Re-enter s1 with Shallow History
        // Since history is shallow, it should restore s11 (the last active direct child).
        // and then follow s11's initialState to s111.
        await machine.handle(MyEvent.toS1HistoryShallow);

        expect(
          machine.stateString,
          contains('s1)/State(MyState.s11)/State(MyState.s111)'),
        );
      },
    );

    test('Deep history restores full recursive path', () async {
      // 1. Transition to s112
      await machine.handle(MyEvent.toS112);
      expect(
        machine.stateString,
        contains('s1)/State(MyState.s11)/State(MyState.s112)'),
      );

      // 2. Exit s1 to s2
      await machine.handle(MyEvent.e1);
      expect(machine.stateString, contains('s2)'));

      // 3. Re-enter s1 with Deep History
      // Should go to travrse to s112
      await machine.handle(MyEvent.toS1HistoryDeep);

      expect(
        machine.stateString,
        contains('s1)/State(MyState.s11)/State(MyState.s112)'),
      );
    });
    group('History Recording', () {
      test('History is only recorded when historyEnabled is true', () async {
        // s12 is NOT history enabled
        await machine.handle(MyEvent.toS1); // Goes to s1 -> s12 (initial)
        expect(machine.stateString, contains('s1)/State(MyState.s12)'));

        await machine.handle(MyEvent.e1); // Exit s1

        // Since s1 is history enabled, it should have recorded s12.
        // Wait, history records are updated on EXIT.
      });
    });
  });
}
