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

import 'package:logging/logging.dart';
import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';
import 'package:test/test.dart';

/// A matcher that checks that an [AssertionError] was thrown.
final throwsAssertionError = throwsA(isA<AssertionError>());

void main() {
  Logger.root.level = Level.ALL;
  final startTime = DateTime.now();
  Logger.root.onRecord.listen((LogRecord rec) {
    var elapsed = DateTime.now().difference(startTime);
    var error = rec.error == null ? '' : ' ${rec.error}';
    var stackTrace = rec.stackTrace == null ? '' : '\n${rec.stackTrace}';
    print(
      '$elapsed [${rec.level}] ${rec.loggerName}: '
      '${rec.message}$error$stackTrace',
    );
  });

  group('Machine', () {
    group('constructor', () {
      test('works normally', () {
        var root = State('root');
        var machine = Machine.rooted(root);
        expect(machine['root'], same(root));
        expect(machine.root, same(root));
        expect(root.machine, same(machine));
      });
      test('asserts with another machine\'s root', () {
        var badState = State('root');
        Machine.rooted(badState);
        expect(() => Machine.rooted(badState), throwsAssertionError);
      });
      test('generates stateChain for simple state', () {
        var root = State('root');
        var machine = Machine.rooted(root);
        State('a', parent: root);
        State('b', parent: root);
        State('aa', parent: machine['a']);
        root.initialState = machine['aa'];
        machine.start();
        expect(machine.stateString, 'State(root)/State(a)/State(aa)');
      });
      test('generates stateChain for complex state', () {
        var root = State('root');
        var machine = Machine.rooted(root);
        ParallelState('a', parent: root);
        State('aa', parent: machine['a']);
        ParallelState('ab', parent: machine['a']);
        State('aba', parent: machine['ab']);
        State('abb', parent: machine['ab']);

        root.initialState = machine['ab'];
        machine.start();
        expect(
          machine.stateString,
          'State(root)/ParallelState(a)/(State(aa),'
          'ParallelState(ab)/(State(aba),State(abb)))',
        );
      });
      test('factory', () {
        var hsm = Machine(name: 'foo', rootId: 'root');
        expect(hsm, isNotNull);
        expect(hsm.root, isNotNull);
        expect(hsm.root.id, 'root');
        expect(hsm.root.parent, isNull);
      });
    });

    group('events', () {
      late Machine machine;
      late State root;
      setUp(() {
        root = State('root');
        machine = Machine.rooted(root);
      });

      test('handle queued events', () async {
        var t2 = false;
        root.addHandler(
          't1',
          action: (e, d) {
            machine.handle('t2', 'internal');
          },
        );
        root.addHandler(
          't2',
          action: (e, d) {
            t2 = true;
          },
        );
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
        final a = State('a', parent: root);
        root.initialState = a;
        machine.start();
        expect(await machine.handle('codefu', null), isFalse);
      });
    });
  });

  test('typed machine', () {
    var hsm = Machine<TestStates, TestEvents>(
      name: 'typed',
      rootId: TestStates.a,
      log: Logger('[typed ]'),
    );
    final a = hsm.root;
    // And this is why we write helper functions because this sucks.
    State<TestStates, TestEvents>(TestStates.aa, parent: a);
    var ab = a.newChild(TestStates.ab);
    a.newChild(TestStates.b);
    a.initialState = ab;
    hsm.start();
    expect(ab.isActive, isTrue);
  });

  group('State', () {
    late Machine<String, dynamic> machine;
    late State<String, dynamic> root;
    late State<String, dynamic> a;

    setUp(() {
      root = State('root');
      machine = Machine.rooted(root);
      a = State('a', parent: root);
    });

    test('isRoot', () {
      expect(root.isRoot, isTrue);
      expect(a.isRoot, isFalse);
    });

    test('can be nested', () {
      expect(machine['a'], same(a));
      expect(a.parent, same(root));
    });

    test('must be unique', () {
      expect(() => State('a', parent: a), throwsArgumentError);
    });

    test('path generation', () {
      expect(a.path, [root, a]);
    });

    test('report ancestry traits', () {
      final b = State('a.b', parent: a);
      expect(b.isDescendantOf(a), isTrue);
      expect(a.isDescendantOf(b), isFalse);
      expect(a.isAncestorOf(b), isTrue);
      expect(b.isAncestorOf(a), isFalse);
      expect(a.hasLineage(b) && b.hasLineage(a), isTrue);

      expect(a.isDescendantOf(a), isFalse);
      expect(a.isAncestorOf(a), isFalse);
      expect(a.hasLineage(a), isFalse);

      var c = State('c', parent: root);
      expect(c.hasLineage(a), isFalse);
    });

    test('returns LCA of common states', () {
      final b = State('a.b', parent: a);
      var c = State('a.b.c', parent: b);
      var cc = State('a.b.cc', parent: b);
      var d = State('a.b.c.d', parent: c);

      expect(State.lowestCommonAncestor(d, cc), b);
      expect(State.lowestCommonAncestor(cc, c), b);
      expect(State.lowestCommonAncestor(cc, b), a);
    });

    test('returns null for LCA of uncommon states (bad state code)', () {
      final b = State('a.b', parent: a);
      var c = State('a.b.c', parent: b);

      var root2 = State('root');
      Machine.rooted(root2);
      var a1 = State('a', parent: root2);
      final b1 = State('a.b', parent: a1);

      expect(State.lowestCommonAncestor(b1, c), isNull);
    });

    test('can add handlers with different data types', () {
      final event1 = 'event-1';
      final event2 = 'event-2';
      final data1 = 'data-1';
      final data2 = 3;

      machine.start();
      root.addHandler<String>(
        event1,
        action: (event, String data) => expect(data, TypeMatcher<String>()),
        guard: (event, String data) => data == data1,
        target: a,
      );
      a.addHandler<int>(
        event2,
        action: (event, int data) => expect(data, TypeMatcher<int>()),
        guard: (event, int data) => data != data2,
        target: root,
      );

      machine.handle(event1, data1);
      machine.handle(event2, data2);
      expect(a.isActive, isTrue);
    });
  });

  group('Transitions', () {
    final log = Logger('[Transitions] ');
    late State root;
    late Machine machine;
    late List<String> records;

    void record(String msg) => records.add(msg);
    setUp(() {
      root = State('root', log: log)
        ..onEnter = () {
          record('root:enter');
        }
        ..onExit = () {
          record('root:exit');
        };

      machine = Machine.rooted(root, log: log);

      records = [];
      final a = State('a', parent: root)
        ..onEnter = () {
          record('a:enter');
        }
        ..onExit = () {
          record('a:exit');
        };
      var aa = State('aa', parent: a)
        ..onEnter = () {
          record('aa:enter');
        }
        ..onExit = () {
          record('aa:exit');
        };
      State('aaa', parent: aa)
        ..onEnter = () {
          record('aaa:enter');
        }
        ..onExit = () {
          record('aaa:exit');
        };
      State('aab', parent: aa)
        ..onEnter = () {
          record('aab:enter');
        }
        ..onExit = () {
          record('aab:exit');
        };

      var ab = State('ab', parent: a)
        ..onEnter = () {
          record('ab:enter');
        }
        ..onExit = () {
          record('ab:exit');
        };

      State('aba', parent: ab)
        ..onEnter = () {
          record('aba:enter');
        }
        ..onExit = () {
          record('aba:exit');
        };

      State('ac', parent: a)
        ..onEnter = () {
          record('ac:enter');
        }
        ..onExit = () {
          record('ac:exit');
        };

      // B-Parallel[A->AA && B->BA]
      final b = ParallelState('b', parent: root)
        ..onEnter = () {
          record('b:enter');
        }
        ..onExit = () {
          record('b:exit');
        };

      final ba = State('ba', parent: b)
        ..onEnter = () {
          record('ba:enter');
        }
        ..onExit = () {
          record('ba:exit');
        };

      State('baa', parent: ba)
        ..onEnter = () {
          record('baa:enter');
        }
        ..onExit = () {
          record('baa:exit');
        };

      final bb = State('bb', parent: b)
        ..onEnter = () {
          record('bb:enter');
        }
        ..onExit = () {
          record('bb:exit');
        };

      State('bba', parent: bb)
        ..onEnter = () {
          record('bba:enter');
        }
        ..onExit = () {
          record('bba:exit');
        };
    });

    test('root initial state taken when starting', () {
      root.initialState = machine['aa'];
      machine.start();
      expect(records, ['root:enter', 'a:enter', 'aa:enter']);
    });

    test('onInitialState ignored if no initialState', () {
      var called = {};
      root.onInitialState = () {
        called['root'] = true;
      };
      machine.start();
      expect(called, {});
    });

    test('onInitialState called', () {
      var called = {};
      root.onInitialState = () {
        called['root'] = true;
      };

      final a = machine['a'];
      root.initialState = a;

      a!.initialState = machine['aa'];
      a.onInitialState = () => called['a'] = true;

      machine['aa']!.initialState = machine['aab'];

      machine.start();
      expect(called, {'root': true, 'a': true});
    });

    test('simple sibling transition', () {
      var aa = machine['aa'];
      root.initialState = aa;
      aa!.addHandler(
        't1',
        target: machine['ab'],
        action: (e, __) => record('aa:$e'),
        local: false,
      );
      machine.start();
      machine.handle('t1');
      expect(records, [
        'root:enter',
        'a:enter',
        'aa:enter',
        'aa:exit',
        'aa:t1',
        'ab:enter'
      ]);
    });

    test('parallel children all entered', () {
      root.initialState = machine['b'];
      machine['b']!.initialState = machine['baa'];
      machine['bb']!.initialState = machine['bba'];

      machine.start();
      expect(records, [
        'root:enter',
        'b:enter',
        'ba:enter',
        'bb:enter',
        'bba:enter',
        'baa:enter'
      ]);
    });

    test('parallel children all exited', () async {
      root.initialState = machine['b'];
      machine['b']!.initialState = machine['baa'];
      machine['bb']!.initialState = machine['bba'];

      machine.start();
      records.clear();
      root.addHandler('t1', target: machine['a']);
      await machine.handle('t1');
      expect(
        records,
        ['baa:exit', 'ba:exit', 'bba:exit', 'bb:exit', 'b:exit', 'a:enter'],
      );
    });

    test('parallel children delivered events', () async {
      root.initialState = machine['b'];
      final bb = machine['bb'];
      final ba = machine['ba'];
      machine['b']!.initialState = machine['baa'];
      machine['bb']!.initialState = machine['bba'];
      machine.start();
      records.clear();
      var handler = 0;
      bb!.addHandler(
        't1',
        guard: (e, d) {
          records.add('bb:g:$e:$handler');
          return false;
        },
      );
      ba!.addHandler(
        't1',
        guard: (e, d) {
          records.add('ba:g:$e:$handler');
          return false;
        },
      );
      await machine.handle('t1');
      handler++;
      await machine.handle('t1');
      expect(
        records,
        unorderedEquals(
          ['bb:g:t1:0', 'ba:g:t1:0', 'bb:g:t1:1', 'ba:g:t1:1'],
        ),
      );
    });

    test('event guards', () {
      var aa = machine['aa'];
      var ab = machine['ab'];
      var aba = machine['aba'];

      root.addHandlers('t1', [
        EventHandler(
          target: aa,
          guard: (e, d) {
            record('root:t1:g1');
            return false;
          },
          action: (e, d) => record('root:t1:a1'),
        ),
        EventHandler(
          target: ab,
          guard: (e, d) {
            record('root:t1:g2');
            return true;
          },
          action: (e, d) => record('root:t1:a2'),
        ),
        EventHandler(
          target: aba,
          guard: (e, d) {
            record('root:t1:g3');
            return false;
          },
          action: (e, d) => record('root:t1:a3'),
        )
      ]);
      machine.start();
      records.clear();
      machine.handle('t1', null);
      expect(
        records,
        ['root:t1:g1', 'root:t1:g2', 'root:t1:a2', 'a:enter', 'ab:enter'],
      );
    });

    test('local transition to ancestor', () async {
      final aaa = machine['aaa'];
      final aa = machine['aa'];
      root.initialState = aaa;
      aaa!.addHandler(
        't1',
        target: aa,
        action: (e, d) => record('aaa:$e'),
        local: true,
      );
      machine.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, [
        'aaa:exit',
        'aaa:t1' // Actions take place after exiting, before entering.
      ]);
    });

    test('local transition to descendant', () async {
      final aaa = machine['aaa'];
      final a = machine['a'];
      root.initialState = a;
      a!.addHandler(
        't1',
        target: aaa,
        action: (e, d) => record('a:$e'),
        local: true,
      );
      machine.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['a:t1', 'aa:enter', 'aaa:enter']);
    });

    test('external transition to ancestor', () async {
      final aaa = machine['aaa'];
      var aa = machine['aa'];
      root.initialState = aaa;
      aaa!.addHandler(
        't1',
        target: aa,
        action: (e, d) => record('aaa:$e'),
        local: false,
      );
      machine.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, [
        'aaa:exit',
        'aa:exit',
        'aaa:t1', // Actions take place after exiting, before entering.
        'aa:enter',
      ]);
    });

    test('external transition to descendant', () async {
      final aaa = machine['aaa'];
      final a = machine['a'];
      root.initialState = a;
      a!.addHandler(
        't1',
        target: aaa,
        action: (e, d) => record('a:$e'),
        local: false,
      );
      machine.start();
      records.clear();
      expect(await machine.handle('t1', null), isTrue);
      expect(records, ['a:exit', 'a:t1', 'a:enter', 'aa:enter', 'aaa:enter']);
    });
  });

  group('Practical Machines', () {
    test('keyboard', () async {
      // Done to match wikipedia example.
      // https://en.wikipedia.org/wiki/UML_state_machine#Orthogonal_regions
      final log = Logger('[Keyboard] ');
      var root = ParallelState('keyboard', log: log);
      var hsm = Machine.rooted(root, name: 'keyboard', log: log);
      var output = [];

      var main = State('main_keypad', parent: root);
      var numeric = State('numeric_keypad', parent: root);
      var mdef = State('main_default', parent: main);
      var ndef = State('numbers', parent: numeric);

      main.initialState = mdef;
      numeric.initialState = ndef;

      var caps = State('caps_locked', parent: main);
      var arrows = State('arrows', parent: numeric);

      mdef.addHandler('CAPS_LOCK', target: caps);
      caps.addHandler('CAPS_LOCK', target: mdef);

      ndef.addHandler('NUM_LOCK', target: arrows);
      arrows.addHandler('NUM_LOCK', target: ndef);

      mdef.addHandler(
        'ANY_KEY',
        action: (e, d) {
          output.add(d);
        },
      );
      caps.addHandler(
        'ANY_KEY',
        action: (e, String? d) {
          output.add(d!.toUpperCase());
        },
      );

      ndef.addHandler(
        'NUM_KEY',
        action: (e, d) {
          output.add(d);
        },
      );
      arrows.addHandler(
        'NUM_KEY',
        action: (e, d) {
          switch (d) {
            case '8':
              output.add('↑');
              break;
            case '6':
              output.add('→');
              break;
            case '2':
              output.add('↓');
              break;
            case '4':
              output.add('←');
              break;
            case '3':
              output.add('↘');
              break;
            case '1':
              output.add('↙');
              break;
            case '7':
              output.add('↖');
              break;
            case '9':
              output.add('↗');
              break;
            default:
              output.add(d);
          }
        },
      );

      hsm.start();

      for (var char in 'abcABC'.split('')) {
        await hsm.handle('ANY_KEY', char);
      }
      for (var char in '123'.split('')) {
        await hsm.handle('NUM_KEY', char);
      }
      await hsm.handle('CAPS_LOCK');
      for (var char in 'abcABC'.split('')) {
        await hsm.handle('ANY_KEY', char);
      }
      for (var char in '123'.split('')) {
        await hsm.handle('NUM_KEY', char);
      }
      await hsm.handle('NUM_LOCK');
      for (var char in '123'.split('')) {
        await hsm.handle('NUM_KEY', char);
      }

      expect(output.join(), 'abcABC123ABCABC123↙↓↘');
      log.info(() => hsm.stateString);
    });

    group('Async / Deferred Machines', () {
      // Machines *are* Async as they depend on the input of events to run.
      late Machine<String, dynamic> hsm;
      late State<String, dynamic> root, a, b;
      Logger log;
      late List<List<dynamic>> deferred;
      late bool ready;
      late List<String> records;

      Future<void> unspool() async {
        await Future.delayed(const Duration(milliseconds: 100), () async {
          ready = true;
          var queued = deferred;
          deferred = [];
          for (var pair in queued) {
            await hsm.handle(pair[0], pair[1]);
          }
        });
      }

      setUp(() {
        ready = false;
        deferred = [];
        records = [];
        log = Logger('[defer] ');
        hsm = Machine(name: 'deferral', log: log, rootId: 'root');
        root = hsm.root;
        a = root.newChild('a');
        b = root.newChild('b');
      });

      // cleaner separation by putting "pre" and "post" in different states.
      test('guards to another state', () async {
        a.addHandler(
          't1',
          target: b,
          guard: (e, d) {
            records.add('a:g');
            if (!ready) deferred.add([e, d]);
            return ready;
          },
          action: (e, d) {
            records.add('a:b');
          },
        );
        root.initialState = a;
        hsm.start();
        unawaited(hsm.handle('t1', 1));
        unawaited(hsm.handle('t1', 2));
        expect(deferred, isNotEmpty);
        expect(records, ['a:g', 'a:g']);
        expect(b.isActive, isFalse);
        await unspool();

        /// Note, the second event, t1:2, falls through because it was passed
        /// to B after the transition.
        expect(records, ['a:g', 'a:g', 'a:g', 'a:b']);
      });

      test('guard with internal transition', () async {
        root.addHandlers('t1', [
          EventHandler(
            guard: (_, __) => !ready,
            action: (e, d) {
              records.add('$e:q');
              deferred.add([e, d]);
            },
          ),
          EventHandler(
            action: (e, d) {
              records.add('$e:$d');
            },
          )
        ]);
        root.addHandler(
          't2',
          guard: (_, __) => ready,
          action: (e, d) {
            records.add('$e:$d');
          },
        );
        hsm.start();
        unawaited(hsm.handle('t1', 1));
        unawaited(hsm.handle('t1', 2));
        var dropFuture = hsm.handle('t2', 3);
        expect(deferred.length, 2, reason: 't1 queued twice, t2 dropped');
        await unspool();
        expect(await dropFuture, isFalse, reason: 't2 should be dropped');
        expect(records, ['t1:q', 't1:q', 't1:1', 't1:2']);
      });

      test('defer multiple with one handler', () async {
        var unready = EventHandler<String, dynamic>(
          guard: (_, __) => !ready,
          action: (e, d) {
            records.add('$e:q');
            deferred.add([e, d]);
          },
        );
        root.addHandlers('t1', [
          unready,
          EventHandler(
            action: (e, d) {
              records.add('$e:$d');
            },
          )
        ]);
        root.addHandlers('t2', [
          unready,
          EventHandler(
            action: (e, d) {
              records.add('$e:$d');
            },
          )
        ]);
        hsm.start();
        unawaited(hsm.handle('t1', 1));
        unawaited(hsm.handle('t1', 2));
        unawaited(hsm.handle('t2', 3));
        expect(deferred.length, 3, reason: 'deferral of all events');
        await unspool();
        expect(records, ['t1:q', 't1:q', 't2:q', 't1:1', 't1:2', 't2:3']);
      });
    });
  });
}

enum TestEvents { one, two, three, four }

enum TestStates { a, aa, ab, b }
