// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'test_observer.dart';

enum States {
  root,
  wait,
  s1,
  // Region 1
  s1_r1,
  s1_1,
  // Region 2
  s1_r2,
  s1_2,
  // Region 3
  s1_r3,
  s1_3,

  // Fork 002
  s1_1_nested,
  s1_1_rA,
  s1_1_1,
  s1_1_rB,
  s1_2_1,

  fork,
}

enum Events { start }

void main() {
  group('PSSM Fork Tests', () {
    test('Fork 001: Mixed Explicit and Default Entry', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.wait,
          children: [
            .composite(
              id: States.wait,
              on: {Events.start: .new(target: States.fork)},
            ),
            .parallel(
              id: States.s1,
              children: [
                .composite(
                  id: States.s1_r1,
                  children: [.composite(id: States.s1_1)],
                ),
                .composite(
                  id: States.s1_r2,
                  children: [.composite(id: States.s1_2)],
                ),
                .composite(
                  id: States.s1_r3,
                  initial: States.s1_3,
                  children: [.composite(id: States.s1_3)],
                ),
              ],
            ),
            .fork(
              id: States.fork,
              transitions: [
                .new(target: States.s1_1),
                .new(target: States.s1_2),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      expect(errors, isEmpty);
      machine!.start();

      await machine.handle(Events.start);

      // Assert
      expect(machine.stateString, contains('State(States.s1_1)'));
      expect(machine.stateString, contains('State(States.s1_2)'));
      expect(machine.stateString, contains('State(States.s1_3)'));
      expect(machine.stateString, contains('ParallelState(States.s1)'));
    });

    test('Fork 002: Deeply Nested Fork Targets', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.wait,
          children: [
            .composite(
              id: States.wait,
              on: {Events.start: .new(target: States.fork)},
            ),
            .composite(
              id: States.s1,
              initial: States.s1_1_nested,
              children: [
                .parallel(
                  id: States.s1_1_nested,
                  children: [
                    .composite(
                      id: States.s1_1_rA,
                      children: [.composite(id: States.s1_1_1)],
                    ),
                    .composite(
                      id: States.s1_1_rB,
                      children: [.composite(id: States.s1_2_1)],
                    ),
                  ],
                ),
                .fork(
                  id: States.fork,
                  transitions: [
                    .new(target: States.s1_1_1),
                    .new(target: States.s1_2_1),
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
      machine!.start();

      await machine.handle(Events.start);

      // Assert
      expect(machine.getState(States.wait)!.isActive, isFalse);
      expect(
        machine.stateString,
        contains('ParallelState(States.s1_1_nested)'),
      );
      expect(machine.stateString, contains('State(States.s1_1_1)'));
      expect(machine.stateString, contains('State(States.s1_2_1)'));
    });
  });
}
