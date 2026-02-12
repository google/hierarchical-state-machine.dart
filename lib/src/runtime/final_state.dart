part of '../machine.dart';

/// A state that represents a completion of a region.
///
/// Final states are "silent" and do not process events. Entering a final state
/// triggers a completion check on the parent state.
base class FinalState<S, E> extends State<S, E> {
  FinalState(super.id, super.hsm, {super.parent});

  @override
  (HandledStatus, Set<EventData<E>>?) _handle(EventData<E> eventData) {
    hsm.observer.onEventUnhandled(this, eventData.event, eventData.data);
    return (HandledStatus.unhandled, null);
  }

  /// Final states are always completed.
  @override
  bool get isCompleted => true;

  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    EventData<E>? eventData,
    HistoryType history = HistoryType.none,
  }) {
    super._enter(path, index, eventData: eventData, history: history);
    parent?._clearHistory();
    _notifyParentOfCompletion();
  }

  void _notifyParentOfCompletion() {
    parent?.onChildFinal(this);
  }
}
