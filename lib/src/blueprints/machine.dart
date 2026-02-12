part of '../machine.dart';

/// The root entry point for a state machine definition.
class MachineBlueprint<S, E> {
  final String? name;
  final BasicBlueprint<S, E> root;

  MachineBlueprint({this.name, required this.root});

  (Machine<S, E>?, List<ValidationError>) compile({
    void Function()? onTerminated,
    MachineObserver<S, E>? observer,
  }) {
    final errors = <ValidationError>[];
    final statesMap = <S, BaseState<S, E>>{};

    final machine = Machine<S, E>._uninitialized(
      name: name ?? '',
      onTerminated: onTerminated,
      observer: observer ?? NoOpObserver<S, E>(),
    );

    // Pass 1: Create all state objects and build the tree structure.
    final runtimeRoot = _createState(root, null, machine, statesMap, errors);

    if (runtimeRoot is! State<S, E>) {
      errors.add(InvalidRootError());
      return (null, errors);
    }

    // Pass 2: Resolve transition targets and initial states.
    _resolveHierarchy(root, machine, statesMap, errors);

    if (errors.isNotEmpty) {
      return (null, errors);
    }

    // Pass 3: Pre-calculate paths for optimization.
    for (final state in statesMap.values) {
      state.path;
    }

    machine._setRoot(runtimeRoot, statesMap);

    return (machine, errors);
  }

  BaseState<S, E> _recordState(
    BaseState<S, E> newState,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    final oldState = statesMap[newState.id];
    if (oldState != null) {
      errors.add(DuplicateStateIdError(newState.id));
    } else {
      statesMap[newState.id] = newState;
    }
    return newState;
  }

  BaseState<S, E> _createState(
    BasicBlueprint<S, E> def,
    State<S, E>? parent,
    Machine<S, E> hsm,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    final BaseState<S, E> state;

    if (def is ParallelBlueprint<S, E>) {
      state = ParallelState<S, E>(
        def.id,
        hsm,
        parent: parent,
        onEnter: def.entry,
        onExit: def.exit,
      );
      // record state before visiting the children.
      _recordState(state, statesMap, errors);
      for (final childDef in def.children) {
        _createState(
          childDef,
          state as ParallelState<S, E>,
          hsm,
          statesMap,
          errors,
        );
      }
    } else if (def is CompositeBlueprint<S, E>) {
      final composite = state = State<S, E>(
        def.id,
        hsm,
        parent: parent,
        onEnter: def.entry,
        onExit: def.exit,
      );
      for (var event in def.defer) {
        composite.addDeferral(event);
      }
      // record state before visiting the children.
      _recordState(state, statesMap, errors);
      for (final childDef in def.children) {
        _createState(childDef, state as State<S, E>, hsm, statesMap, errors);
      }
    } else if (def is FinalBlueprint<S, E>) {
      state = FinalState<S, E>(def.id, hsm, parent: parent);
      _recordState(state, statesMap, errors);
    } else if (def is TerminateBlueprint<S, E>) {
      state = TerminateState<S, E>(def.id, hsm, parent: parent);
      _recordState(state, statesMap, errors);
    } else if (def is ChoiceBlueprint<S, E>) {
      state = ChoiceState<S, E>(def.id, hsm, parent: parent);
      _recordState(state, statesMap, errors);
    } else if (def is ForkBlueprint<S, E>) {
      // children will be filled in resolve.
      state = ForkState<S, E>(def.id, hsm, parent: parent, children: []);
      _recordState(state, statesMap, errors);
    } else {
      errors.add(UnknownDefinitionTypeError(def.runtimeType, def.id));
      state = State<S, E>(def.id, hsm);
      _recordState(state, statesMap, errors);
    }
    return state;
  }

  void _resolveHierarchy(
    BasicBlueprint<S, E> def,
    Machine<S, E> hsm,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    final state = statesMap[def.id];
    if (state == null) return;

    if (def is CompositeBlueprint<S, E> && state is State<S, E>) {
      _resolveComposite(def, state, hsm, statesMap, errors);
    } else if (def is ForkBlueprint<S, E> && state is ForkState<S, E>) {
      _resolveFork(def, state, hsm, statesMap, errors);
    } else if (def is ChoiceBlueprint<S, E> && state is ChoiceState<S, E>) {
      _resolveChoice(def, state, hsm, statesMap, errors);
    }
  }

