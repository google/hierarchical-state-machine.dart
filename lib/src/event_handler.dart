part of 'machine.dart';

/// Defines the type of history restoration to apply during a transition.
enum HistoryType {
  /// No history restoration.
  none,

  /// Restore the last active direct child state.
  shallow,

  /// Restore the last active active leaf state (recursively).
  deep,
}

/// Represents the result of an event handling attempt.
enum HandledStatus {
  /// The event was not handled by the state or its descendants.
  unhandled,

  /// The event was handled (either by a transition or an internal action).
  handled,

  /// The event was deferred by the state.
  deferred,
}

enum TransitionKind {
  /// Implies that the Transition exits its source Vertex.
  /// This is the default kind.
  external,

  /// Implies that the Transition does not exit its containing State.
  /// The target Vertex must be different from its source Vertex.
  local,
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
/// The handler can define the transition [kind] as external or local. Local
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
final class EventHandler<S, E> {
  final BaseState<S, E>? target;

  /// The lowest common ancestor between the source state and the target state.
  /// Pre-calculated during compilation for performance.
  BaseState<S, E>? lca;

  /// Methods use to gate the processing of an [EventTarget] by the associated
  /// [State] it is registered with.
  final GuardFunction<E?, dynamic>? guard;

  /// Methods used by [EventHandler] during a transition, after having exited
  /// all states to the lowest common ancestor.
  final ActionFunction<E?, dynamic>? action;

  final TransitionKind kind;

  /// The type of history restoration to apply when entering the target state.
  final HistoryType history;

  bool get isInternal => target == null;

  String? _lazy;

  EventHandler({
    this.target,
    this.guard,
    this.action,
    this.kind = .local,
    this.history = HistoryType.none,
  });

  @override
  String toString() {
    _lazy ??=
        'EventTarget${(target: isInternal ? 'internal' : target, guard: guard != null, action: action != null, kind: kind, history: history)}}';
    return _lazy!;
  }
}

/// A handler for completion transitions (joins), evaluated when a region completes.
final class CompletionHandler<S, E> {
  final BaseState<S, E>? target;

  /// The lowest common ancestor between the source state and the target state.
  /// Pre-calculated during compilation for performance.
  BaseState<S, E>? lca;

  final bool Function()? guard;
  final void Function()? action;

  final TransitionKind kind;

  /// The type of history restoration to apply when entering the target state.
  final HistoryType history;

  CompletionHandler({
    this.target,
    this.guard,
    this.action,
    this.history = .none,
    this.kind = .local,
  });
}

/// Simple method called for [State.onEnter], [State.onExit], and
/// [State.onInitialState].
typedef StateFunction = void Function();

typedef GuardFunction<E, D> = bool Function(E event, D data);
typedef ActionFunction<E, D> = void Function(E event, D data);
