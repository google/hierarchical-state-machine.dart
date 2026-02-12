import 'package:hierarchical_state_machine/src/machine.dart';
import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

// Test types
enum MyState { root, p, a, a1, a2, a2_1, a2_2, b, b1, b2, idle }

enum MyEvent {
  toPDeep,
  toBDeep,
  toA2Shallow,
  toPB2,
  toA2,
  toA2_2,
  toB2,
  toIdle,
}

void main() {
  group('PRD 2.0: Parallel State History', () {
    late Machine<MyState, MyEvent> hsm;

    setUp(() {
      final machineDef = MachineBlueprint<MyState, MyEvent>(
        name: 'parallel-history',
        root: .composite(
          id: .root,
          initial: .p,
          on: {
            .toIdle: .new(target: .idle),
            .toPDeep: .new(target: .p, history: .deep),
            .toBDeep: .new(target: .b, history: .deep),
            .toA2Shallow: .new(target: .a2, history: .shallow),
            .toPB2: .new(target: .b2),
          },
          children: [
            .parallel(
              id: .p,
              children: [
                .composite(
                  id: .a,
                  initial: .a1,
                  on: {
                    .toA2: .new(target: .a2),
                    .toA2_2: .new(target: .a2_2),
                  },
                  children: [
                    .composite(id: .a1),
                    .composite(
                      id: .a2,
                      initial: .a2_1,
                      children: [
                        .composite(id: .a2_1),
                        .composite(id: .a2_2),
                      ],
                    ),
                  ],
                ),
                .composite(
                  id: .b,
                  initial: .b1,
                  on: {.toB2: .new(target: .b2)},
                  children: [
                    .composite(id: .b1),
                    .composite(id: .b2),
                  ],
                ),
              ],
            ),
            .composite(id: .idle),
          ],
        ),
      );

      final (compiled, errors) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      expect(errors, isEmpty);
      hsm = compiled!;
      hsm.start();
    });

    // Helper to reach configuration: {P, A:{A2:{A2_2}}, B:{B2}}
    Future<void> setupActiveConfig() async {
      // Move region A A2_2
      await hsm.handle(.toA2_2);
      // Move region B to B2
      await hsm.handle(.toB2);

      expect(hsm.stateString, contains('State(MyState.a2_2)'));
      expect(hsm.stateString, contains('State(MyState.b2)'));
    }

    test('Deep history restores full recursive state (A2_2, B2)', () async {
      await setupActiveConfig();

      // Exit to Idle
      await hsm.handle(.toIdle);
      expect(hsm.stateString, contains('State(MyState.idle)'));

      // Return with Deep History
      await hsm.handle(.toPDeep);

      // Expect P->A->A2->A2_2 AND P->B->B2
      expect(hsm.stateString, contains('State(MyState.a2_2)'));
      expect(hsm.stateString, contains('State(MyState.b2)'));
    });

    test('Shallow history to A2 restores A2_2', () async {
      await setupActiveConfig();

      // Exit to Idle - reset state
      await hsm.handle(.toIdle);
      expect(hsm.stateString, 'State(MyState.root)/State(MyState.idle)');

      // Now return to A2's shallow history - b will take the default path
      await hsm.handle(.toA2Shallow);

      expect(
        hsm.stateString,
        contains('State(MyState.a)/State(MyState.a2)/State(MyState.a2_1)'),
      );
      expect(
        hsm.stateString,
        contains('State(MyState.b)/State(MyState.b1)'),
        reason: 'b initial path taken to b1',
      );
    });

    test('Deep history on B restores B2', () async {
      await setupActiveConfig();

      // Exit to Idle - reset state
      await hsm.handle(.toIdle);
      expect(hsm.stateString, 'State(MyState.root)/State(MyState.idle)');

      // Now return to B's deep history - a will take the default path
      await hsm.handle(.toBDeep);

      /// STILL BAD: Now we have state == a2/a2_2, which is very wrong
      expect(
        hsm.stateString,
        contains('State(MyState.b)/State(MyState.b2)'),
        reason: 'b initial path taken to b2',
      );
      expect(
        hsm.stateString,
        contains('State(MyState.a)/State(MyState.a1)'),
        reason: 'a initial path taken for A',
      );
      expect(hsm.getState(.b2)?.isActive, isTrue);
    });

    test(
      'Transition to explicit sibling (B2) resets other region (A1)',
      () async {
        await setupActiveConfig();

        // Exit to Idle
        await hsm.handle(.toIdle);

        // Transition directly to B2
        await hsm.handle(.toPB2);

        // Region B should be B2 (explicit)
        expect(hsm.stateString, contains('State(MyState.b2)'));

        // Region A should be A1 (implicit default)
        // Because we didn't specify history for A, and we didn't target A.
        expect(hsm.stateString, contains('State(MyState.a1)'));
      },
    );
  });

  group('Parallel shallow target are illegal for', () {
    test('transitions', () {
      final def = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          on: {
            'deep': .new(target: 'p', history: .deep),
            'shallow': .new(target: 'p', history: .shallow),
          },
          children: [
            .composite(id: 'a'),
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1'),
                .composite(id: 'r2'),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = def.compile();
      expect(machine, isNull);
      expect(
        errors.toString(),
        '[ValidationError: Transition "root -> p" validation failed: cannot target parallel state with shallow history]',
      );
    });

    test('choice', () {
      final def = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          children: [
            .choice(
              id: 'c',
              defaultTransition: .new(target: 'p', history: .shallow),
              options: [.new(target: 'p', history: .shallow)],
            ),
            .composite(id: 'a'),
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1'),
                .composite(id: 'r2'),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = def.compile();
      expect(machine, isNull);
      expect(
        errors.toString(),
        '[ValidationError: Transition "c -> p" validation failed: choice default transition cannot target parallel state with shallow history,'
        ' ValidationError: Transition "c -> p" validation failed: choice optional transition cannot target parallel state with shallow history]',
      );
    });

    test('forks', () {
      final def = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          children: [
            .fork(
              id: 'c',
              transitions: [.new(target: 'p', history: .shallow)],
            ),
            .composite(id: 'a'),
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1'),
                .composite(id: 'r2'),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = def.compile();
      expect(machine, isNull);
      expect(
        errors.toString(),
        contains(
          'ValidationError: Transition "c -> p" validation failed: fork transition cannot target parallel state with shallow history',
        ),
      );
    });

    test('completions', () {
      final def = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          children: [
            .composite(
              id: 'a',
              completion: [.new(target: 'p', history: .shallow)],
            ),
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1'),
                .composite(id: 'r2'),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = def.compile();
      expect(machine, isNull);
      expect(
        errors.toString(),
        contains(
          'ValidationError: Transition "a -> p" validation failed: completion cannot target parallel state with shallow history',
        ),
      );
    });
  });
}