  void _resolveChoice(
    ChoiceBlueprint<S, E> def,
    ChoiceState<S, E> choice,
    Machine<S, E> hsm,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    final defaultTransDef = def.defaultTransition;
    final defaultTarget = statesMap[defaultTransDef.target];
    if (defaultTarget == null) {
      errors.add(
        MissingStateError(defaultTransDef.target, def.id, 'default transition'),
      );
    } else {
      choice.defaultChoice = EventHandler<S, E>(
        target: defaultTarget,
        action: defaultTransDef.action,
        kind: defaultTransDef.kind,
        history: defaultTransDef.history,
      );
      if (defaultTarget is ParallelState &&
          defaultTransDef.history == .shallow) {
        errors.add(
          TransitionError(
            choice.id,
            defaultTarget.id,
            'choice default transition cannot target parallel state with shallow history',
          ),
        );
      }

      choice.defaultChoice.lca = lowestCommonAncestor(choice, defaultTarget);
    }

    for (final optionDef in def.options) {
      BaseState<S, E>? target;

      if (optionDef.target != null) {
        target = statesMap[optionDef.target];
        if (target == null) {
          errors.add(
            MissingStateError(optionDef.target, def.id, 'choice option'),
          );
        }
      }
      // TODO: Validation requirement: all choice targets must be valid.
      final handler = EventHandler<S, E>(
        target: target,
        guard: optionDef.guard,
        action: optionDef.action,
        kind: optionDef.kind,
        history: optionDef.history,
      );
      if (target is ParallelState && optionDef.history == .shallow) {
        errors.add(
          TransitionError(
            choice.id,
            target!.id,
            'choice optional transition cannot target parallel state with shallow history',
          ),
        );
      }

      if (target != null) {
        handler.lca = lowestCommonAncestor(choice, target);
      }
      choice.choiceOptions.add(handler);
    }
  }

  void _resolveFork(
    ForkBlueprint<S, E> def,
    ForkState<S, E> fork,
    Machine<S, E> hsm,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    for (final transDef in def.transitions) {
      final targetId = transDef.target;
      final target = statesMap[targetId];
      if (target == null) {
        errors.add(MissingStateError(targetId, def.id, 'fork branch'));
        continue;
      }

      final forkTrans = ForkTransition(
        target: target,
        action: transDef.action,
        history: transDef.history,
      );

      if (target is ParallelState && forkTrans.history == .shallow) {
        errors.add(
          TransitionError(
            fork.id,
            target.id,
            'fork transition cannot target parallel state with shallow history',
          ),
        );
      }

      forkTrans.lca = lowestCommonAncestor(fork, target);
      fork.children.add(forkTrans);
    }

    // 1. Fork states must have more than one target states.
    if (fork.children.length < 2) {
      errors.add(
        ForkValidationError(
          fork.id,
          'A fork must have at least two target transitions.',
        ),
      );
    }

    if (fork.children.isEmpty) return;

    final targets = [for (final child in fork.children) child.target];

    // 2. The LCA of all the targets must be a parallel state.
    final lca = targets.lca();
    if (lca is! ParallelState<S, E>) {
      errors.add(
        ForkValidationError(
          fork.id,
          'The Lowest Common Ancestor of all fork targets must be a ParallelState. '
          'Found: $lca',
        ),
      );
      return;
    }

    final p = fork.targetsLca = lca;
    fork.lca = lowestCommonAncestor(fork, p);

    // 3. Number of targets <= number of orthogonal regions.
    final regions = p.regions;
    if (fork.children.length > regions.length) {
      errors.add(
        ForkValidationError(
          fork.id,
          'Number of fork targets (${fork.children.length}) exceeds the number of '
          'orthogonal regions (${regions.length}) in $p.',
        ),
      );
    }

    // 4. Each orthogonal region targeted at most once.
    final regionMap = <BaseState<S, E>, BaseState<S, E>>{};
    for (var target in targets) {
      final path = target.path;
      final pIndex = path.indexOf(p);

      if (pIndex == -1 || pIndex == path.length - 1) {
        errors.add(
          ForkValidationError(
            fork.id,
            'Target $target is not a proper descendant of $p.',
          ),
        );
        continue;
      }

      final region = path[pIndex + 1];
      final other = regionMap[region];
      if (other != null) {
        errors.add(
          ForkValidationError(
            fork.id,
            'Multiple targets detected for the same orthogonal region: $region '
            'previous target: $other, failing target: $target.',
          ),
        );
        continue;
      }

      regionMap[region] = target;
    }
  }

