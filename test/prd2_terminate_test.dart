import 'package:test/test.dart';
import 'package:hierarchical_state_machine/src/machine.dart'; // For internal verification
import 'test_observer.dart';

enum Events { terminate, deferMe, next }

enum States { root, s1, s11, s111, t1 }

void main() {
  group('TerminateState Semantics', () {
    test('Entering TerminateState stops the machine immediately', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.s1,
          children: [
            .composite(
              id: States.s1,
              on: {Events.terminate: .new(target: States.t1)},
            ),
            .terminate(id: States.t1),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      expect(machine.isRunning, isTrue);

      await machine.handle(Events.terminate);

      expect(machine.isRunning, isFalse);
    });

    test(
      'Entering TerminateState does call onExit and onEnter handlers',
      () async {
        var s1ExitCalled = false;
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.root,
            initial: States.s1,
            children: [
              .composite(
                id: States.s1,
                exit: () => s1ExitCalled = true,
                on: {Events.terminate: .new(target: States.t1)},
              ),
              .terminate(id: States.t1),
            ],
          ),
        );

        final (machine, _) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        machine!.start();
        await machine.handle(Events.terminate);

        expect(s1ExitCalled, isTrue);
      },
    );

    test('Termination clears all history and deferrals', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.s1,
          children: [
            .composite(
              id: States.s1,
              initial: States.s11,
              on: {Events.terminate: .new(target: States.t1)},
              children: [
                .composite(
                  id: States.s11,
                  initial: States.s111,
                  children: [
                    .composite(id: States.s111, defer: {Events.deferMe}),
                  ],
                ),
              ],
            ),
            .terminate(id: States.t1),
          ],
        ),
      );

      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();

      // Defer an event in s111
      await machine.handle(Events.deferMe);
      final s111Internal = machine.getState(States.s111) as State;
      expect(s111Internal.deferredQueue, isNotEmpty);

      // Verify history is set
      final rootInternal = machine.getState(States.root) as State;
      final s1Internal = machine.getState(States.s1) as State;
      final s11Internal = machine.getState(States.s11) as State;

      expect(rootInternal.history, isNotNull);
      expect(s1Internal.history, isNotNull);
      expect(s11Internal.history, isNotNull);

      // Transition to TerminateState
      await machine.handle(Events.terminate);

      expect(machine.isRunning, isFalse);

      // Verify deferrals are cleared
      expect(s111Internal.deferredQueue, isEmpty);

      // Verify history is cleared across the machine
      expect(rootInternal.history, isNull);
      expect(s1Internal.history, isNull);
      expect(s11Internal.history, isNull);
      expect(s111Internal.history, isNull);
    });

    test(
      'Machine.onTerminated is called when reaching TerminateState',
      () async {
        var terminatedCalled = false;
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.root,
            initial: States.s1,
            children: [
              .composite(
                id: States.s1,
                on: {Events.terminate: .new(target: States.t1)},
              ),
              .terminate(id: States.t1),
            ],
          ),
        );

        final (machine, _) = machineDef.compile(
          onTerminated: () => terminatedCalled = true,
          observer: const TestPrintObserver(),
        );
        machine!.start();
        await machine.handle(Events.terminate);

        expect(terminatedCalled, isTrue);
      },
    );
  });
}
