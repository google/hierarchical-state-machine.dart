part of '../machine.dart';

/// A state in which all direct descendants are active at the same time.
///
/// States can handle events by registering [EventHandler] via the [addHandler]
/// and [addHandlers] methods. See EventHandler for more information.
base class ParallelState<S, E> extends State<S, E> {
  ParallelState(
    super.id,
    super.hsm, {
    super.parent,
    super.onEnter,
    super.onExit,
  });

  /// The orthogonal regions of this parallel state.
  List<State<S, E>> get regions => UnmodifiableListView(_children);

  /// All children are always active.
  @override
  State<S, E>? get active => null;

  /// Returns true if all children are completed.
  @override
  bool get isCompleted {
    for (final child in _children) {
      if (!child.isCompleted) return false;
    }
    return true;
  }

  @override
  String get stateString {
    return '$this/(${_children.map((e) => e.stateString).join(',')})';
  }

  @override
  (HandledStatus, Set<EventData<E>>?) _handle(EventData<E> eventData) {
    // As an optimization - track deferrals to remove if any child handles it.
    List<Set<EventData<E>>>? allDeferrals; // = <Set<EventData<E>>>[];

    for (var child in _children) {
      final (status, childDeferrals) = child._handle(eventData);
      if (status == HandledStatus.deferred && childDeferrals != null) {
        (allDeferrals ??= []).add(childDeferrals);
      }
    }

    if (eventData.handled) {
      // Drop all deferrals since the event was handled.
      for (var deferrals in allDeferrals ?? const []) {
        deferrals.remove(eventData);
        hsm.observer.onEventDropped(this, eventData.event, eventData.data);
      }

      return (HandledStatus.handled, null);
    }

    if (allDeferrals?.isNotEmpty ?? false) {
      return (HandledStatus.deferred, allDeferrals!.first);
    }

    // This lets the parallel state have its own deferrals/handlers.
    return super._handle(eventData);
  }

  @override
  void _exit(List<BaseState<S, E>> to) {
    for (var child in _children) {
      child._exit(to);
    }

    if (parent?.active == this) {
      parent?._active = null;
    }
    hsm.observer.onStateExit(this);
    onExit?.call();
  }

  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    EventData<E>? eventData,
    HistoryType history = HistoryType.none,
  }) {
    onEnter?.call();

    var activeChild = this == path.last ? null : path[index + 1];
    hsm.observer.onStateEnter(this);

    for (var child in _children) {
      // The child is being entered either as part of the target path
      // or as a default entry (index 0 of its own path).
      if (child == activeChild) {
        child._enter(
          path,
          index + 1,
          eventData: eventData,
          history: switch (history) {
            .deep => .deep,
            _ => .none,
          },
        );
      } else {
        child._enter(
          [child],
          0,
          eventData: eventData,
          history: activeChild == null
              ? switch (history) {
                  .deep => .deep,
                  _ => .none,
                }
              : .none,
        );
      }
    }
    if (!isRoot) parent?._active = this;
    if (activeChild == null && initialState != null) {
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

  /// Enters this parallel state with explicit target states for its regions.
  ///
  /// Used by [ForkState] to transition into specific descendants in different
  /// orthogonal regions.
  void enterWith(
    List<ForkTransition<S, E>> transitions, {
    EventData<E>? eventData,
  }) {
    if (!isActive) {
      isActive = true;
      parent?._active = this;
      parent?._history = this;
      onEnter?.call();
    }

    hsm.observer.onInternalTransition(this, eventData?.event, eventData?.data);

    for (var child in _children) {
      // Find which transition belongs to this child (region)
      ForkTransition<S, E>? transitionForRegion;
      for (final t in transitions) {
        if (t.target == child || t.target.isDescendantOf(child)) {
          transitionForRegion = t;
          break;
        }
      }

      if (transitionForRegion != null) {
        // Optimization: calculate entry index for the target path
        // Since child is an ancestor of target (or is target), child is in target.path
        // We know child is a direct child of this (ParallelState), so its index
        // in target.path is child.path.length - 1.
        final targetPath = transitionForRegion.target.path;
        final entryIndex = child.path.length - 1;

        child._enter(
          targetPath,
          entryIndex,
          eventData: eventData,
          history: transitionForRegion.history,
        );
      } else {
        // Default entry
        child._enter(
          [child],
          0,
          eventData: eventData,
          history: HistoryType.none,
        );
      }
    }

    if (!isRoot) parent?._active = this;
  }

  @override
  String toString() => 'ParallelState($id)';
}
