import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final current = Directory.current;

  var process = await Process.start('dart', [
    'run',
    'coverage:test_with_coverage',
  ]);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  if (await process.exitCode != 0) {
    print('code? ${await process.exitCode}');
    exit(1);
  }

  process = await Process.start('dart', [
    'run',
    'coverage:format_coverage',
    '--lcov',
    '--in=coverage',
    '--check-ignore',
    '--out=coverage/lcov.info',
    '--report-on=lib',
  ]);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  if (await process.exitCode != 0) {
    exit(1);
  }

  final coverageFiles = <String>[
    for (var file in current.listSync(recursive: true))
      if (file is File &&
          p.basename(file.path) == 'lcov.info' &&
          p.basename(file.parent.path) == 'coverage')
        p.relative(file.path),
  ];

  var result = Process.runSync(
    'dart',
    ['run', 'lcov_format', '-f', 'html', '-o', 'coverage', ...coverageFiles],
    runInShell: true, // This is required on Windows to find global CLI tools
  );

  result = Process.runSync(
    'dart',
    ['run', 'lcov_format', '-f', 'stats', '-o', 'coverage', ...coverageFiles],
    runInShell: true, // This is required on Windows to find global CLI tools
  );
  stdout.writeln(result.stdout);
}
