import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

Future<int> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart list_api.dart <path_to_entry_file> [<path_to_output>]',
    );
    return -1;
  }

  final filePath = p.canonicalize(args[0]);
  final rootPath = p.dirname(p.dirname(filePath));

  final collection = AnalysisContextCollection(includedPaths: [rootPath]);
  final context = collection.contexts.first;

  final libraryResult = await context.currentSession.getResolvedLibrary(
    filePath,
  );

  final buffer = StringBuffer();

  if (libraryResult is ResolvedLibraryResult) {
    final library = libraryResult.element;
    buffer.writeln('# PUBLIC API FOR `$library`');

    final publicNames = library.exportNamespace.definedNames2;
    final sortedNames = publicNames.keys.toList()..sort();

    for (var name in sortedNames) {
      final element = publicNames[name]!;

      // Check kind instead of using 'isGetter' or 'is' types for reliability
      if (element.kind == ElementKind.CLASS) {
        final classElement = element as ClassElement;
        buffer.writeln('## Class: `$name`');

        // 1. Constructors & Factories (Sorted)
        final constructors =
            classElement.constructors
                .where((c) => !c.name!.startsWith('_'))
                .toList()
              ..sort((a, b) => a.name!.compareTo(b.name!));

        final collector = <String>[];
        for (var ctor in constructors) {
          final type = ctor.isFactory ? 'factory ' : '';
          // Clean up ".new" for unnamed constructors
          final ctorName = (ctor.name == 'new' || ctor.name!.isEmpty)
              ? name
              : '$name.${ctor.name}';

          collector.add(
            '  $type$ctorName(${_formatParams(ctor.formalParameters)});',
          );
        }
        if (collector.isNotEmpty) {
          buffer.writeln('### Constructors');
          buffer.writeln('```dart');
          buffer.writeln(collector.join('\n'));
          buffer.writeln('```');
          collector.clear();
        }

        // 2. Members / Fields (Sorted)
        final fields =
            classElement.fields.where((f) => !f.name!.startsWith('_')).toList()
              ..sort((a, b) => a.name!.compareTo(b.name!));

        for (var field in fields) {
          collector.add('  ${field.type.getDisplayString()} ${field.name};');
        }
        if (collector.isNotEmpty) {
          buffer.writeln('### Fields');
          buffer.writeln('```dart');
          buffer.writeln(collector.join('\n'));
          buffer.writeln('```');
          collector.clear();
        }

        // 3. Methods (Sorted)
        final methods =
            classElement.methods.where((m) => !m.name!.startsWith('_')).toList()
              ..sort((a, b) => a.name!.compareTo(b.name!));

        for (var method in methods) {
          collector.add(
            '  ${method.returnType.getDisplayString()} ${method.name}(${_formatParams(method.formalParameters)});',
          );
        }
        if (collector.isNotEmpty) {
          buffer.writeln('### Methods');
          buffer.writeln('```dart');
          buffer.writeln(collector.join('\n'));
          buffer.writeln('```');
          collector.clear();
        }
      } else if (element.kind == ElementKind.FUNCTION) {
        final func = element as TopLevelFunctionElement;
        buffer.writeln(
          '## Global Function: `${func.returnType.getDisplayString()} $name(${_formatParams(func.formalParameters)})`',
        );
      } else if (element.kind == ElementKind.GETTER) {
        final getter = element as PropertyAccessorElement;
        buffer.writeln(
          '## Global Variable: `${getter.returnType.getDisplayString()} $name`',
        );
      }
    }
  }

  if (args.length > 1) {
    // Write directly to file to bypass shell redirection behavior
    final file = File(args[1]);
    await file.writeAsString('$buffer', encoding: utf8, flush: true);
    print('API surface written to ${args[1]} with LF line endings.');
  } else {
    stdout.write('$buffer');
  }

  return 0;
}

String _formatParams(List<FormalParameterElement> parameters) {
  if (parameters.isEmpty) return '';

  final requiredPositional = parameters.where((p) => p.isRequiredPositional);
  final optionalPositional = parameters.where((p) => p.isOptionalPositional);
  final named = parameters.where((p) => p.isNamed);

  List<String> parts = [];

  // 1. Required Positional
  if (requiredPositional.isNotEmpty) {
    parts.add(
      requiredPositional
          .map((p) => '${p.type.getDisplayString()} ${p.name}')
          .join(', '),
    );
  }

  // 2. Optional Positional: Grouped in one set of []
  if (optionalPositional.isNotEmpty) {
    final inner = optionalPositional
        .map((p) => '${p.type.getDisplayString()} ${p.name}')
        .join(', ');
    parts.add('[$inner]');
  }

  // 3. Named: Grouped in one set of {}
  if (named.isNotEmpty) {
    final inner = named
        .map((p) {
          final requiredPrefix = p.isRequiredNamed ? 'required ' : '';
          return '$requiredPrefix${p.type.getDisplayString()} ${p.name}';
        })
        .join(', ');
    parts.add('{$inner}');
  }

  return parts.join(', ');
}
