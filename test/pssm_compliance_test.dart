import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

enum States {
  root,
  s1,
  s11,
  s12,
  s2,
  s21,
  s22,
  p,
  r1,
  r11,
  r12,
  r2,
  r21,
  r22,
  choice,
  targetA,
  targetB,
  fork,
  r211,
  r212,
  r121,
}

enum Events { e1, e2, toP, toS1, toS2, forkEvent, toRoot }

void main() {
  group('PSSM Compliance Tests', () {
    test('Initial Transition with Action', () async {
      var initialActionCalled = false;
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: .root,
          initial: .s1,
          initialAction: () => initialActionCalled = true,
          children: [.composite(id: .s1)],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(errors, isEmpty);
      machine!.start();

      expect(machine.getState(.s1)!.isActive, isTrue);
      expect(initialActionCalled, isTrue);
    });

    test('Initial Transition with Choice Chaining', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: .root,
          initial: .choice,
          on: {.toRoot: .new(target: .root, kind: .external)},
          children: [
            .choice(
              id: .choice,
              defaultTransition: .new(target: .targetA),
              options: [.new(target: .targetB, guard: (e, d) => d == 'B')],
            ),
            .composite(id: .targetA),
            .composite(id: .targetB),
          ],
        ),
      );

      // Scenario 1: Default choice
      final (hsm, _) = machineDef.compile();
      hsm!.start();
      expect(hsm.getState(.targetA)!.isActive, isTrue);
      await hsm.handle(.toRoot, 'B');
      expect(hsm.getState(.targetB)!.isActive, isTrue);
    });

    test('Fork with Mixed History (Deep and Shallow)', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: .root,
          initial: .s1,
          children: [
            .composite(
              id: .s1,
              on: {
                .forkEvent: .new(target: .fork),
                .toP: .new(target: .p),
              },
            ),
            .parallel(
              id: .p,
              on: {.toS1: .new(target: .s1)},
              children: [
                .composite(
                  id: .r1,
                  initial: .r11,
                  children: [
                    .composite(
                      id: .r11,
                      on: {.e1: .new(target: .r121)},
                    ),
                    .composite(
                      id: .r12,
                      children: [.composite(id: .r121)],
                    ),
                  ],
                ),
                .composite(
                  id: .r2,
                  initial: .r21,
                  children: [
                    .composite(
                      id: .r21,
                      initial: .r212,
                      children: [
                        .composite(id: .r211),
                        .composite(
                          id: .r212,
                          on: {.e2: .new(target: .r211)},
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            .fork(
              id: .fork,
              transitions: [
                .new(target: .r1, history: .shallow),
                .new(target: .r21, history: .deep),
              ],
            ),
          ],
        ),
      );

      final (hsm, errors) = machineDef.compile();
      expect(errors, isEmpty);
      hsm!.start();

      // 1. Setup: move to r12 and r211
      await hsm.handle(.toP);
      await hsm.handle(.e1); // r11 -> r12
      await hsm.handle(.e2); // r212 -> r211
      expect(hsm.getState(.r12)!.isActive, isTrue);
      expect(hsm.getState(.r121)!.isActive, isTrue);
      expect(hsm.getState(.r211)!.isActive, isTrue);

      // 2. Exit parallel state
      await hsm.handle(.toS1);
      expect(hsm.getState(.p)!.isActive, isFalse);

      // 3. Re-enter via Fork with mixed history
      await hsm.handle(.forkEvent);
      expect(hsm.getState(.p)!.isActive, isTrue);
      expect(
        hsm.getState(.r12)!.isActive,
        isTrue,
        reason: 'r1 shallow history should restore r12',
      );
      expect(
        hsm.getState(.r121)!.isActive,
        isFalse,
        reason: 'r1 shallow will not restore r121',
      );

      expect(
        hsm.getState(.r211)!.isActive,
        isTrue,
        reason: 'r21 deep history should restore r211',
      );
    });

    test('Inner vs Outer Transition Priority', () async {
      var innerCalled = false;
      var outerCalled = false;

      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: .root,
          initial: .s1,
          on: {Events.e1: .new(action: (e, d) => outerCalled = true)},
          children: [
            .composite(
              id: .s1,
              on: {Events.e1: .new(action: (e, d) => innerCalled = true)},
            ),
          ],
        ),
      );

      final (machine, _) = machineDef.compile();
      machine!.start();

      await machine.handle(Events.e1);

      expect(
        innerCalled,
        isTrue,
        reason: 'Inner handler should take precedence',
      );
      expect(outerCalled, isFalse, reason: 'Outer handler should be shadowed');
    });
  });
}
