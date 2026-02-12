part of '../machine.dart';

/// Observer interface for monitoring state machine execution.
///
/// Implement this class to hook into lifecycle events, transitions, and error handling.
/// Default implementations are empty, so you can override only the methods you need.
abstract class MachineObserver<S, E> {
  const MachineObserver();

  // Lifecycle
  void onMachineStarting(Machine<S, E> machine) {}
  void onMachineStarted(Machine<S, E> machine) {}
  void onMachineStopped(Machine<S, E> machine) {}
  void onMachineTerminated(Machine<S, E> machine) {}

  // Event Handling
  void onEventQueued(Machine<S, E> machine, E event, dynamic data) {}
  void onEventHandling(Machine<S, E> machine, E event, dynamic data) {}
  void onEventHandled(HsmState<S, E> state, E event, dynamic data) {}
  void onEventUnhandled(HsmState<S, E> state, E event, dynamic data) {}
  void onEventDeferred(HsmState<S, E> state, E event, dynamic data) {}
  void onEventDropped(HsmState<S, E> state, E event, dynamic data) {}
  void onEventError(
    Machine<S, E> machine,
    E event,
    dynamic data,
    Object error,
    StackTrace stackTrace,
  ) {}

  // State Lifecycle
  void onStateEnter(HsmState<S, E> state) {}
  void onStateExit(HsmState<S, E> state) {}

  // Transitions
  void onTransition(
    HsmState<S, E> source,
    HsmState<S, E> target,
    E? event,
    dynamic data,
    TransitionKind kind,
  ) {}
  void onInternalTransition(HsmState<S, E> state, E? event, dynamic data) {}
}

/// A no-op observer that does nothing.
final class NoOpObserver<S, E> extends MachineObserver<S, E> {
  const NoOpObserver();
}

/// A default observer that prints machine activity to the console.
class PrintObserver<S, E> extends MachineObserver<S, E> {
  final String Function(String) formatter;

  const PrintObserver({this.formatter = _defaultFormatter});

  static String _defaultFormatter(String msg) => msg;

  void _log(String message) {
    print(formatter(message));
  }

  @override
  void onMachineStarting(Machine<S, E> machine) => _log('$machine: starting');

  @override
  void onMachineStarted(Machine<S, E> machine) => _log('$machine: started');

  @override
  void onMachineStopped(Machine<S, E> machine) => _log('$machine: stopped');

  @override
  void onMachineTerminated(Machine<S, E> machine) =>
      _log('$machine: terminated');

  @override
  void onEventQueued(Machine<S, E> machine, E event, dynamic data) =>
      _log('$machine: queueing event $event data: $data');

  @override
  void onEventHandling(Machine<S, E> machine, E event, dynamic data) =>
      _log('$machine: handling event $event data: $data');

  @override
  void onEventHandled(HsmState<S, E> state, E event, dynamic data) =>
      _log('$state: handled event $event');

  @override
  void onEventUnhandled(HsmState<S, E> state, E event, dynamic data) =>
      _log('$state: unhandled event $event');

  @override
  void onEventDeferred(HsmState<S, E> state, E event, dynamic data) =>
      _log('$state: deferring event $event');

  @override
  void onEventDropped(HsmState<S, E> state, E event, dynamic data) =>
      _log('$state: dropping deferral $event');

  @override
  void onEventError(
    Machine<S, E> machine,
    E event,
    dynamic data,
    Object error,
    StackTrace stackTrace,
  ) => _log('$machine: error handling $event: $error\n$stackTrace');

  @override
  void onStateEnter(HsmState<S, E> state) => _log('$state: enter');

  @override
  void onStateExit(HsmState<S, E> state) => _log('$state: exit');

  @override
  void onTransition(
    HsmState<S, E> source,
    HsmState<S, E> target,
    E? event,
    dynamic data,
    TransitionKind kind,
  ) => _log('$source: transition to $target (${kind.name})');

  @override
  void onInternalTransition(HsmState<S, E> state, E? event, dynamic data) =>
      _log('$state: internal transition');
}
