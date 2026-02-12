part of '../machine.dart';

abstract class BasicBlueprint<S, E> {
  final S id;
  BasicBlueprint({required this.id});

  /// A compound state that may contain children.
  ///
  /// Composite states have one region - that is, at most one child may be active
  /// at any one time.
  ///
  /// Composite states can have handlers, completion, entry and exit behaviors,
  /// record history, and define an initial state. This is the basis of nearly
  /// all machines.
  factory BasicBlueprint.composite({
    required S id,
    Map<E, TransitionBlueprint<S, E>>? on,
    Set<E> defer,
    List<CompletionBlueprint<S, E>>? completion,
    StateFunction? entry,
    StateFunction? exit,
    List<BasicBlueprint<S, E>> children,
    S? initial,
    StateFunction? initialAction,
  }) = CompositeBlueprint;

  /// A compound state in which each direct child forms a region.
  ///
  /// A parallel state is like a [CompositeState] except that all direct children
  /// are active at the same time - meaning they each have the ability to handle
  /// events.
  factory BasicBlueprint.parallel({
    required S id,
    Map<E, TransitionBlueprint<S, E>>? on,
    List<CompletionBlueprint<S, E>>? completion,
    StateFunction? entry,
    StateFunction? exit,
    List<BasicBlueprint<S, E>> children,
  }) = ParallelBlueprint;

  /// A pseudostate that chooses a transition based on guards.
  factory BasicBlueprint.choice({
    required S id,
    required DefaultTransitionBlueprint<S, E> defaultTransition,
    List<TransitionBlueprint<S, E>> options,
  }) = ChoiceBlueprint;

  /// A pseudostate that splits a transition into multiple simultaneous paths
  /// targeting different regions of a [ParallelBlueprint].
  ///
  /// Forks serve to enter a [ParallelBlueprint] at specific, non-default
  /// states in its orthogonal regions.
  ///
  /// Validation is performed during compilation. A valid fork must:
  /// 1. Have at least two target transitions.
  /// 2. Have a [ParallelBlueprint] as the Lowest Common Ancestor (LCA)
  ///    of all targets.
  /// 3. Have no more targets than there are regions in
  ///    that [ParallelBlueprint].
  /// 4. Target each orthogonal region at most once.
  factory BasicBlueprint.fork({
    required S id,
    required List<ForkTransitionBlueprint<S, E>> transitions,
  }) = ForkBlueprint;

  /// A state representing a final node in a region.
  ///
  /// grumble: .final cannot be used?
  factory BasicBlueprint.finish({required S id}) = FinalBlueprint;

  /// A state representing a terminate node for the whole machine.
  factory BasicBlueprint.terminate({required S id}) = TerminateBlueprint;
}

/// A compound state that may contain children.
///
/// Composite states have one region - that is, at most one child may be active
/// at any one time.
///
/// Composite states can have handlers, completion, entry and exit behaviors,
/// record history, and define an initial state. This is the basis of nearly
/// all machines.
class CompositeBlueprint<S, E> extends BasicBlueprint<S, E> {
  final Map<E, TransitionBlueprint<S, E>>? on;
  final Set<E> defer;
  final List<CompletionBlueprint<S, E>>? completion;
  final StateFunction? entry;
  final StateFunction? exit;
  final List<BasicBlueprint<S, E>> children;
  final S? initial;
  final StateFunction? initialAction;

  CompositeBlueprint({
    required super.id,
    this.on,
    this.defer = const {},
    this.completion,
    this.entry,
    this.exit,
    this.children = const [],
    this.initial,
    this.initialAction,
  });
}

/// A compound state in which each direct child forms a region.
///
/// A parallel state is like a [CompositeState] except that all direct children
/// are active at the same time - meaning they each have the ability to handle
/// events.
class ParallelBlueprint<S, E> extends CompositeBlueprint<S, E> {
  ParallelBlueprint({
    required super.id,
    super.children = const [],
    super.entry,
    super.exit,
    super.on,
    super.completion,
  });
}

/// A pseudostate that chooses a transition based on guards.
class ChoiceBlueprint<S, E> extends BasicBlueprint<S, E> {
  final DefaultTransitionBlueprint<S, E> defaultTransition;
  final List<TransitionBlueprint<S, E>> options;

  ChoiceBlueprint({
    required super.id,
    required this.defaultTransition,
    this.options = const [],
  });
}

/// A pseudostate that splits a transition into multiple simultaneous paths
/// targeting different regions of a [ParallelBlueprint].
///
/// Forks serve to enter a [ParallelBlueprint] at specific, non-default
/// states in its orthogonal regions.
///
/// Validation is performed during compilation. A valid fork must:
/// 1. Have at least two target transitions.
/// 2. Have a [ParallelBlueprint] as the Lowest Common Ancestor (LCA)
///    of all targets.
/// 3. Have no more targets than there are regions in
///    that [ParallelBlueprint].
/// 4. Target each orthogonal region at most once.
class ForkBlueprint<S, E> extends BasicBlueprint<S, E> {
  final List<ForkTransitionBlueprint<S, E>> transitions;

  ForkBlueprint({required super.id, required this.transitions});
}

/// A state representing a final node in a region.
class FinalBlueprint<S, E> extends BasicBlueprint<S, E> {
  FinalBlueprint({required super.id});
}

/// A state representing a terminate node for the whole machine.
class TerminateBlueprint<S, E> extends BasicBlueprint<S, E> {
  TerminateBlueprint({required super.id});
}
