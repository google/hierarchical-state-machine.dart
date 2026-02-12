import 'package:test/test.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

// Test types
enum MyState { root, s1 }

enum MyEvent { e1 }

void main() {
  group('PRD 2.0 Phase 1: History Semantics', () {
    test('HistoryType enum exists and has correct values', () {
      expect(HistoryType.none, isNotNull);
      expect(HistoryType.shallow, isNotNull);
      expect(HistoryType.deep, isNotNull);
    });

    test('TransitionDefinition accepts history parameter', () {
      final transition = TransitionBlueprint<MyState, MyEvent>(
        target: MyState.s1,
        history: HistoryType.shallow,
      );
      expect(transition.history, equals(HistoryType.shallow));
    });

    test('ForkTransitionDefinition accepts history parameter', () {
      final transition = ForkTransitionBlueprint<MyState, MyEvent>(
        target: MyState.s1,
        history: HistoryType.deep,
      );
      expect(transition.history, equals(HistoryType.deep));
    });
  });
}
