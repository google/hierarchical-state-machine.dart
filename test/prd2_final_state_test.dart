import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

enum Events { next, stop }

enum States { root, s1, f1, s2 }

enum ComplexStates { root, s1, s11, s111, s1final, s2, s21 }

void main() {
  group('FinalState Semantics (Phase 1)', () {
    test(
      'FinalState entry triggers CompletionHandler in Composite State',
      () async {
        final machineDef = MachineBlueprint<States, Events>(
          root: .composite(
            id: States.root,
            initial: States.s1,
            completion: [.new(target: States.s2)],
            children: [
              .composite(
                id: States.s1,
                on: {Events.stop: .new(target: States.f1)},
              ),
              .finish(id: States.f1),
              .composite(id: States.s2),
            ],
          ),
        );

        final (machine, errors) = machineDef.compile();
        expect(errors, isEmpty);
        machine!.start();

        expect(machine.getState(States.s1)!.isActive, isTrue);

        await machine.handle(Events.stop);

        // Should automatically move to s2
        expect(machine.getState(States.s2)!.isActive, isTrue);
      },
    );

    test('CompletionHandler guard blocks transition', () async {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.root,
          initial: States.s1,
          completion: [.new(target: States.s2, guard: () => false)],
          children: [
            .composite(
              id: States.s1,
              on: {Events.stop: .new(target: States.f1)},
            ),
            .finish(id: States.f1),
            .composite(id: States.s2),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(errors, isEmpty);
      machine!.start();
      await machine.handle(Events.stop);

      // Should stay in f1 because completion transition was guarded
      expect(machine.getState(States.f1)!.isActive, isTrue);
    });

    // History and cleanup of history on final state is an internal detail,
    // but we can verify it via machine's internal state if we import it.
    // However, let's focus on public observable behavior first.
    // Prd 2.1 says entering FinalState clears history.
  });
}
