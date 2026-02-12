part of '../machine.dart';

/// A pseudo-state that represents a decision point in the state machine.
///
/// Choice handlers provide developers with a many-to-many transition mechanism,
/// enabling evaluative branching logic based on guards.
///
/// When entered, the ChoiceState evaluates its completion handlers in order,
/// taking the first whose guard evaluates to true. If none match, it takes the
/// default completion handler.
///
/// Choice states cannot have event handlers or children.
///
/// > [!IMPORTANT] Choice states may be the target of completions and thus carry
/// > no event or data.
final class ChoiceState<S, E> extends BaseState<S, E> {
  EventHandler<S, E>? _defaultChoice;
  EventHandler<S, E> get defaultChoice => _defaultChoice!;
  set defaultChoice(EventHandler<S, E> value) => _defaultChoice = value;

  /// List of choice handlers that have guards.
  ///
  /// Choice Pseudo-States do not have "triggers", hence the simple list.
  final List<EventHandler<S, E>> choiceOptions = [];

  /// Choice states are transient and never "active" in a resting sense.
  @override
  bool get isActive => false;

  ChoiceState(
    super.id,
    super.hsm, {
    BaseState<S, E>? defaultTarget,
    ActionFunction<E?, dynamic>? action,
    TransitionKind kind = TransitionKind.local,
    HistoryType history = HistoryType.none,
    super.parent,
  }) {
    if (defaultTarget != null) {
      _defaultChoice = EventHandler<S, E>(
        guard: null,
        action: action,
        target: defaultTarget,
        kind: kind,
        history: history,
      );
    }
  }

  // Adds a non-default completion handler to this choice state.
  void addCompletionHandler(EventHandler<S, E> handler) {
    choiceOptions.add(handler);
  }

  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    EventData<E>? eventData,
    // ignore: unused_element_parameter
    HistoryType history = HistoryType.none,
  }) {
    for (var handler in choiceOptions) {
      if (handler.guard == null ||
          handler.guard!(eventData?.event, eventData?.data)) {
        hsm.observer.onInternalTransition(
          this,
          eventData?.event,
          eventData?.data,
        );
        _transition(
          handler.target!,
          eventData: eventData,
          action: handler.action,
          kind: handler.kind,
          history: handler.history,
          lca: handler.lca,
        );
        return;
      }
    }

    hsm.observer.onInternalTransition(this, eventData?.event, eventData?.data);
    _transition(
      defaultChoice.target!,
      eventData: eventData,
      action: defaultChoice.action,
      kind: defaultChoice.kind,
      history: defaultChoice.history,
      lca: defaultChoice.lca,
    );
  }
}
