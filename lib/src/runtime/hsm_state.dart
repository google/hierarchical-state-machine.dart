part of '../machine.dart';

/// The read-only view of a state within a [Machine].
sealed class HsmState<S, E> {
  HsmState._();

  /// The unique identifier for this state.
  S get id;

  /// The parent state, if any.
  HsmState<S, E>? get parent;

  /// Whether this state is currently active.
  bool get isActive;

  /// Returns the state path from root to this state.
  List<HsmState<S, E>> get path;
}
