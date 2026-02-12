part of '../machine.dart';

/// Defines a transition to a target state.
final class TransitionBlueprint<S, E> {
  final S? target;
  final GuardFunction<E?, Object?>? guard;
  final ActionFunction<E?, Object?>? action;
  final TransitionKind kind;
  final HistoryType history;

  TransitionBlueprint({
    this.target,
    this.guard,
    this.action,
    this.kind = TransitionKind.local,
    this.history = HistoryType.none,
  });
}

/// Specialized transition for choice states (no guard).
final class DefaultTransitionBlueprint<S, E> {
  final S target;
  final ActionFunction<E?, Object?>? action;
  final TransitionKind kind;
  final HistoryType history;

  DefaultTransitionBlueprint({
    required this.target,
    this.action,
    this.kind = TransitionKind.local,
    this.history = HistoryType.none,
  });
}

/// Specialized transition for fork states.
final class ForkTransitionBlueprint<S, E> {
  final S target;
  final ActionFunction<E?, Object?>? action;
  final HistoryType history;

  ForkTransitionBlueprint({
    required this.target,
    this.action,
    this.history = HistoryType.none,
  });
}

/// Defines a completion transition (no event).
///
/// A Completion Event is an internal control signal, not an external
/// data carrier. It signifies solely that "all Behaviors associated with
/// the source State... have completed execution". They execute with dispatching
/// priority. UML 14.2.3.8.3
final class CompletionBlueprint<S, E> {
  final S? target;
  final bool Function()? guard;
  final void Function()? action;
  final TransitionKind kind;
  final HistoryType history;

  /// Defines a completion transition (no event).
  ///
  /// A Completion Event is an internal control signal, not an external
  /// data carrier. It signifies solely that "all Behaviors associated with
  /// the source State... have completed execution". They execute with dispatching
  /// priority. UML 14.2.3.8.3
  CompletionBlueprint({
    this.target,
    this.guard,
    this.action,
    this.kind = TransitionKind.local,
    this.history = HistoryType.none,
  });
}
