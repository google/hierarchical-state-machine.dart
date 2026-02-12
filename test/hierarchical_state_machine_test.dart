// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:hierarchical_state_machine/src/machine.dart';
import 'package:test/test.dart';
import 'test_observer.dart';

/// A matcher that checks that an [AssertionError] was thrown.
final throwsAssertionError = throwsA(isA<AssertionError>());

void main() {
  group('Machine', () {
    group('constructor', () {
      test('works normally', () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(id: 'root'),
        );
        final (machine, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        expect(machine, isNotNull);
        expect(machine!.getState('root'), isNotNull);
        expect(machine.root.id, equals('root'));
      });

      test('generates stateChain for simple state', () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            initial: 'aa',
            children: [
              .composite(
                id: 'a',
                children: [.composite(id: 'aa')],
              ),
              .composite(id: 'b'),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        machine!.start();
        expect(machine.stateString, 'State(root)/State(a)/State(aa)');
      });

      test('generates stateChain for complex state', () {
        final machineDef = MachineBlueprint<String, String>(
          root: .composite(
            id: 'root',
            initial: 'ab',
            children: [
              .parallel(
                id: 'a',
                children: [
                  .composite(id: 'aa'),
                  .parallel(
                    id: 'ab',
                    children: [
                      .composite(id: 'aba'),
                      .composite(id: 'abb'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
        final (machine, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        machine!.start();
        expect(
          machine.stateString,
          'State(root)/ParallelState(a)/(State(aa),'
          'ParallelState(ab)/(State(aba),State(abb)))',
        );
      });
    });

    group('events', () {
      late MachineBlueprint<String, String> machineDef;
      late Machine<String, String> machine;

      test('handle queued events', () async {
        var t2 = false;
        machineDef = MachineBlueprint(
          root: .composite(
            id: 'root',
            on: {
              't1': .new(
                action: (e, d) {
                  machine.handle('t2', 'internal');
                },
              ),
              't2': .new(
                action: (e, d) {
                  t2 = true;
                },
              ),
            },
          ),
        );
        final (compiled, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        machine = compiled!;
        machine.start();

        var settled = false;
        expect(machine.isHandlingEvent, isFalse);
        expect(await machine.handle('t1', 'from test'), isTrue);
        expect(machine.isHandlingEvent, isTrue);
        unawaited(machine.settled.then((_) => settled = true));
        expect(settled, isFalse);
        expect(t2, isFalse);
        await Future.value();
        expect(t2, isTrue);
        expect(machine.isHandlingEvent, isFalse);
        expect(settled, isFalse);
        await Future.value();
        expect(settled, isTrue);
      });

      test('reports missing events', () async {
        machineDef = MachineBlueprint(
          root: .composite(
            id: 'root',
            initial: 'a',
            children: [.composite(id: 'a')],
          ),
        );
        final (compiled, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        expect(errors, isEmpty);
        machine = compiled!;
        machine.start();
        expect(await machine.handle('codefu', null), isFalse);
      });

      test('stop and handle guard', () async {
        machineDef = MachineBlueprint(root: .composite(id: 'root'));
        final (compiled, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        machine = compiled!;
        expect(await machine.handle('e1'), isFalse, reason: 'Not started');
        machine.start();
        expect(machine.isRunning, isTrue);
        machine.stop();
        expect(machine.isRunning, isFalse);
        expect(await machine.handle('e1'), isFalse, reason: 'Stopped');
      });

      test('error handling in event loop', () async {
        machineDef = MachineBlueprint(
          root: .composite(
            id: 'root',
            on: {
              'error': .new(action: (e, d) => throw Exception('test error')),
            },
          ),
        );
        final (compiled, errors) = machineDef.compile(
          observer: const TestPrintObserver(),
        );
        machine = compiled!;
        machine.start();
        expect(machine.handle('error'), throwsA(isA<Exception>()));
      });
    });
  });

  test('typed machine', () {
    final machineDef = MachineBlueprint<TestStates, TestEvents>(
      name: 'typed',
      root: .composite(
        id: TestStates.a,
        initial: TestStates.ab,
        children: [
          .composite(id: TestStates.aa),
          .composite(id: TestStates.ab),
          .composite(id: TestStates.b),
        ],
      ),
    );
    final (machine, errors) = machineDef.compile(
      observer: const TestPrintObserver(),
    );
    expect(errors, isEmpty);
    machine!.start();
    expect(machine.getState(TestStates.ab)!.isActive, isTrue);
  });

  group('State', () {
    late Machine<String, dynamic> machine;

    test('isRoot', () {
      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          children: [.composite(id: 'a')],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      expect(machine.root.isActive, isFalse); // Not started
      machine.start();
      expect(machine.root.isActive, isTrue);
    });

    test('can be nested', () {
      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          children: [.composite(id: 'a')],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      expect(machine.getState('a'), isNotNull);
      expect(machine.getState('a')!.parent?.id, equals('root'));
    });

    test('path generation', () {
      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          children: [.composite(id: 'a')],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      final a = machine.getState('a')!;
      expect(a.path.map((s) => s.id), ['root', 'a']);
    });

    test('report ancestry traits', () {
      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          children: [
            .composite(
              id: 'a',
              children: [.composite(id: 'a.b')],
            ),
          ],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      final a = machine.getState('a') as BaseState;
      final b = machine.getState('a.b') as BaseState;

      expect(b.isDescendantOf(a), isTrue);
      expect(a.isDescendantOf(b), isFalse);
      expect(a.isAncestorOf(b), isTrue);
      expect(b.isAncestorOf(a), isFalse);
      expect(a.hasLineage(b) && b.hasLineage(a), isTrue);
    });

    test('returns LCA of common states', () {
      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          children: [
            .composite(
              id: 'a',
              children: [
                .composite(
                  id: 'a.b',
                  children: [
                    .composite(
                      id: 'a.b.c',
                      children: [.composite(id: 'a.b.c.d')],
                    ),
                    .composite(id: 'a.b.cc'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      final b = machine.getState('a.b') as BaseState;
      final cc = machine.getState('a.b.cc') as BaseState;
      final d = machine.getState('a.b.c.d') as BaseState;

      expect(lowestCommonAncestor(d, cc), b);
      expect(lowestCommonAncestor(cc, b), machine.getState('a'));
    });

    test('can add handlers with different data types', () async {
      final event1 = 'event-1';
      final event2 = 'event-2';
      final data1 = 'data-1';
      final data2 = 3;

      final machineDef = MachineBlueprint<String, dynamic>(
        root: .composite(
          id: 'root',
          initial: 'a',
          on: {
            event1: TransitionBlueprint<String, dynamic>(
              target: 'a',
              guard: (event, data) => data == data1,
              action: (event, data) => expect(data, isA<String>()),
            ),
          },
          children: [
            .composite(
              id: 'a',
              on: {
                event2: TransitionBlueprint<String, dynamic>(
                  target: 'root',
                  guard: (event, data) => data != data2,
                  action: (event, data) => expect(data, isA<int>()),
                ),
              },
            ),
          ],
        ),
      );
      final (compiled, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine = compiled!;
      machine.start();

      await machine.handle(event1, data1);
      await machine.handle(event2, data2);
      expect(machine.getState('a')!.isActive, isTrue);
    });
  });

  group('Transitions', () {
    late List<String> records;

    void record(String msg) => records.add(msg);

    test('root initial state taken when starting', () {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          entry: () => record('root:enter'),
          initial: 'aa',
          children: [
            .composite(
              id: 'a',
              entry: () => record('a:enter'),
              children: [.composite(id: 'aa', entry: () => record('aa:enter'))],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      expect(records, ['root:enter', 'a:enter', 'aa:enter']);
    });

    test('onInitialState called (migrated to entry actions)', () {
      var called = <String, bool>{};
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          entry: () => called['root'] = true,
          initial: 'aa',
          children: [
            .composite(
              id: 'a',
              entry: () => called['a'] = true,
              children: [.composite(id: 'aa')],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      expect(called, {'root': true, 'a': true});
    });

    test('simple sibling transition', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          entry: () => record('root:enter'),
          initial: 'aa',
          children: [
            .composite(
              id: 'a',
              entry: () => record('a:enter'),
              children: [
                .composite(
                  id: 'aa',
                  entry: () => record('aa:enter'),
                  exit: () => record('aa:exit'),
                  on: {
                    't1': .new(
                      target: 'ab',
                      action: (e, d) => record('aa:$e'),
                      kind: TransitionKind.external,
                    ),
                  },
                ),
                .composite(id: 'ab', entry: () => record('ab:enter')),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear(); // Clear initial entry records
      await machine.handle('t1');
      expect(records, ['aa:exit', 'aa:t1', 'ab:enter']);
    });

    test('parallel children all entered', () {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          entry: () => record('root:enter'),
          initial: 'b',
          children: [
            .parallel(
              id: 'b',
              entry: () => record('b:enter'),
              children: [
                .composite(
                  id: 'ba',
                  entry: () => record('ba:enter'),
                  initial: 'baa',
                  children: [
                    .composite(id: 'baa', entry: () => record('baa:enter')),
                  ],
                ),
                .composite(
                  id: 'bb',
                  entry: () => record('bb:enter'),
                  initial: 'bba',
                  children: [
                    .composite(id: 'bba', entry: () => record('bba:enter')),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      // The order depends on children order and initial state transitions.
      expect(records, [
        'root:enter',
        'b:enter',
        'ba:enter',
        'baa:enter',
        'bb:enter',
        'bba:enter',
      ]);
    });

    test('parallel children all exited', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'b',
          on: {'t1': .new(target: 'a')},
          children: [
            .composite(id: 'a', entry: () => record('a:enter')),
            .parallel(
              id: 'b',
              exit: () => record('b:exit'),
              children: [
                .composite(
                  id: 'ba',
                  exit: () => record('ba:exit'),
                  initial: 'baa',
                  children: [
                    .composite(id: 'baa', exit: () => record('baa:exit')),
                  ],
                ),
                .composite(
                  id: 'bb',
                  exit: () => record('bb:exit'),
                  initial: 'bba',
                  children: [
                    .composite(id: 'bba', exit: () => record('bba:exit')),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      await machine.handle('t1');
      expect(records, [
        'baa:exit',
        'ba:exit',
        'bba:exit',
        'bb:exit',
        'b:exit',
        'a:enter',
      ]);
    });

    test('parallel children delivered events', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'b',
          children: [
            .parallel(
              id: 'b',
              children: [
                .composite(
                  id: 'ba',
                  initial: 'baa',
                  children: [.composite(id: 'baa')],
                  on: {
                    't1': .new(
                      guard: (e, d) {
                        records.add('ba:g:$e');
                        return false;
                      },
                    ),
                  },
                ),
                .composite(
                  id: 'bb',
                  initial: 'bba',
                  children: [.composite(id: 'bba')],
                  on: {
                    't1': .new(
                      guard: (e, d) {
                        records.add('bb:g:$e');
                        return false;
                      },
                    ),
                  },
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      await machine.handle('t1');
      await machine.handle('t1');
      expect(
        records,
        unorderedEquals(['bb:g:t1', 'ba:g:t1', 'bb:g:t1', 'ba:g:t1']),
      );
    });

    test('local transition to ancestor', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'aaa',
          children: [
            .composite(
              id: 'a',
              entry: () => record('a:enter'),
              children: [
                .composite(
                  id: 'aa',
                  entry: () => record('aa:enter'),
                  children: [
                    .composite(
                      id: 'aaa',
                      on: {
                        't1': .new(
                          target: 'a',
                          action: (e, d) => record('aaa:$e'),
                          kind: TransitionKind.local,
                        ),
                      },
                      exit: () => record('aaa:exit'),
                    ),
                  ],
                  exit: () => record('aa:exit'),
                ),
              ],
              exit: () => record('a:exit'),
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['aaa:exit', 'aa:exit', 'aaa:t1']);
    });

    test('local transition to descendant', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'a',
          children: [
            .composite(
              id: 'a',
              on: {
                't1': .new(
                  target: 'aaa',
                  action: (e, d) => record('a:$e'),
                  kind: TransitionKind.local,
                ),
              },
              children: [
                .composite(
                  id: 'aa',
                  entry: () => record('aa:enter'),
                  children: [
                    .composite(id: 'aaa', entry: () => record('aaa:enter')),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['a:t1', 'aa:enter', 'aaa:enter']);
    });

    test('external transition to ancestor', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'aaa',
          children: [
            .composite(
              id: 'aa',
              entry: () => record('aa:enter'),
              exit: () => record('aa:exit'),
              children: [
                .composite(
                  id: 'aaa',
                  on: {
                    't1': .new(
                      target: 'aa',
                      action: (e, d) => record('aaa:$e'),
                      kind: TransitionKind.external,
                    ),
                  },
                  exit: () => record('aaa:exit'),
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['aaa:exit', 'aa:exit', 'aaa:t1', 'aa:enter']);
    });

    test('external transition to descendant', () async {
      records = [];
      final machineDef = MachineBlueprint<String, String>(
        root: .composite(
          id: 'root',
          initial: 'a',
          children: [
            .composite(
              id: 'a',
              entry: () => record('a:enter'),
              exit: () => record('a:exit'),
              on: {
                't1': .new(
                  target: 'aaa',
                  action: (e, d) => record('a:$e'),
                  kind: TransitionKind.external,
                ),
              },
              children: [
                .composite(
                  id: 'aa',
                  entry: () => record('aa:enter'),
                  children: [
                    .composite(id: 'aaa', entry: () => record('aaa:enter')),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final (machine, _) = machineDef.compile(
        observer: const TestPrintObserver(),
      );
      machine!.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['a:exit', 'a:t1', 'a:enter', 'aa:enter', 'aaa:enter']);
    });
  });
}

enum TestEvents { one, two, three, four }

enum TestStates { a, aa, ab, b }
