import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

// Test types
enum MyState { s1 }

enum MyEvent { e1 }

void main() {
  group('PRD 2.0 Phase 2: Specialized Handlers', () {
    test('CompletionDefinition can be instantiated', () {
      final definition = CompletionBlueprint<MyState, MyEvent>(
        target: MyState.s1,
        guard: () => true,
        action: () {},
      );
      expect(definition, isNotNull);
    });

    test('CompositeBlueprint has completion registry', () {
      final blueprint = CompositeBlueprint<MyState, MyEvent>(
        id: MyState.s1,
        completion: [.new(target: MyState.s1)],
      );
      expect(blueprint.completion, isNotEmpty);
      expect(blueprint.completion!.first.target, equals(MyState.s1));
    });
  });
}
