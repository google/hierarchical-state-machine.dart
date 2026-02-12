import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

// Test types
enum MyState { root, s1, s2, finalS, parallel, r1, r2 }

enum MyEvent { e1, e2 }

void main() {
  group('PRD 2.0 Phase 4: Structural Integration', () {
    test('Complex state hierarchy with new schema components', () {
      final machineDef = MachineBlueprint<MyState, MyEvent>(
        name: 'test-machine',
        root: .composite(
          id: MyState.root,
          children: [
            .finish(id: .finalS),
            .parallel(
              id: .parallel,
              completion: [.new(target: .finalS, guard: () => true)],
              children: [
                .composite(id: .r1),
                .composite(id: .r2),
              ],
            ),
          ],
        ),
      );

      final (machine, errors) = machineDef.compile();
      expect(errors, isEmpty);
      expect(machine, isNotNull);

      final parallel = machine!.getState(.parallel);
      expect(parallel, isNotNull);
      expect(parallel!.parent?.id, MyState.root);

      final r1 = machine.getState(.r1);
      expect(r1!.parent?.id, MyState.parallel);
    });
  });
}
