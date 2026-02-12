part of '../machine.dart';

/// Base class for validation errors.
sealed class ValidationError {
  final String message;
  ValidationError(this.message);
  @override
  String toString() => 'ValidationError: $message';
}

/// Thrown when multiple states share the same ID.
final class DuplicateStateIdError<S> extends ValidationError {
  final S id;
  DuplicateStateIdError(this.id) : super('Duplicate state ID found: $id');
}

/// Thrown when a transition or initial state targets a non-existent state.
final class MissingStateError<S> extends ValidationError {
  final S id;
  final S sourceId;
  final String context;
  MissingStateError(this.id, this.sourceId, this.context)
    : super('Missing state "$id" in $context of state "$sourceId"');
}

/// Thrown when a ForkState fails structural validation.
final class ForkValidationError<S> extends ValidationError {
  final S forkId;
  final String details;
  ForkValidationError(this.forkId, this.details)
    : super('ForkState "$forkId" validation failed: $details');
}

final class TransitionError<S> extends ValidationError {
  final S baseId;
  final S targetId;
  final String details;
  TransitionError(this.baseId, this.targetId, this.details)
    : super('Transition "$baseId -> $targetId" validation failed: $details');
}

/// Thrown when an initial state is not a proper descendant of its parent state.
final class InvalidInitialStateError<S> extends ValidationError {
  final S initialStateId;
  final S parentId;
  InvalidInitialStateError(this.initialStateId, this.parentId)
    : super(
        'Initial state "$initialStateId" is not a proper descendant of "$parentId"',
      );
}

/// Thrown when the root state is not a composite or parallel state.
final class InvalidRootError extends ValidationError {
  InvalidRootError() : super('Root must be a State or ParallelState');
}

/// Thrown when an unknown definition type is encountered.
final class UnknownDefinitionTypeError<S> extends ValidationError {
  final Type type;
  final S id;
  UnknownDefinitionTypeError(this.type, this.id)
    : super('Unknown definition type "$type" for state "$id"');
}
