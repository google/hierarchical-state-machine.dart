part of '../machine.dart';

/// Defines an explicit target for one region of a [ForkState].
///
/// A [ForkTransition] specifies a [target] state within an orthogonal region
/// of a [ParallelState], along with an optional [action] to execute during
/// the transition and a [history] type for entry.
class ForkTransition<S, E> {
  /// The destination state for this branch of the fork.
  final BaseState<S, E> target;

  /// The lowest common ancestor between the source state and the target state.
  /// Pre-calculated during compilation for performance.
  BaseState<S, E>? lca;

  /// An optional effect behavior executed when this branch is taken.
  final ActionFunction<E?, dynamic>? action;

  /// The history restoration strategy to use when entering the [target].
  final HistoryType history;

  /// A [ForkTransition] specifies a [target] state within an orthogonal region
  /// of a [ParallelState], along with an optional [action] to execute during
  /// the transition and a [history] type for entry.
  ForkTransition({
    required this.target,
    this.action,
    this.history = HistoryType.none,
  });

  @override
  String toString() => 'ForkTransition(target: $target, history: $history)';
}

/// A pseudo-state that splits a transition into multiple simultaneous paths
/// targeting different regions of a [ParallelState].
///
/// Forks serve to enter a [ParallelState] at specific, non-default states
/// in its orthogonal regions.
///
/// Validation is performed during compilation. A valid fork must:
/// 1. Have at least two target transitions.
/// 2. Have a [ParallelState] as the Lowest Common Ancestor (LCA) of all targets.
/// 3. Have no more targets than there are regions in that [ParallelState].
/// 4. Target each orthogonal region at most once.
base class ForkState<S, E> extends BaseState<S, E> {
  /// The set of simultaneous transitions outgoing from this fork.
  final List<ForkTransition<S, E>> children;
  ParallelState<S, E>? _targetsLca;

  /// The lowest common ancestor between this fork state and its target
  /// parallel state. Pre-calculated during compilation.
  late final BaseState<S, E>? lca;

  /// Fork states are transient and never "active" in a resting sense.
  @override
  bool get isActive => false;

  @visibleForTesting
  ParallelState<S, E>? get targetsLca => _targetsLca;
  set targetsLca(ParallelState<S, E>? value) => _targetsLca = value;

  /// Forks serve to enter a [ParallelState] at specific, non-default states
  /// in its orthogonal regions.
  ///
  /// Validation is performed during compilation. A valid fork must:
  /// 1. Have at least two target transitions.
  /// 2. Have a [ParallelState] as the Lowest Common Ancestor (LCA) of all targets.
  /// 3. Have no more targets than there are regions in that [ParallelState].
  /// 4. Target each orthogonal region at most once.
  ForkState(super.id, super.hsm, {required this.children, super.parent});

  @override
  void _enter(
    List<BaseState<S, E>> path,
    int index, {
    EventData<E>? eventData,
    // ignore: unused_element_parameter
    HistoryType history = HistoryType.none,
  }) {
    hsm.observer.onStateEnter(this);

    final p = _targetsLca;
    if (p == null) {
      throw StateError('ForkState $id was not compiled correctly.');
    }

    // 1. Exit from current (Fork) up to LCA.
    final exitLca = lca;

    if (exitLca is State<S, E>) {
      exitLca.active?._exit(p.path);
    }
    // else if (exitLca == null) {
    //   (hsm.root as State<S, E>?)?.active?._exit(p.path);
    // }

    // 2. Enter path to P (excluding P).
    final nextPath = p.path;
    // Optimization: we can calculate the LCA index from the path length
    // because we know LCA is an ancestor of P (or null).
    final lcaIndex = exitLca == null ? -1 : exitLca.path.length - 1;

    for (var i = lcaIndex + 1; i < nextPath.length; i++) {
      final s = nextPath[i];
      if (s == p) break;

      if (s is State<S, E>) {
        if (!s.isActive) {
          if (!s.isRoot) {
            s.parent?._active = s;
            s.parent?._history = s;
          }
          hsm.observer.onStateEnter(s);
          s.onEnter?.call();
        }
      }
    }

    // 3. Execute transition actions.
    for (final child in children) {
      child.action?.call(eventData?.event, eventData?.data);
    }

    // 4. Enter Parallel State with targets.
    p.enterWith(children, eventData: eventData);
  }
}
