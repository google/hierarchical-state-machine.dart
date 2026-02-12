import 'package:test/test.dart';
import 'package:hierarchical_state_machine/src/machine.dart';

void main() {
  group('Definitions API Structure', () {
    test('MachineDefinition should accept a name and root', () {
      final machine = MachineBlueprint<String, String>(
        name: 'TestMachine',
        root: .composite(id: 'root'),
      );
      expect(machine.name, equals('TestMachine'));
      expect(machine.root, isNotNull);
    });

    test('StateDefinition should accept basic properties', () {
      final state = CompositeBlueprint<String, String>(
        id: 's1',
        on: {'event': .new(target: 'next')},
      );
      expect(state.id, equals('s1'));
      expect(state.on?['event']?.target, 'next');
    });

    test('ChoiceStateDefinition should require defaultTransition', () {
      final defaultTrans = DefaultTransitionBlueprint<String, String>(
        target: 's2',
      );
      final choice = ChoiceBlueprint<String, String>(
        id: 'c1',
        defaultTransition: defaultTrans,
        options: [.new(target: 's3', guard: (e, d) => true)],
      );
      expect(choice.id, equals('c1'));
      expect(choice.defaultTransition, equals(defaultTrans));
      expect(choice.options.length, equals(1));
    });

    test('ForkStateDefinition should require transitions', () {
      final fork = ForkBlueprint<String, String>(
        id: 'f1',
        transitions: [
          .new(target: 'r1'),
          .new(target: 'r2'),
        ],
      );
      expect(fork.id, equals('f1'));
      expect(fork.transitions.length, equals(2));
    });

    test('StateDefinition should allow pseudostates as children', () {
      final state = CompositeBlueprint<String, String>(
        id: 's1',
        children: [
          .choice(
            id: 'c1',
            defaultTransition: .new(target: 's2'),
          ),
        ],
      );

      expect(state.children.first, isA<ChoiceBlueprint>());
    });

    test(
      'ParallelStateDefinition should only allow StateDefinition children',
      () {
        final child = CompositeBlueprint<String, String>(id: 'child');
        final state = ParallelBlueprint<String, String>(
          id: 'p1',
          children: [child],
        );
        expect(state.children.first, equals(child));
      },
    );

    test('TransitionDefinition should have default kind and history', () {
      final transition = TransitionBlueprint<String, String>(target: 'next');
      expect(transition.kind, equals(TransitionKind.local));
      expect(transition.history, equals(HistoryType.none));
    });
  });

  group('Compilation Logic', () {
    test('MachineDefinition.compile() should build a valid Machine', () {
      final s1 = CompositeBlueprint<String, String>(id: 's1');
      final root = CompositeBlueprint<String, String>(
        id: 'root',
        initial: 's1',
        children: [s1],
      );
      final machineDef = MachineBlueprint<String, String>(
        name: 'TestMachine',
        root: root,
      );
      final (machine, errors) = machineDef.compile();

      expect(errors, isEmpty);
      expect(machine, isNotNull);
      expect(machine!.name, equals('TestMachine'));
      expect(machine.root.id, equals('root'));
      expect(machine.getState('s1'), isNotNull);
    });

    test(
      'MachineDefinition.compile() should return errors for missing initial state',
      () {
        final root = CompositeBlueprint<String, String>(
          id: 'root',
          initial: 'missing',
        );
        final machineDef = MachineBlueprint<String, String>(root: root);
        final (machine, errors) = machineDef.compile();

        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(errors.first, isA<MissingStateError>());
        expect(
          errors.first.message,
          contains('Missing state "missing" in initial state of state "root"'),
        );
      },
    );

    test(
      'MachineDefinition.compile() should return errors for duplicate state IDs',
      () {
        final s1 = CompositeBlueprint<String, String>(id: 'dup');
        final s2 = CompositeBlueprint<String, String>(id: 'dup');
        final root = CompositeBlueprint<String, String>(
          id: 'root',
          children: [s1, s2],
        );
        final machineDef = MachineBlueprint<String, String>(root: root);
        final (machine, errors) = machineDef.compile();

        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(errors.any((e) => e is DuplicateStateIdError), isTrue);
      },
    );

    test(
      'MachineDefinition.compile() should calculate paths for all states',
      () {
        final s11 = CompositeBlueprint<String, String>(id: 's11');
        final s1 = CompositeBlueprint<String, String>(
          id: 's1',
          children: [s11],
        );
        final root = CompositeBlueprint<String, String>(
          id: 'root',
          children: [s1],
        );
        final machineDef = MachineBlueprint<String, String>(root: root);
        final (machine, errors) = machineDef.compile();

        expect(errors, isEmpty);
        expect(machine, isNotNull);
        final runtimeS11 = machine!.getState('s11');
        expect(runtimeS11, isNotNull);
        expect([
          ...runtimeS11!.path.map((s) => s.id),
        ], equals(['root', 's1', 's11']));
      },
    );

    test(
      'MachineDefinition.compile() should pre-calculate LCAs for transitions',
      () {
        final machineDef = MachineBlueprint<String, String>(
          root: CompositeBlueprint<String, String>(
            id: 'root',
            children: [
              CompositeBlueprint<String, String>(
                id: 's1',
                on: {'goto_s2': .new(target: 's2')},
              ),
              CompositeBlueprint<String, String>(id: 's2'),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile();

        expect(errors, isEmpty);
        expect(machine, isNotNull);

        final runtimeS1 = machine!.getState('s1') as State<String, String>;
        final handler = runtimeS1.handlers['goto_s2']!.first;
        expect(handler.lca, isNotNull);
        expect(handler.lca!.id, equals('root'));
      },
    );

    test(
      'MachineDefinition.compile() should pre-calculate LCAs for ChoiceState transitions',
      () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            children: [
              .composite(id: 's1'),
              .composite(id: 's2'),
              .choice(
                id: 'choice',
                defaultTransition: .new(target: 's1'),
                options: [.new(target: 's2', guard: (e, d) => true)],
              ),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile();

        expect(errors, isEmpty);
        expect(machine, isNotNull);

        final runtimeChoice =
            machine!.getState('choice') as ChoiceState<String, String>;
        expect(runtimeChoice.defaultChoice.lca, isNotNull);
        expect(runtimeChoice.defaultChoice.lca!.id, equals('root'));
        expect(runtimeChoice.choiceOptions[0].lca, isNotNull);
        expect(runtimeChoice.choiceOptions[0].lca!.id, equals('root'));
      },
    );

    test(
      'MachineDefinition.compile() should pre-calculate LCAs for ForkState transitions',
      () {
        final machineDef = MachineBlueprint<String, String>(
          root: CompositeBlueprint<String, String>(
            id: 'root',
            children: [
              ParallelBlueprint<String, String>(
                id: 'p1',
                children: [
                  CompositeBlueprint<String, String>(id: 's1'),
                  CompositeBlueprint<String, String>(id: 's2'),
                ],
              ),
              ForkBlueprint<String, String>(
                id: 'fork',
                transitions: [
                  .new(target: 's1'),
                  .new(target: 's2'),
                ],
              ),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile();

        expect(errors, isEmpty);
        expect(machine, isNotNull);

        final fork = machine!.getState('fork') as ForkState<String, String>;
        expect(fork.children[0].lca, isNotNull);
        expect(fork.children[0].lca!.id, equals('root'));
        expect(fork.children[1].lca, isNotNull);
        expect(fork.children[1].lca!.id, equals('root'));
        expect(fork.targetsLca?.id, 'p1');
      },
    );

    test('MachineDefinition.compile() should resolve ForkState targets', () {
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'p1',
          children: [
            .parallel(
              id: 'p1',
              children: [
                .composite(id: 's1'),
                .composite(id: 's2'),
              ],
            ),
            .fork(
              id: 'fork',
              transitions: [
                .new(target: 's1'),
                .new(target: 's2'),
              ],
            ),
          ],
        ),
      );
      final (machine, errors) = machineDef.compile();

      expect(errors, isEmpty);
      expect(machine, isNotNull);

      final fork = machine!.getState('fork') as ForkState<String, String>;
      expect(fork, isNotNull);
      expect(fork.children, hasLength(2));
    });

    test('MachineDefinition.compile() should resolve ChoiceState targets', () {
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'choice',
          children: [
            .composite(id: 's1'),
            .composite(id: 's2'),
            ChoiceBlueprint<String, String>(
              id: 'choice',
              defaultTransition: .new(target: 's1'),
              options: [.new(target: 's2', guard: (e, d) => true)],
            ),
          ],
        ),
      );
      final (machine, errors) = machineDef.compile();

      expect(errors, isEmpty);
      expect(machine, isNotNull);

      final runtimeChoice =
          machine!.getState('choice') as ChoiceState<String, String>;
      expect(runtimeChoice, isNotNull);
      expect(runtimeChoice.defaultChoice.target!.id, equals('s1'));
      expect(runtimeChoice.choiceOptions.length, equals(1));
      expect(runtimeChoice.choiceOptions[0].target!.id, equals('s2'));
    });

    test(
      'MachineDefinition.compile() should return errors for missing fork target',
      () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            children: [
              ForkBlueprint<String, String>(
                id: 'fork',
                transitions: [.new(target: 'missing')],
              ),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile();

        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(
          errors.any(
            (e) =>
                e is MissingStateError &&
                e.id == 'missing' &&
                e.context.contains('fork branch'),
          ),
          isTrue,
        );
      },
    );

    test(
      'MachineDefinition.compile() should return errors for missing event handler target',
      () {
        final root = CompositeBlueprint<String, String>(
          id: 'root',
          on: {'event': .new(target: 'missing')},
        );
        final machineDef = MachineBlueprint<String, String>(root: root);
        final (machine, errors) = machineDef.compile();

        expect(machine, isNull);
        expect(errors, isNotEmpty);
        expect(
          errors.any(
            (e) =>
                e is MissingStateError &&
                e.id == 'missing' &&
                e.context.contains('event handler "event"'),
          ),
          isTrue,
        );
      },
    );

    test(
      'MachineDefinition.compile() should return errors for missing choice targets',
      () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            children: [
              .choice(
                id: 'choice',
                defaultTransition: .new(target: 'missing_default'),
                options: [.new(target: 'missing_option')],
              ),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile();

        expect(machine, isNull);
        expect(errors.length, equals(2));
        expect(
          errors.any((e) => e.message.contains('missing_default')),
          isTrue,
        );
        expect(errors.any((e) => e.message.contains('missing_option')), isTrue);
      },
    );
  });
}
