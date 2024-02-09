// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A hierarchical state machine (HSM) implementation for dart.
library;

import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart';

/// A hierarchical state machine (HSM) container of [S] states that accepts
/// [E] events.
///
/// Events are processed by recursively passing the event through [root] and to
/// any active states for handling. If a state is handled by a descendant, it
/// does not bubble up. [State]s can be simple (leaf), composite
/// (having children), or [ParallelState] (all children active at once).
class Machine<S, E> {
  Logger log;

  final String name;

  /// Returns whether or not the state machine has been [start]ed.
  bool get isRunning => _running;
  bool _running = false;

  final State<S, E> root;

  /// The map of all states in this machine, by their [State.id].
  final Map<S, State<S, E>> _states = <S, State<S, E>>{};

  Machine.rooted(this.root, {this.name = '', Logger? log})
      : log = log ?? root.log ?? Logger('HSMachine') {
    assert(root._hsm == null);
    root._hsm = this;
    _states[root.id] = root;
  }

  factory Machine({String name = '', required S rootId, Logger? log}) {
    log ??= Logger('HSMachine');
    var root = State<S, E>(rootId, log: log);
    return Machine<S, E>.rooted(root, name: name, log: log);
  }

  /// Returns a state for the given id.
  State<S, E>? operator [](S id) => _states[id];

  /// Initializes the state machine and enters the root state.
  bool start() {
    if (isRunning) return false;
    log.fine(() => '$this: starting with $root');
    _running = true;
    // 🐔 & 🥚: isActive will prevent initial onEnter() call.
    log.info(() => '$root: enter');
    root.onEnter?.call();
    root._enter([root]);
    return true;
  }

