import 'package:test/test.dart';
import 'package:hierarchical_state_machine/src/machine.dart';

enum States {
  s,
  s1,
  s11,
  s12,
  s2,
  s21,
  s211,
  s212,
  s22,
  s221,
  s222,
  s2221,
  s2222,
  s3,
}

enum Events { next }

void main() {
  group('StateLCAExtension.lca() with SXY nomenclature', () {
    late Machine<States, Events> machine;

    setUp(() {
      final machineDef = MachineBlueprint<States, Events>(
        root: .composite(
          id: States.s,
          children: [
            .composite(
              id: States.s1,
              children: [
                .composite(id: States.s11),
                .composite(id: States.s12),
              ],
            ),
            .parallel(
              id: States.s2,
              children: [
                .composite(
                  id: States.s21,
                  children: [
                    .composite(id: States.s211),
                    .finish(id: States.s212),
                  ],
                ),
                .composite(
                  id: States.s22,
                  children: [
                    .composite(id: States.s221),
                    .parallel(
                      id: States.s222,
                      children: [
                        .composite(id: States.s2221),
                        .composite(id: States.s2222),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            .finish(id: States.s3),
          ],
        ),
      );

      final (compiled, errors) = machineDef.compile();
      expect(errors, isEmpty);
      machine = compiled!;
    });

    BaseState<States, Events> s(States id) =>
        machine.getState(id) as BaseState<States, Events>;

    test('LCA of siblings S11 and S12 is S1', () {
      expect([s(States.s11), s(States.s12)].lca(), s(States.s1));
    });

    test('LCA of S11 and S211 is S (Root)', () {
      expect([s(States.s11), s(States.s211)].lca(), s(States.s));
    });

    test('LCA involving FinalState S3 and S11 is S', () {
      expect([s(States.s3), s(States.s11)].lca(), s(States.s));
    });

    test(
      'LCA of states in orthogonal regions S211 and S221 is S2 (Parallel)',
      () {
        expect([s(States.s211), s(States.s221)].lca(), s(States.s2));
      },
    );

    test('LCA in nested ParallelState S2221 and S2222 is S222', () {
      expect([s(States.s2221), s(States.s2222)].lca(), s(States.s222));
    });

    test('LCA of S212 (Final) and S2221 (Nested Parallel Child) is S2', () {
      expect([s(States.s212), s(States.s2221)].lca(), s(States.s2));
    });

    test('Strict Ancestor Rule: LCA of S2 and S211 is S (parent of S2)', () {
      expect([s(States.s2), s(States.s211)].lca(), s(States.s));
    });

    test('LCA of three states across the machine is S', () {
      expect([s(States.s11), s(States.s2221), s(States.s3)].lca(), s(States.s));
    });

    test('LCA of single state S11 is its parent S1', () {
      expect([s(States.s11)].lca(), s(States.s1));
    });

    test('LCA of root state S is null', () {
      expect([s(States.s)].lca(), isNull);
    });
  });
}
