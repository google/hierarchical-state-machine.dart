part of '../machine.dart';

/// A terminal node that immediately halts the state machine.
///
/// When a [TerminateState] is entered, the state machine's [Machine.isRunning]
/// property becomes false, and the [Machine.onTerminated] callback is invoked.
/// All history and deferred events are cleared across the machine.
base class TerminateState<S, E> extends BaseState<S, E> {
  TerminateState(super.id, super.hsm, {super.parent});

  /// Terminate states are instantaneous and never "active" in a resting sense.
  @override
  bool get isActive => false;

  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    // ignore: unused_element_parameter
    EventData<E>? eventData,
    // ignore: unused_element_parameter
    HistoryType history = HistoryType.none,
  }) {
    hsm.observer.onStateEnter(this);
    hsm._terminate();
  }
}