  /// Halts a running machine, exiting all states.
  bool stop() {
    if (!isRunning) return false;
    log.warning('$this: stopping');
    root._exit([]);
    _running = false;
    return true;
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
    log.fine(() => '$this: handle($event, $data)');

    if (!isRunning) {
      log.warning('Machine not running: $this');
      return Future.value(false);
    }
    var work = (_eventQueue..add(_QueuedWork(event, data))).last;
    if (_handlingEvent) {
      log.info(() => '$this: queueing $work');
      return work.completer.future;
    }

    _handlingEvent = true;
    Future.doWhile(() {
      var dequeued = _eventQueue.removeFirst();
      log.info(() => '$this: handling $dequeued');
      dequeued.completer.complete(root._handle(dequeued.event, dequeued.data));
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
  String get stateString => root.stateString;

  @override
  String toString() => 'Machine($name)';
}

/// Used to store events and their data for future processing by the machine.
class _QueuedWork<E> {
  final E event;
  final dynamic data;
  final Completer<bool> completer = Completer<bool>();
  _QueuedWork(this.event, this.data);
  @override
  String toString() => '{event: $event, data: $data}';
}

/// A simple state, which can have at most one active child.
///
/// States can handle events by registering [EventHandler] via the [addHandler]
/// and [addHandlers] methods. See EventHandler for more information.
class State<S, E> {
  /// A unique identifier for this state.
  final S id;

  /// The machine this state is attached to.
  Machine<S, E>? get machine => _hsm;
  Machine<S, E>? _hsm;

  /// The parent of this state if we are not the root of the machine.
  final State<S, E>? parent;

  /// Direct descendants of this state.
  final List<State<S, E>> _children = [];

  /// Map of all event handlers this state recognizes. See [EventHandler] for
  /// a description of configurations.
  final Map<E, List<EventHandler<S, E>>> handlers =
      <E, List<EventHandler<S, E>>>{};

  /// The currently active descendent, this state, or null.
  ///
  /// If this state is anywhere in the active path, this field will be set. If
  /// this state is the leaf, then active is set to self. If any ancestor
  /// is focused, then this is set to the next direct descendant.
  State<S, E>? get active => _active;
  State<S, E>? _active;

  /// Is this state currently in the active chain of states from root.
  ///
  /// Note: the direct children of [ParallelState]s are all considered active if
  /// the parallel state is active.
  bool get isActive =>
      parent?.active == this ||
      (parent is ParallelState && (parent?.isActive ?? false)) ||
      (isRoot && (_hsm?.isRunning ?? false));

  Logger? log;

  /// Called when the state is exiting.
  StateFunction? onExit;

  /// Called when the state is entering.
  StateFunction? onEnter;

  /// The default state to transition to if we are entered.
  State<S, E>? initialState;

  /// Called when the current state defines an [initialState].
  StateFunction? onInitialState;

  String get stateString =>
      active == null ? '$this' : '$this/${active?.stateString}';

  /// Create a basic state who can have zero or one active sub-states.
  ///
  /// It is considered an error if [id] is not unique to the owning [Machine].
  State(this.id, {this.parent, Logger? log})
      : log = log ?? parent?.log ?? parent?.machine?.log ?? Logger('HsmState'),
        _hsm = parent?.machine {
    this.log?.fine(() => '$this: parent:$parent');

    // Non-root states need to be added to the state cache
    if (_hsm != null) {
      final hsm = _hsm!;
      if (hsm[id] != null) {
        throw ArgumentError(
          '$hsm: already contains id:$id = ${hsm[id]} '
          'path:${hsm[id]?.path}',
        );
      }
      hsm._states[id] = this;
    }

    parent?._children.add(this);
  }

  State<S, E> newChild(S id, {Logger? log}) =>
      State(id, parent: this, log: log ?? this.log);

  /// Adds a handler for [event] to this state's [handlers].
  ///
  /// Events are handled in the order they are installed. See [EventHandler] for
  /// a deeper explanation of the parameters.
  List<EventHandler<S, E>> addHandler<D>(
    E event, {
    State<S, E>? target,
    GuardFunction<E, D>? guard,
    ActionFunction<E?, D>? action,
    bool local = true,
  }) =>
      handlers.putIfAbsent(event, () => [])
        ..add(
          EventHandler(
            target: target,
            guard:
                guard == null ? null : (event, data) => guard(event, data as D),
            action: action == null
                ? null
                : (event, data) => action(event, data as D),
            isLocalTransition: local,
          ),
        );

  List<EventHandler<S, E>> addHandlers(
    E event,
    List<EventHandler<S, E>> handlers,
  ) =>
      this.handlers.putIfAbsent(event, () => [])..addAll(handlers);

  /// Returns true if we are a descendant of [ancestor].
  bool isDescendantOf(State<S, E> ancestor) {
    var target = parent;
    while (target != null) {
      if (target == ancestor) return true;
      target = target.parent;
    }
    return false;
  }

  /// Returns true if we are an ancestor of [descendant].
  bool isAncestorOf(State<S, E> descendant) => descendant.isDescendantOf(this);

  /// Returns true if we share a lineage with [relative].
  bool hasLineage(State<S, E> relative) =>
      isAncestorOf(relative) || isDescendantOf(relative);

  bool get isRoot => _hsm?.root == this;

  List<State<S, E>>? _path;

  /// Returns the state path from root to this state.
  List<State<S, E>> get path {
    if (_path == null) {
      var path = Queue<State<S, E>>();
      State<S, E>? crumb = this;
      while (crumb != null) {
        path.addFirst(crumb);
        crumb = crumb.parent;
      }
      _path = path.toList();
    }

    return _path!;
  }

  bool _handle(E event, dynamic data) {
    if (active?._handle(event, data) == true) return true;

    if (handlers[event] == null) {
      log?.info(() => '$this: does not handle $event');
      return false;
    }

    // No one handled the message, see if we do.
    final eventHandlers = handlers[event];
    if (eventHandlers != null) {
      for (final handler in eventHandlers) {
        // 1: Evaluate the guard condition (if one exists)
        if (!(handler.guard?.call(event, data) ?? true)) {
          continue;
        }

        log?.finer(() => '$this[$event]: guard check passed for $handler');
        log?.info(() => '$this: handling $event');

        // 2: See if this was just an internal event (i.e. no transitioning)
        if (handler.isInternal) {
          log?.info(() => '$this[$event]: internal transition');
          handler.action?.call(event, data);
          return true;
        }

        if (handler.target != null) {
          _transition(
            handler.target!,
            local: handler.isLocalTransition,
            event: event,
            data: data,
            action: handler.action,
          );
        }

        return true;
      }
    }

    log?.info(() => '$this: did not handle $event');
    return false;
  }

  /// Performs the exit logic for this state and any active child.
  void _exit(List<State<S, E>> to) {
    active?._exit(to);

    if (parent?.active == this) {
      parent?._active = null;
    }
    log?.finer(() => '$this: exit');
    onExit?.call();
  }

  /// Performs entrance logic for this state and any active child, recursively.
  ///
  /// When a state is entered, the optional [onEnter] method is called.
  /// If this state is the final target and an [initialState] is defined, that
  /// state will then be transitioned to.
  void _enter(List<State<S, E>> path) {
    // We might already be active right now.
    final active = isActive;
    if (!active) {
      if (!isRoot) parent?._active = this;
      log?.info(() => '$this: enter');
      onEnter?.call();
    }

    // Check if we need to transition to our initialState
    if (this != path.last) {
      // Keep walking down the transition path requested.
      path[path.indexOf(this) + 1]._enter(path);
    } else if (initialState != null) {
      log?.finer(
        () => '$this: entered - '
            'transition to initialState($initialState)',
      );
      _transition(initialState!, action: _handleInitialAction);
    }
  }

  /// Transitions from this state, and any active substates, to [nextState].
  ///
  /// The [local] parameter only applies to ancestor <-> descendant
  /// transitions. It avoids extra exit/re-entry of the main source / target
  /// state.
  ///     local:           non-local:
  ///     ┌──────|s1|──┐    ┌─────|s1|────┐
  ///     │   ┌──|s11|┐│    │  ┌──|s11|┐  │
  ///     │<--│       ││  /-┼--│       │<-┼-\
  ///     │-->│       ││  \>│  │       │  │ |
  ///     │   └───────┘│    │  └───────┘  │-/
  ///     └────────────┘    └─────────────┘
  ///
  /// The triggering [event] and [data] are passed to the optional [action].
  void _transition(
    State<S, E> nextState, {
    bool local = true,
    E? event,
    data,
    ActionFunction<E?, dynamic>? action,
  }) {
    log?.finer(
      () => '$this: _transition($nextState, '
          '${{'local': local, 'event': event, 'action': action != null}})',
    );

    State<S, E>? lca;
    local = local && nextState.hasLineage(this);
    if (local) {
      // Local means we don't concern ourselves with lca; we do not want
      // to exit/enter the main source or exit/enter the main target.
      if (isAncestorOf(nextState)) {
        // we are the lca.
        lca = this;
      } else /* this is descendant of nextState */ {
        // they are the lca.
        lca = nextState;
      }
    } else {
      lca = lowestCommonAncestor(this, nextState);
    }

    // This is only possible if the 2 states are incompatible,
    // which shouldn't happen if they are in the same state machine.
    assert(lca != null);

    var nextPath = nextState.path;
    var lcaIndex = nextPath.indexOf(lca!);

    // LCA is common to both and if they share lineage (thus local), we want
    // to skip forward
    lcaIndex++;
    var entering = nextPath.sublist(lcaIndex);
    log?.info(
      () => '$this: _transition to $nextState (local:$local, '
          'action:${action != null}: lca:$lca entering: $entering',
    );

    // First handle the exiting action - this is recursive.
    lca.active?._exit(nextPath);

    // Handle any action
    action?.call(event, data);

    // Then enter with the given path.
    if (entering.isNotEmpty) entering.first._enter(nextPath);
  }

  /// Given two states, return their lowest common ancestor (LCA) defined as
  /// the super state of both source and target.
  ///
  /// Example:
  ///     left: [A, B, C, D, E, F]
  ///     right: [A, B, C, G, H, I]
  ///     LCA: C
  ///
  ///     left: [A, B, C]
  ///     right: [A, B]
  ///     LCA: A
  static State<S, E>? lowestCommonAncestor<S, E>(
    State<S, E> left,
    State<S, E> right,
  ) {
    var iLeft = left.path.iterator;
    var iRight = right.path.iterator;
    State<S, E>? common;
    while (iLeft.moveNext() && iRight.moveNext()) {
      if (iLeft.current != iRight.current) break;
      common = iLeft.current;
    }

    // Make sure to return the ancestor of both.
    if (common == left || common == right) {
      common = common?.parent;
    }

    return common;
  }

  /// Patches [ActionFunction] to [onInitialState].
  void _handleInitialAction(E? event, data) {
    onInitialState?.call();
  }

  @override
  String toString() => 'State($id)';
}

/// A state in which all direct descendants are active at the same time.
///
/// States can handle events by registering [EventHandler] via the [addHandler]
/// and [addHandlers] methods. See EventHandler for more information.
class ParallelState<S, E> extends State<S, E> {
  ParallelState(super.id, {super.parent, super.log});

  /// All children are always active.
  @override
  State<S, E>? get active => null;

  @override
  String get stateString {
    return '$this/(${_children.map((e) => e.stateString).join(',')})';
  }

  @override
  bool _handle(E event, dynamic data) {
    /// Parallel states get the message delivered to every child state.
    /// If any of them handle the message, we're done.
    var handled = false;
    for (var child in _children) {
      handled = child._handle(event, data) || handled;
    }
    if (handled) return true;
    return super._handle(event, data);
  }

  @override
  void _exit(List<State<S, E>> to) {
    for (var child in _children) {
      child._exit(to);
    }

    if (parent?.active == this) {
      parent?._active = null;
    }
    log?.finer(() => '$this: exit');
    onExit?.call();
  }

  @override
  void _enter(List<State<S, E>> path) {
    onEnter?.call();

    var us = path.indexOf(this);
    var activeChild = this == path.last ? null : path[us + 1];
    log?.fine(() => '$this: _enter($path) $us $activeChild $_children');
    for (var child in _children) {
      log?.info(() => '$this: child: $child');
      child._enter(child == activeChild ? path : [child]);
    }
    if (!isRoot) parent?._active = this;
    if (activeChild == null && initialState != null) {
      log?.finer(
        () => '$this: entered - '
            '_transition to initialState($initialState)',
      );
      _transition(initialState!, action: _handleInitialAction);
    }
  }

  @override
  String toString() => 'ParallelState($id)';
}

/// Handler associated with a state's event table.
///
/// Handlers can trigger a transition when an event is received:
///
///    state.addHandler('event', EventHandler(target: 'foo'));
///
/// They can have guards that prevent the event processing if certain
/// conditions are not met:
///
///    state.addHandler('event', EventHandler(target: 'foo',
///        guard: (_, data) => data == false));
///
/// The state can have multiple handlers, in which case the first handler that
/// doesn't implement a guard or guard function returns true gets processed:
///
///    state.addHandler('event', EventHandler(target: 'foo',
///        guard: (_, data) => data == false));
///    state.addHandler('event', EventHandler(target: 'bar',
///        guard: (_, data) => data == true));
///
/// The handler doesn't need to transition to another state to process the
/// event, in which case the transition is internal.
///
///    state.addHandler('event', EventHandler(action: () => print('sup')));
///
/// The handler can define the transition as [local] or external. Local
/// transitions do not generate exit() and re-entry() events on the LCA state.
/// External can be specified for UML 1.0 backwards compatibility and can be
/// useful for handling timeout situations to harness onExit/onEnter methods.
///
/// It is important to note: [action] is executed mid-transition, after the
/// state is exited up to the LCA and before enters() are called to the new
/// state. If you need to perform an operation before the machine changes,
/// do that in [guard].
///
/// Order of operations for the following state, assuming event T1 is fired and
/// s11 is the current state.
///     1) T1 delivered to s1
///     2) Guard g() is called. If it returns false, stop.
///     3) a(), b(), t(), c(), d(), e()
/// ┌──────────────────────────|s|──────────────────────────┐
/// │┌────|s1|────┐                    ┌────|s2|───────────┐│
/// ││exit:b()    │                    │entry:c()          ││
/// ││┌──|s11|──┐ │                    │-*:d()->┌──|s21|──┐││
/// │││exit:a() │ │--T1{guard:g(),     │        │entry:e()│││
/// │││         │ │      action:t()}-->│        │         │││
/// ││└─────────┘ │                    │        └─────────┘││
/// │└────────────┘                    └───────────────────┘│
/// └───────────────────────────────────────────────────────┘
class EventHandler<S, E> {
  final State<S, E>? target;

  /// Methods use to gate the processing of an [EventTarget] by the associated
  /// [State] it is registered with.
  final GuardFunction<E, dynamic>? guard;

  /// Methods used by [EventHandler] during a transition, after having exited
  /// all states to the lowest common ancestor.
  final ActionFunction<E?, dynamic>? action;

  final bool isLocalTransition;

  bool get isInternal => target == null;

  String? _lazy;

  EventHandler({
    this.target,
    this.guard,
    this.action,
    this.isLocalTransition = true,
  });

  @override
  String toString() {
    _lazy ??= 'EventTarget${{
      'target': isInternal ? 'internal' : target,
      'guard': guard != null,
      'action': action != null,
      'local': isLocalTransition,
    }}';
    return _lazy!;
  }
}

/// Simple method called for [State.onEnter], [State.onExit], and
/// [State.onInitialState].
typedef StateFunction = void Function();

typedef GuardFunction<E, D> = bool Function(E event, D data);
typedef ActionFunction<E, D> = void Function(E event, D data);
