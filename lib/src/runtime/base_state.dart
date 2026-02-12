part of '../machine.dart';

/// The base unit of the state machine, capturing identity and tree structure.
abstract base class BaseState<S, E> implements HsmState<S, E> {
  /// A unique identifier for this state.
  @override
  final S id;

  /// The machine this state is attached to.
  final Machine<S, E> hsm;

  /// The parent of this state if we are not the root of the machine.
  ///
  /// Only [State] (and subclasses like [ParallelState]) can be parents.
  @override
  final State<S, E>? parent;

  /// The state path from root to this state.
  @override
  final List<BaseState<S, E>> path = <BaseState<S, E>>[];

  BaseState(this.id, this.hsm, {this.parent}) {
    path.addAll(parent?.path ?? []);
    path.add(this);
  }

  /// Returns true if we are a descendant of [ancestor].
  bool isDescendantOf(BaseState<S, E> ancestor) {
    if (path.length <= ancestor.path.length) return false;
    // Since ancestor is in our path, it must be at its own depth index
    // if the ancestry holds true.
    return path[ancestor.path.length - 1] == ancestor;
  }

  /// Returns true if we are an ancestor of [descendant].
  bool isAncestorOf(BaseState<S, E> descendant) =>
      descendant.isDescendantOf(this);

  /// Returns true if we share a lineage with [relative].
  bool hasLineage(BaseState<S, E> relative) =>
      identical(this, relative) ||
      isDescendantOf(relative) ||
      relative.isDescendantOf(this);

  /// Whether this state is the root of the machine.
  bool get isRoot => hsm.root == this;

  /// Whether this state is currently active.
  @override
  bool get isActive;

  /// Performs entrance logic for this state and any active child, recursively.
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    // ignore: unused_element_parameter
    EventData<E>? eventData,
    // ignore: unused_element_parameter
    HistoryType history = HistoryType.none,
  });

  /// Transitions from this state, and any active substates, to [nextState].
  ///
  /// The [local] parameter only applies to ancestor <-> descendant
  /// transitions. It avoids extra exit/re-entry of the main source / target
  /// state.
  ///     local:           non-local:
  ///     ┌──────|s1|──┐    ┌─────|s1|────┐
  ///     │   ┌──|s11|┐│    │  ┌──|s11|┐  │
  ///     │<--│       ││  /-┼--│       │<-┼-
  ///     │-->│       ││  \>│  │       │  │ |
  ///     │   └───────┘│    │  └───────┘  │-/
  ///     └────────────┘    └─────────────┘
  ///
  /// The triggering [event] and [data] are passed to the optional [action].
  void _transition(
    BaseState<S, E> nextState, {
    required BaseState<S, E>? lca,
    TransitionKind kind = .local,
    EventData<E>? eventData,
    ActionFunction<E?, dynamic>? action,
    HistoryType history = HistoryType.none,
  }) {
    hsm.observer.onTransition(
      this,
      nextState,
      eventData?.event,
      eventData?.data,
      kind,
    );

    var nextPath = nextState.path;
    // Optimization: we can calculate the LCA index from the path length
    // because we know LCA is an ancestor of nextState (or null).
    var lcaIndex = lca == null ? -1 : lca.path.length - 1;

    // LCA is common to both and if they share lineage (thus local), we want
    // to skip forward to the first state being entered.
    lcaIndex++;

    if (lca is State<S, E>) {
      lca.active?._exit(nextPath);
    }

    // Handle any action
    action?.call(eventData?.event, eventData?.data);

    // Then enter with the given path.
    if (lcaIndex < nextPath.length) {
      nextPath[lcaIndex]._enter(
        nextPath,
        lcaIndex,
        eventData: eventData,
        history: history,
      );
    } else {
      // If we are targeting the LCA itself (or a local transition to self),
      // we need to trigger stability/history logic on it.
      nextState._enter(
        nextPath,
        lcaIndex, // index will be out of bounds, but _enter handles that
        eventData: eventData,
        history: history,
      );
    }
  }

  @override
  String toString() {
    final type = '$runtimeType'.split('<').first;
    return '$type($id)';
  }
}

extension ForkTargetExtension<S, E> on BaseState<S, E> {
  /// Returns a [ForkTransition] targeting this state.
  ///
  /// This is a convenience helper for building [ForkState] children.
  /// You can optionally specify an [action] to run when this branch is entered,
  /// and a [history] restoration strategy.
  ForkTransition<S, E> forkTarget({
    ActionFunction<E?, dynamic>? action,
    HistoryType history = HistoryType.none,
  }) => ForkTransition(target: this, action: action, history: history);
}
