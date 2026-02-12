import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

enum States {
  s,
  s1,
  s2,
  s21,
  s211,
  s212,
  s22,
  s221,
  s222,
  s3,
  s31,
  s32,
  fork,
  fork2,
  invalidFork,
}

enum Events { fork, fork2, invalidFork }

void main() {
  group('ForkState Semantics', () {
    test(
      'ForkState enters multiple orthogonal regions at specified states',
      () async {
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.s,
            initial: States.s1,
            children: [
              .composite(
                id: States.s1,
                on: {Events.fork: .new(target: States.fork)},
              ),
              .parallel(
                id: States.s2,
                children: [
                  .composite(
                    id: States.s21,
                    initial: States.s211,
                    children: [
                      .composite(id: States.s211),
                      .composite(id: States.s212),
                    ],
                  ),
                  .composite(
                    id: States.s22,
                    initial: States.s221,
                    children: [
                      .composite(id: States.s221),
                      .composite(id: States.s222),
                    ],
                  ),
                ],
              ),
              .fork(
                id: States.fork,
                transitions: [
                  .new(target: States.s212),
                  .new(target: States.s222),
                ],
              ),
            ],
          ),
        );

        final (machine, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        expect(machine, isNotNull);

        machine!.start();
        expect(
          machine.stateString,
          contains('State(States.s)/State(States.s1)'),
        );

        await machine.handle(Events.fork);

        // Should be in S2 and its orthogonal regions
        expect(machine.stateString, contains('ParallelState(States.s2)'));
        expect(
          machine.stateString,
          contains('State(States.s21)/State(States.s212)'),
        );
        expect(
          machine.stateString,
          contains('State(States.s22)/State(States.s222)'),
        );
      },
    );

    test('ForkState does not have to be parent to LCA', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.s,
          initial: States.s1,
          children: [
            .composite(
              id: States.s1,
              on: {Events.fork: .new(target: States.fork)},
              children: [
                .fork(
                  id: States.fork,
                  transitions: [
                    .new(target: States.s212),
                    .new(target: States.s222),
                  ],
                ),
              ],
            ),
            .parallel(
              id: States.s2,
              children: [
                .composite(
                  id: States.s21,
                  initial: States.s211,
                  children: [
                    .composite(id: States.s211),
                    .composite(id: States.s212),
                  ],
                ),
                .composite(
                  id: States.s22,
                  initial: States.s221,
                  children: [
                    .composite(id: States.s221),
                    .composite(id: States.s222),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      expect(errors, isEmpty);
      expect(machine, isNotNull);

      machine!.start();
      expect(machine.stateString, contains('State(States.s)/State(States.s1)'));

      await machine.handle(Events.fork);

      // Should be in S2 and its orthogonal regions
      expect(machine.stateString, contains('ParallelState(States.s2)'));
      expect(
        machine.stateString,
        contains('State(States.s21)/State(States.s212)'),
      );
      expect(
        machine.stateString,
        contains('State(States.s22)/State(States.s222)'),
      );
    });

    test(
      'Invalid fork (less than 2 targets) returns compilation error',
      () async {
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.s,
            children: [
              .parallel(
                id: States.s2,
                children: [.composite(id: States.s21)],
              ),
              .fork(
                id: States.invalidFork,
                transitions: [.new(target: States.s21)],
              ),
            ],
          ),
        );

        final (machine, errors) = machineDef.compile();
        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(
          errors.any(
            (e) =>
                e is ForkValidationError &&
                e.message.contains('at least two target transitions'),
          ),
          isTrue,
        );
      },
    );

    test(
      'Invalid fork (targets in same region) returns compilation error',
      () async {
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.s,
            children: [
              .parallel(
                id: States.s2,
                children: [
                  .composite(
                    id: States.s21,
                    children: [
                      .composite(id: States.s211),
                      .composite(id: States.s212),
                    ],
                  ),
                  .composite(
                    id: States.s22,
                    children: [.composite(id: States.s221)],
                  ),
                ],
              ),
              .fork(
                id: States.invalidFork,
                transitions: [
                  .new(target: States.s211),
                  .new(target: States.s212),
                  .new(target: States.s221),
                ],
              ),
            ],
          ),
        );

        final (machine, errors) = machineDef.compile();
        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(
          errors.any(
            (e) =>
                e is ForkValidationError &&
                e.message.contains(
                  'Multiple targets detected for the same orthogonal region',
                ),
          ),
          isTrue,
        );
      },
    );

    test('Invalid fork (LCA not Parallel) returns compilation error', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.s,
          children: [
            .composite(id: States.s1),
            .composite(id: States.s2),
            .fork(
              id: States.invalidFork,
              transitions: [
                .new(target: States.s1),
                .new(target: States.s2),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(machine, isNull);
      expect(errors, isNotEmpty);
      expect(
        errors.any(
          (e) =>
              e is ForkValidationError &&
              e.message.contains(
                'The Lowest Common Ancestor of all fork targets must be a ParallelState. Found:',
              ),
        ),
        isTrue,
      );
    });

    test('Nested Fork works correctly', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.s,
          initial: States.s1,
          children: [
            .composite(
              id: States.s1,
              on: {Events.fork: .new(target: States.fork)},
            ),
            .parallel(
              id: States.s2,
              children: [
                .composite(
                  id: States.s21,
                  initial: States.s211,
                  children: [.composite(id: States.s211)],
                ),
                .composite(
                  id: States.s22,
                  initial: States.s3,
                  children: [
                    .parallel(
                      id: States.s3,
                      children: [
                        .composite(id: States.s31),
                        .composite(id: States.s32),
                      ],
                    ),
                    .fork(
                      id: States.fork2,
                      transitions: [
                        .new(target: States.s31),
                        .new(target: States.s32),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            .fork(
              id: States.fork,
              transitions: [
                .new(target: States.s211),
                .new(target: States.fork2),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      expect(errors, isEmpty);
      expect(machine, isNotNull);

      machine!.start();
      await machine.handle(Events.fork);

      // Verify states
      expect(machine.stateString, contains('ParallelState(States.s2)'));
      expect(
        machine.stateString,
        contains('State(States.s21)/State(States.s211)'),
      );
      expect(
        machine.stateString,
        contains('State(States.s22)/ParallelState(States.s3)'),
      );
      expect(machine.stateString, contains('State(States.s31)'));
      expect(machine.stateString, contains('State(States.s32)'));
    });
  });
}
