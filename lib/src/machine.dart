library;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

// Event-related classes
part 'event_handler.dart';

// State-related classes
part 'runtime/hsm_state.dart';
part 'runtime/base_state.dart';
part 'runtime/state.dart';
part 'runtime/parallel_state.dart';
part 'runtime/choice_state.dart';
part 'runtime/fork_state.dart';
part 'runtime/final_state.dart';
part 'runtime/terminate_state.dart';

// Blueprints
part 'blueprints/errors.dart';
part 'blueprints/machine.dart';
part 'blueprints/transitions.dart';
part 'blueprints/states.dart';
part 'blueprints/lca.dart';

part 'runtime/observer.dart';

/// A hierarchical state machine (HSM) container of [S] states that accepts
/// [E] events.
///
/// Events are processed by recursively passing the event through [root] and to
/// any active states for handling. If a state is handled by a descendant, it
/// does not bubble up. [State]s can be simple (leaf), composite
/// (having children), or [ParallelState] (all children active at once).
final class Machine<S, E> {
  final MachineObserver<S, E> observer;

  final String name;

  /// Returns whether or not the state machine has been [start]ed.
  bool get isRunning => _running;
  bool _running = false;

  /// The root state of the machine.
  HsmState<S, E> get root => _root;
  late final State<S, E> _root;

  /// Called when a [TerminateState] is entered.
  final void Function()? onTerminated;

  /// The map of all states in this machine, by their [State.id].
  final _states = <S, BaseState<S, E>>{};

  Machine._uninitialized({
    this.name = '',
    MachineObserver<S, E>? observer,
    this.onTerminated,
  }) : observer = observer ?? NoOpObserver<S, E>();

  void _setRoot(State<S, E> rootState, Map<S, BaseState<S, E>> states) {
    _root = rootState;
    _states.addAll(states);
  }

  /// Returns the state with the given [id], if it exists in this machine.
  HsmState<S, E>? getState(S id) => _states[id];

  /// Initializes the state machine and enters the root state.
  bool start() {
    if (isRunning) return false;
    observer.onMachineStarting(this);
    _running = true;
    // 🐔 & 🥚: isActive will prevent initial onEnter() call.
    // observer.onStateEnter(_root);
    final rootState = root as State<S, E>;
    // rootState.onEnter?.call();
    rootState._enter([rootState], 0);
    observer.onMachineStarted(this);
    return true;
  }

  /// Halts a running machine, exiting all states.
  bool stop() {
    if (!isRunning) return false;
    observer.onMachineStopped(this);
    _root._exit([]);
    _running = false;
    return true;
  }

  /// Immediately halts the machine, clearing all history and deferrals.
  void _terminate() {
    if (!_running) return;
    observer.onMachineTerminated(this);
    _running = false;

    for (final state in _states.values) {
      if (state is State<S, E>) {
        state._history = null;
        state.deferredQueue.clear();
      }
    }

    onTerminated?.call();
  }

  /// Returns if the machine is currently processing events.
  ///
  /// Since events are processed asynchronously, this informs the external
  /// caller that events have been queued and are being processed.
  bool get isHandlingEvent => _handlingEvent;
  bool _handlingEvent = false;

  /// Queued work represents events that are received while the machine is
  /// processing events - i.e. generated via [EventHandler.action] and
  /// [EventHandler.guard] functions.
  final Queue<_QueuedWork<E>> _eventQueue = Queue<_QueuedWork<E>>();
  StreamController<Machine<S, E>>? _settling;

  /// A stream who's events represent times when the machine's work queue is
  /// emptied.
  Stream<Machine<S, E>> get onSettled {
    _settling ??= StreamController<Machine<S, E>>.broadcast();
    return _settling!.stream;
  }

  /// A future that completes when all events in the work queue are processed.
  Future<void> get settled =>
      _eventQueue.isEmpty ? Future.value() : onSettled.first;

  /// Prepends work to the front of the event queue.
  ///
  /// Used for replaying deferred events when a state is exited.
  void _prependWork(EventData<E> event) {
    _eventQueue.addFirst(_QueuedWork.retry(event));
  }

  /// Passes the event to the machine to handle, with optional [data].
  ///
  /// Events are recursively passed to the tree of active states for handling.
  /// If any child handles an event, the message processing for that event is
  /// done. If any guard or action functions trigger further events, they will
  /// wait in a queue until the processing of the current event and any
  /// corresponding transition is completed.
  ///
  /// This method returns `true` iff there was a suitable event handler for the
  /// event (which was not guarded or the guard returned true). This method
  /// returns after the transition happened (if any). Asynchronous action
  /// functions are NOT awaited before this function returns.
  ///
  /// See [EventHandler] for more detail.
  Future<bool> handle(E event, [dynamic data]) {
    observer.onEventQueued(this, event, data);

    if (!isRunning) {
      return Future.value(false);
    }
    var work = (_eventQueue..add(_QueuedWork(event, data))).last;
    if (_handlingEvent) {
      return work.completer.future;
    }

    _handlingEvent = true;
    Future.doWhile(() {
      var _QueuedWork(:eventData, :completer) = _eventQueue.removeFirst();

      // An event could already be handled if it was deferred by multiple
      // regions and replayed later. We can only "handle" the event once.
      if (!eventData.handled) {
        observer.onEventHandling(this, eventData.event, eventData.data);
        try {
          final (status, deferrals) = _root._handle(eventData);
          if (status == HandledStatus.deferred && deferrals != null) {
            completer.complete(true);
          } else {
            completer.complete(status == HandledStatus.handled);
          }
        } catch (error, stackTrace) {
          observer.onEventError(
            this,
            eventData.event,
            eventData.data,
            error,
            stackTrace,
          );
          completer.completeError(error, stackTrace);
        }
      }

      if (_eventQueue.isEmpty) {
        _handlingEvent = false;

        /// If there is anyone waiting on all events in the machine to complete,
        /// notify them.
        _settling?.add(this);
        return Future.value(false);
      }
      return Future.value(true);
    });
    return work.completer.future;
  }

  /// Returns a string that represents all of the active states of the machine.
  String get stateString => _root.stateString;

  @override
  String toString() => 'Machine($name)';
}

/// Used to store events and their data for future processing by the machine.
class _QueuedWork<E> {
  final EventData<E> eventData;
  final Completer<bool> completer = Completer<bool>();

  _QueuedWork(E event, dynamic data) : eventData = EventData<E>(event, data);

  _QueuedWork.retry(this.eventData);

  @override
  String toString() => '$eventData';
}

/// Unique object representing event data passed during event handling.
///
/// If an event is deferred - this object is held on to and potentially later
/// replayed. A copy should never be made of this.
class EventData<E> {
  static int _nextId = 0;
  final int _id;
  final E event;
  final dynamic data;

  bool _handled = false;
  bool get handled => _handled;
  set handled(bool value) {
    if (value) _handled = value;
  }

  EventData(this.event, this.data) : _id = _nextId++;

  @override
  String toString() =>
      '[$_id]{event: $event, data: $data${handled ? ', handled' : ''}}';
}
