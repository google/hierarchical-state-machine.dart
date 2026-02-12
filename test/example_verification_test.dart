import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Example Verification', () {
    test('complex_blueprint.dart compiles and runs', () async {
      final result = await Process.run('dart', [
        'run',
        'example/complex_blueprint.dart',
      ]);

      if (result.exitCode != 0) {
        print('STDOUT: ${result.stdout}');
        print('STDERR: ${result.stderr}');
      }

      expect(result.exitCode, 0, reason: 'Example should run successfully');
      expect(
        LineSplitter.split(result.stdout),
        containsAllInOrder([
          'Machine compiled successfully: GameMachine',
          'Active states: State(root)/State(loading)',
          'Handling gameLoaded with isLoggedIn: true...',
          'Active states: State(root)/ParallelState(gameplay)/(State(movement)/State(idle),State(combat)/State(peaceful))',
          'Handling move...',
          'Active states: State(root)/ParallelState(gameplay)/(State(movement)/State(walking),State(combat)/State(peaceful))',
          'Handling attack...',
          'Active states: State(root)/ParallelState(gameplay)/(State(movement)/State(walking),State(combat)/State(fighting))',
          'Handling stop...',
          'Active states: State(root)/ParallelState(gameplay)/(State(movement)/State(idle),State(combat)/State(fighting))',
          'Handling flee...',
          'Active states: State(root)/ParallelState(gameplay)/(State(movement)/State(idle),State(combat)/State(peaceful))',
          'Alt-F4',
          'Active states: State(root)',
        ]),
      );
    });

    test('keyboard.dart compiles and runs', () async {
      final result = await Process.run('dart', [
        'run',
        'example/keyboard.dart',
      ], stdoutEncoding: utf8);

      if (result.exitCode != 0) {
        print('STDOUT: ${result.stdout}');
        print('STDERR: ${result.stderr}');
      }

      expect(result.exitCode, 0, reason: 'Example should run successfully');

      expect(
        LineSplitter.split(result.stdout),
        containsAllInOrder([
          'Simulating typing...',
          'Toggling CAPS_LOCK...',
          'Toggling NUM_LOCK...',
          'Final Output: abcABC123ABCABC↙↓↘',
        ]),
      );
    });
  });
}