  void _resolveComposite(
    CompositeBlueprint<S, E> def,
    State<S, E> state,
    Machine<S, E> hsm,
    Map<S, BaseState<S, E>> statesMap,
    List<ValidationError> errors,
  ) {
    if (def.initial != null) {
      final initial = statesMap[def.initial];
      if (initial == null) {
        errors.add(MissingStateError(def.initial, def.id, 'initial state'));
      } else if (!initial.isDescendantOf(state)) {
        errors.add(InvalidInitialStateError(def.initial, def.id));
      } else {
        state.initialState = initial;
        state.onInitialState = def.initialAction;
      }
    }

    // Map handlers
    for (final MapEntry(key: event, value: transDef)
        in (def.on ?? {}).entries) {
      final target = transDef.target != null
          ? statesMap[transDef.target]
          : null;
      if (transDef.target != null && target == null) {
        errors.add(
          MissingStateError(transDef.target, def.id, 'event handler "$event"'),
        );
      }

      BaseState<S, E>? lca;

      if (target != null) {
        // LCA has a technical meaning; however what we're storing is either
        // the LCA or the lowest state in a lineage if its local. This is for
        // caching reasons.
        final TransitionKind kind =
            transDef.kind == .local && target.hasLineage(state)
            ? .local
            : .external;
        // Local means we don't concern ourselves with lca; we do not want
        // to exit/enter the main source or exit/enter the main target.
        if (kind == .local) {
          if (state.isAncestorOf(target)) {
            // transition is down the tree
            lca = state;
          } else {
            // state is a descendant of target - upwards local transition
            lca = target;
          }
        } else {
          // no lineage.
          lca = lowestCommonAncestor(state, target);
        }
      }
      final handlers = state.addHandler(
        event,
        target: target,
        guard: transDef.guard,
        action: transDef.action,
        kind: transDef.kind,
        history: transDef.history,
      );

      // LCA has a technical meaning; however we're storing either the LCA or
      // the lowest state in a lineage if its local. This is for
      // caching reasons.
      handlers.last.lca = lca;

      if (target != null) {
        if (target is ParallelState && transDef.history == .shallow) {
          errors.add(
            TransitionError(
              state.id,
              target.id,
              'cannot target parallel state with shallow history',
            ),
          );
        }
      }
    }

    // Map completion handlers
    for (final compDef in (def.completion ?? <CompletionBlueprint<S, E>>[])) {
      final targetId = compDef.target;
      final target = targetId != null ? statesMap[targetId] : null;
      if (targetId != null && target == null) {
        errors.add(MissingStateError(targetId, def.id, 'completion handler'));
      }
      state.addCompletionHandler(
        target: target,
        guard: compDef.guard,
        action: compDef.action,
        kind: compDef.kind,
        history: compDef.history,
      );
      if (target != null) {
        state.completionHandlers.last.lca = lowestCommonAncestor(state, target);
        if (target is ParallelState && compDef.history == .shallow) {
          errors.add(
            TransitionError(
              state.id,
              target.id,
              'completion cannot target parallel state with shallow history',
            ),
          );
        }
      }
    }

    // Recurse
    for (final childDef in def.children) {
      _resolveHierarchy(childDef, hsm, statesMap, errors);
    }
  }
}
