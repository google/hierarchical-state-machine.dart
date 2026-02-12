import 'package:hierarchical_state_machine/src/machine.dart';
import 'package:test/test.dart';

void main() {
  group('Initial State Validation', () {
    test('reports error when initial state is not found', () {
      final blueprint = MachineBlueprint<String, String>(
        name: 'InvalidMachine',
        root: .composite(
          id: 'root',
          initial: 'missing',
          children: [.composite(id: 'a')],
        ),
      );

      final (machine, errors) = blueprint.compile();

      expect(machine, isNull);
      expect(errors, hasLength(1));
      expect(errors.first, isA<MissingStateError>());
      expect(
        errors.first.message,
        contains('Missing state "missing" in initial state of state "root"'),
      );
    });

    test('reports error when initial state is not a descendant', () {
      final blueprint = MachineBlueprint<String, String>(
        name: 'InvalidMachine',
        root: .composite(
          id: 'root',
          initial: 'sibling',
          children: [
            .composite(
              id: 'parent',
              initial: 'sibling', // Sibling is NOT a descendant of parent
              children: [.composite(id: 'child')],
            ),
            .composite(id: 'sibling'),
          ],
        ),
      );

      final (machine, errors) = blueprint.compile();

      expect(machine, isNull);
      expect(errors, hasLength(1));
      expect(errors.first, isA<InvalidInitialStateError>());
      expect(
        errors.first.message,
        contains(
          'Initial state "sibling" is not a proper descendant of "parent"',
        ),
      );
    });

    test('reports error when initial state is itself', () {
      final blueprint = MachineBlueprint<String, String>(
        name: 'InvalidMachine',
        root: .composite(
          id: 'root',
          initial: 'root', // A state cannot be its own initial state
          children: [.composite(id: 'a')],
        ),
      );

      final (machine, errors) = blueprint.compile();

      expect(machine, isNull);
      expect(errors, hasLength(1));
      expect(errors.first, isA<InvalidInitialStateError>());
      expect(
        errors.first.message,
        contains('Initial state "root" is not a proper descendant of "root"'),
      );
    });

    test('successfully compiles when initial state is a proper descendant', () {
      final blueprint = MachineBlueprint<String, String>(
        name: 'ValidMachine',
        root: .composite(
          id: 'root',
          initial: 'child',
          children: [
            .composite(
              id: 'parent',
              children: [.composite(id: 'child')],
            ),
          ],
        ),
      );

      final (machine, errors) = blueprint.compile();

      expect(errors, isEmpty);
      expect(machine, isNotNull);
      expect(machine!.root.id, equals('root'));
    });
  });
}
