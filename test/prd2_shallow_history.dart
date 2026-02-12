import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

// Test types
enum MyState { root, a, a1, a11, a111, b }

enum MyEvent { toB, toAShallow, toA1Shallow }

void main() {
  late final Machine<MyState, MyEvent> hsm;
  setUp(() {
    final blueprint = MachineBlueprint<MyState, MyEvent>(
      root: .composite(
        id: .root,
        initial: .a111,
        on: {
          .toB: .new(target: .b),
          .toAShallow: .new(target: .a, history: .shallow),
          .toA1Shallow: .new(target: .a1, history: .shallow),
        },
        children: [
          .composite(id: .b),
          .composite(
            id: .a,
            children: [
              .composite(
                id: .a1,
                children: [
                  .composite(
                    id: .a11,
                    children: [.composite(id: .a111)],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    final (machine, errors) = blueprint.compile(observer: TestPrintObserver());
    print('errors: $errors');
    expect(errors, isEmpty);
    hsm = machine!;
    hsm.start();
  });

  test('shallow history taken from nested transition', () async {
    expect(hsm.getState(.a111)!.isActive, isTrue);
    await hsm.handle(.toB);
    expect(hsm.getState(.b)?.isActive, isTrue);
    expect(hsm.getState(.a)?.isActive, isFalse);
    expect(hsm.getState(.a1)?.isActive, isFalse);
    expect(hsm.getState(.a11)?.isActive, isFalse);
    expect(hsm.getState(.a111)?.isActive, isFalse);

    expect(hsm.stateString, 'State(MyState.root)/State(MyState.b)');

    await hsm.handle(.toA1Shallow);
    expect(hsm.getState(.b)?.isActive, isFalse);
    expect(hsm.getState(.a)?.isActive, isTrue);
    expect(hsm.getState(.a1)?.isActive, isTrue);
    expect(hsm.getState(.a11)?.isActive, isTrue);
    expect(hsm.getState(.a111)?.isActive, isFalse);
    expect(
      hsm.stateString,
      'State(MyState.root)/State(MyState.a)/State(MyState.a1)/State(MyState.a11)',
    );
  });
}
