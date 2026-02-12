import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

enum Events { toF1, toF2, toF3, toF4 }

enum States {
  root,
  p,
  r1,
  r1s1,
  r1f1,
  r2,
  r2s1,
  r2f1,
  next,
  p2,
  r3,
  r3s1,
  r3f1,
  r4,
  r4s1,
  r4f1,
}

void main() {
  group('ParallelState Completion (Phase 2)', () {
    test('ParallelState completes only when all regions are final', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.p,
          children: [
            .parallel(
              id: States.p,
              completion: [.new(target: States.next)],
              children: [
                .composite(
                  id: States.r1,
                  initial: States.r1s1,
                  children: [
                    .composite(
                      id: States.r1s1,
                      on: {Events.toF1: .new(target: States.r1f1)},
                    ),
                    .finish(id: States.r1f1),
                  ],
                ),
                .composite(
                  id: States.r2,
                  initial: States.r2s1,
                  children: [
                    .composite(
                      id: States.r2s1,
                      on: {Events.toF2: .new(target: States.r2f1)},
                    ),
                    .finish(id: States.r2f1),
                  ],
                ),
              ],
            ),
            .composite(id: States.next),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(errors, isEmpty);
      machine!.start();

      // Initial state: p is active, r1s1 and r2s1 are active.
      expect(machine.stateString, contains('ParallelState(States.p)'));
      expect(machine.stateString, contains('State(States.r1s1)'));
      expect(machine.stateString, contains('State(States.r2s1)'));

      // Move R1 to final
      await machine.handle(Events.toF1);
      expect(machine.stateString, contains('FinalState(States.r1f1)'));
      expect(machine.stateString, contains('State(States.r2s1)'));
      expect(machine.stateString, contains('ParallelState(States.p)'));

      // Move R2 to final
      await machine.handle(Events.toF2);

      // Now both are final. p should complete and transition to next.
      expect(machine.stateString, contains('State(States.next)'));
    });

    test('Nested ParallelStates complete correctly', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.p,
          children: [
            .parallel(
              id: States.p,
              completion: [.new(target: States.next)],
              children: [
                .composite(
                  id: States.r1,
                  initial: States.r1s1,
                  children: [
                    .composite(
                      id: States.r1s1,
                      on: {Events.toF1: .new(target: States.r1f1)},
                    ),
                    .finish(id: States.r1f1),
                  ],
                ),
                .parallel(
                  id: States.p2,
                  children: [
                    .composite(
                      id: States.r3,
                      initial: States.r3s1,
                      children: [
                        .composite(
                          id: States.r3s1,
                          on: {Events.toF3: .new(target: States.r3f1)},
                        ),
                        .finish(id: States.r3f1),
                      ],
                    ),
                    .composite(
                      id: States.r4,
                      initial: States.r4s1,
                      children: [
                        .composite(
                          id: States.r4s1,
                          on: {Events.toF4: .new(target: States.r4f1)},
                        ),
                        .finish(id: States.r4f1),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            .composite(id: States.next),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(errors, isEmpty);
      machine!.start();

      // All active
      expect(machine.stateString, contains('State(States.r1s1)'));
      expect(machine.stateString, contains('State(States.r3s1)'));
      expect(machine.stateString, contains('State(States.r4s1)'));

      // 1. Move R1 to final. P1 not complete.
      await machine.handle(Events.toF1);
      expect(machine.stateString, contains('FinalState(States.r1f1)'));
      expect(machine.stateString, contains('ParallelState(States.p)'));

      // 2. Move R3 to final. P2 not complete, P1 not complete.
      await machine.handle(Events.toF3);
      expect(machine.stateString, contains('FinalState(States.r3f1)'));
      expect(machine.stateString, contains('ParallelState(States.p2)'));
      expect(machine.stateString, contains('ParallelState(States.p)'));

      // 3. Move R4 to final. P2 completes! P1 completes!
      await machine.handle(Events.toF4);

      // Transition to next should have happened
      expect(machine.stateString, contains('State(States.next)'));
    });
  });
}
