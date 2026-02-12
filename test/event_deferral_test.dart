import 'package:hierarchical_state_machine/src/machine.dart'; // For internal verification
import 'package:test/test.dart';
import 'test_observer.dart';

void main() {
  group('Event Deferral', () {
    test('basic deferral', () async {
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'a',
          on: {'event1': .new(target: 'b')},
          children: [
            .composite(id: 'a', defer: {'event1'}),
            .composite(id: 'b'),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      expect(machine.stateString, contains('State(a)'));

      // When 'event1' is handled, 'a' should defer it because it's active.
      final handled = await machine.handle('event1');

      // If deferred, it should NOT have transitioned to 'b' yet.
      expect(handled, isTrue); // It was "handled" by deferral
      expect(machine.stateString, contains('State(a)'));

      final aInternal = machine.getState('a') as State;
      expect(aInternal.deferredQueue.length, 1);
      expect(aInternal.deferredQueue.first.event, 'event1');
    });

    test('ParallelState coordination: handle wins over defer', () async {
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'p',
          children: [
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1', defer: {'event1'}),
                .composite(
                  id: 'r2',
                  on: {'event1': .new(action: (e, d) {})},
                ),
              ],
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      expect(await machine.handle('event1'), isTrue);

      final r1Internal = machine.getState('r1') as State;
      // Since r2 handled it, r1's deferral should have been cancelled/removed.
      expect(r1Internal.deferredQueue, isEmpty);
    });

    test('ParallelState coordination: all deferrals get stored', () async {
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'p',
          children: [
            .parallel(
              id: 'p',
              children: [
                .composite(id: 'r1', defer: {'event1'}),
                .composite(id: 'r2', defer: {'event1'}),
              ],
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      await machine.handle('event1');

      final r1Internal = machine.getState('r1') as State;
      final r2Internal = machine.getState('r2') as State;
      expect(r1Internal.deferredQueue, hasLength(1));
      expect(r2Internal.deferredQueue, hasLength(1));
    });

    test('event replay on exit', () async {
      var handleCount = 0;
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'a',
          children: [
            .composite(
              id: 'a',
              defer: {'event1'},
              on: {'go_to_b': .new(target: 'b')},
            ),
            .composite(
              id: 'b',
              on: {'event1': .new(action: (e, d) => handleCount++)},
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      // 1. Defer 'event1'
      await machine.handle('event1');
      expect(handleCount, 0);

      // 2. Trigger transition to 'b'. 'event1' should be replayed and handled.
      await machine.handle('go_to_b');

      await machine.settled;

      expect(machine.stateString, contains('State(b)'));
      expect(handleCount, 1, reason: 'event1 should have been replayed once');
    });

    test('parallel deferrals only replay once', () async {
      var handleCount = 0;
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'p',
          children: [
            .parallel(
              id: 'p',
              on: {'go_to_b': .new(target: 'b')},
              children: [
                .composite(id: 'r1', defer: {'event1'}),
                .composite(id: 'r2', defer: {'event1'}),
              ],
            ),
            .composite(
              id: 'b',
              on: {'event1': .new(action: (e, d) => handleCount++)},
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      // 1. Defer 'event1'
      await machine.handle('event1');

      // 2. Transition out
      await machine.handle('go_to_b');

      await machine.settled;

      expect(machine.stateString, contains('State(b)'));
      expect(handleCount, 1, reason: 'event1 should only replay once');
    });

    test('parallel deferrals only stack once', () async {
      var handleCount = 0;
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'p',
          children: [
            .parallel(
              id: 'p',
              on: {'go_to_b': .new(target: 'b')},
              children: [
                .composite(
                  id: 'r1',
                  initial: 'S1_Defer',
                  children: [
                    .composite(
                      id: 'S1_Defer',
                      defer: {'event1'},
                      on: {'step_1': .new(target: 'S1_Done')},
                    ),
                    .composite(id: 'S1_Done'),
                  ],
                ),
                .composite(id: 'r2', defer: {'event1'}),
              ],
            ),
            .composite(
              id: 'b',
              on: {'event1': .new(action: (e, d) => handleCount++)},
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      // 1. Defer 'event1'
      await machine.handle('event1');

      await machine.handle('step_1');
      expect(handleCount, 0, reason: 'Event should be re-deferred by R2');

      final r2Internal = machine.getState('r2') as State;
      expect(r2Internal.deferredQueue, hasLength(1));

      // 2. Transition out
      await machine.handle('go_to_b');

      await machine.settled;

      expect(machine.stateString, contains('State(b)'));
      expect(
        handleCount,
        1,
        reason: 'Event should be handled exactly once after final exit',
      );
    });

    test(
      're-deferral: replayed events can be deferred again by new state',
      () async {
        var handleCount = 0;
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            initial: 'a',
            children: [
              .composite(
                id: 'a',
                defer: {'e1'},
                on: {'go_to_b': .new(target: 'b')},
              ),
              .composite(
                id: 'b',
                defer: {'e1'},
                on: {'go_to_c': .new(target: 'c')},
              ),
              .composite(
                id: 'c',
                on: {'e1': .new(action: (e, d) => handleCount++)},
              ),
            ],
          ),
        );

        final (machine, _) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        machine!.start();

        await machine.handle('e1');
        expect(handleCount, 0, reason: 'Deferred in a');

        await machine.handle('go_to_b');
        await machine.settled;
        expect(
          handleCount,
          0,
          reason: 'Replayed but immediately deferred in b',
        );

        await machine.handle('go_to_c');
        await machine.settled;
        expect(handleCount, 1, reason: 'Replayed and finally handled in c');
      },
    );

    test('Transitions have precedence over deferral', () async {
      final records = <int>[];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'A',
          children: [
            .composite(
              id: 'A',
              defer: {'event1'},
              on: {
                'event1': .new(
                  guard: (e, d) => (d as int) > 10,
                  action: (e, d) {
                    records.add(d as int);
                  },
                  target: 'B',
                ),
              },
            ),
            .composite(
              id: 'B',
              on: {
                'event1': .new(
                  action: (e, d) {
                    records.add(d as int);
                  },
                ),
              },
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      // 1. Send (event1, 1). Guard > 10 fails, so it should be deferred.
      await machine.handle('event1', 1);
      expect(records, isEmpty);

      // 2. Send (event1, 11). Guard > 10 passes, should handle and transition.
      // Transition out of A triggers replay of (event1, 1).
      await machine.handle('event1', 11);

      await machine.settled;

      expect(machine.stateString, contains('State(B)'));
      // records should have 11 (from A transition action) then 1 (from B replaying deferred event)
      expect(records, [11, 1]);
    });
  });
}
