part of '../machine.dart';

/// A simple state, which can have at most one active child.
///
/// States can handle events by registering [EventHandler] via the [addHandler]
/// and [addHandlers] methods. See EventHandler for more information.
base class State<S, E> extends BaseState<S, E> {
  /// Direct descendants of this state.
  final _children = <State<S, E>>[];

  /// The map of all event handlers this state recognizes. See [EventHandler] for
  /// a description of configurations.
  final handlers = <E, List<EventHandler<S, E>>>{};

  /// Set of events that this state defers for later processing.
  final deferEvents = <E>{};

  /// Queue of events and their data that have been deferred by this state.
  final deferredQueue = <EventData<E>>{};

  /// List of completion handlers associated with this state.
  final completionHandlers = <CompletionHandler<S, E>>[];

  /// The currently active descendent, this state, or null.
  ///
  /// If this state is anywhere in the active path, this field will be set. If
  /// this state is the leaf, then active is set to self. If any ancestor
  /// is focused, then this is set to the next direct descendant.
  State<S, E>? get active => _active;
  State<S, E>? _active;

  /// The most recently active direct child of this state.
  ///
  /// Used for history restoration.
  State<S, E>? _history;

  @visibleForTesting
  State<S, E>? get history => _history;

  /// Recursively clears history for this state and all its descendants.
  void _clearHistory() {
    _history = null;
    for (final child in _children) {
      child._clearHistory();
    }
  }

  /// Is this state currently in the active chain of states from root.
  ///
  /// Note: the direct children of [ParallelState]s are all considered active if
  /// the parallel state is active.
  @override
  bool isActive = false;
  // bool get isActive => switch (parent) {
  //   null => isRoot && hsm.isRunning,
  //   ParallelState(:var isActive) => isActive,
  //   State(:var active) => active == this,
  // };

  /// Called when the state is exiting.
  StateFunction? onExit;

  /// Called when the state is entering.
  StateFunction? onEnter;

  /// The default state to transition to if we are entered.
  BaseState<S, E>? initialState;

  /// Effect Behavior called when the current state is entered via the default
  /// entry via the [initialState].
  StateFunction? onInitialState;

  /// Returns the state path string from root to this state.
  String get stateString =>
      active == null ? '$this' : '$this/${active?.stateString}';

  /// Create a basic state who can have zero or one active sub-states.
  ///
  /// It is considered an error if [id] is not unique to the owning [Machine].
  State(super.id, super.hsm, {super.parent, this.onEnter, this.onExit}) {
    parent?._children.add(this);
  }

  /// Create a new child state for this state.
  State<S, E> newChild(S id, {bool historyEnabled = false}) =>
      State(id, hsm, parent: this);

  /// Adds a handler for [event] to this state's [handlers].
  ///
  /// Events are handled in the order they are installed. See [EventHandler] for
  /// a deeper explanation of the parameters.
  List<EventHandler<S, E>> addHandler<D>(
    E event, {
    BaseState<S, E>? target,
    GuardFunction<E?, D>? guard,
    ActionFunction<E?, D>? action,
    TransitionKind kind = .local,
    HistoryType history = HistoryType.none,
  }) => (handlers[event] ??= [])
    ..add(
      EventHandler(
        target: target,
        guard: guard == null ? null : (event, data) => guard(event, data as D),
        action: action == null
            ? null
            : (event, data) => action(event, data as D),
        kind: kind,
        history: history,
      ),
    );

  /// Adds a completion handler to this state.
  ///
  /// Completion handlers are evaluated when this state is "completed".
  /// For a composite state, it is completed when its active child is a [FinalState].
  /// For a parallel state, it is completed when all its children are in a [FinalState].
  void addCompletionHandler({
    BaseState<S, E>? target,
    bool Function()? guard,
    void Function()? action,
    TransitionKind kind = .local,
    HistoryType history = HistoryType.none,
  }) {
    completionHandlers.add(
      CompletionHandler(
        target: target,
        guard: guard,
        action: action,
        kind: kind,
        history: history,
      ),
    );
  }

  /// Called by a child state when it has reached a FinalState.
  void onChildFinal(BaseState<S, E> child) {
    _checkCompletion();
  }

  /// Whether this state is considered complete.
  ///
  /// For a composite state, it is complete if its active child is completed.
  bool get isCompleted => active?.isCompleted ?? false;

  /// Checks if completion conditions are met and triggers handlers if so.
  void _checkCompletion() {
    if (!isCompleted) return;

    for (final handler in completionHandlers) {
      if (handler.guard != null && !handler.guard!()) {
        continue;
      }

      hsm.observer.onInternalTransition(this, null, null);
      handler.action?.call();

      if (handler.target != null) {
        _transition(
          handler.target!,
          kind: handler.kind,
          history: handler.history,
          lca: handler.lca,
        );
      }
      return; // Take first matching handler
    }

    // Notify parent that we are complete. For composite states, nothing
    // will happen - but for ParallelStates, they wills check if all children
    // are complete before further processing.
    parent?.onChildFinal(this);
  }

  /// Adds multiple handlers for [event] to this state's [handlers].
  List<EventHandler<S, E>> addHandlers(
    E event,
    List<EventHandler<S, E>> handlers,
  ) => this.handlers.putIfAbsent(event, () => [])..addAll(handlers);

  /// Registers [event] as deferred by this state.
  ///
  /// When this state is active and an event of type [event] is received, it will
  /// be added to [deferredQueue] and processed after this state is exited.
  void addDeferral(E event) => deferEvents.add(event);

  /// Internal handler for events, to be implemented by subclasses.
  (HandledStatus, Set<EventData<E>>?) _handle(EventData<E> eventData) {
    if (active?._handle(eventData) case (var status, var deferrals)) {
      if (status != HandledStatus.unhandled) {
        return (status, deferrals);
      }
    }

    if (handlers[eventData.event] case var eventHandlers?) {
      for (final handler in eventHandlers) {
        // 1: Evaluate the guard condition (if one exists)
        if (!(handler.guard?.call(eventData.event, eventData.data) ?? true)) {
          continue;
        }

        eventData.handled = true;
        hsm.observer.onEventHandled(this, eventData.event, eventData.data);

        // 2: See if this was just an internal event (i.e. no transitioning)
        if (handler.isInternal) {
          hsm.observer.onInternalTransition(
            this,
            eventData.event,
            eventData.data,
          );
          handler.action?.call(eventData.event, eventData.data);
          return (HandledStatus.handled, null);
        }

        if (handler.target != null) {
          _transition(
            handler.target!,
            kind: handler.kind,
            eventData: eventData,
            action: handler.action,
            history: handler.history,
            lca: handler.lca,
          );
        }

        return (HandledStatus.handled, null);
      }
    }

    // Check for deferral
    if (deferEvents.contains(eventData.event)) {
      hsm.observer.onEventDeferred(this, eventData.event, eventData.data);
      deferredQueue.add(eventData);
      return (HandledStatus.deferred, deferredQueue);
    }

    hsm.observer.onEventUnhandled(this, eventData.event, eventData.data);
    return (HandledStatus.unhandled, null);
  }

  /// Performs the exit logic for this state and any active child.
  void _exit(List<BaseState<S, E>> to) {
    active?._exit(to);

    if (parent?.active == this) {
      parent?._active = null;
    }
    isActive = false;
    hsm.observer.onStateExit(this);
    onExit?.call();

    // Replay deferred events at the front of the line.
    if (deferredQueue.isNotEmpty) {
      for (var deferral in [...deferredQueue].reversed) {
        // If the event was handled during replay, we don't re-queue it; this
        // can happen if an event was deferred in multiple regions of a
        // parallel state.
        if (!deferral.handled) {
          hsm._prependWork(deferral);
        }
      }
      deferredQueue.clear();
    }
  }

  /// Performs entrance logic for this state and any active child, recursively.
  ///
  /// When a state is entered, the optional [onEnter] method is called.
  /// If this state is the final target and an [initialState] is defined, that
  /// state will then be transitioned to.
  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    EventData<E>? eventData,
    HistoryType history = HistoryType.none,
  }) {
    // We might already be active right now.
    if (!isActive) {
      isActive = true;
      if (!isRoot) {
        parent?._active = this;
        parent?._history = this;
      }
      hsm.observer.onStateEnter(this);
      onEnter?.call();
    }

    // Check if we need to transition to our initialState
    if (index < path.length - 1) {
      // Keep walking down the transition path requested.
      path[index + 1]._enter(
        path,
        index + 1,
        eventData: eventData,
        history: history,
      );
    } else {
      // Path exhausted. Check for history restoration.
      if (history != HistoryType.none && _history != null) {
        hsm.observer.onInternalTransition(
          this,
          eventData?.event,
          eventData?.data,
        );
        _transition(
          _history!,
          eventData: eventData,
          history: switch (history) {
            HistoryType.deep => HistoryType.deep,
            _ => HistoryType.none,
          },
          lca: this,
        );
        return;
      }

      if (initialState != null && history != HistoryType.deep) {
        hsm.observer.onInternalTransition(
          this,
          eventData?.event,
          eventData?.data,
        );
        _transition(
          initialState!,
          eventData: eventData,
          action: _handleInitialAction,
          lca: this,
        );
      }
    }
  }

  /// Patches [ActionFunction] to [onInitialState].
  void _handleInitialAction(E? event, data) {
    onInitialState?.call();
  }
}
