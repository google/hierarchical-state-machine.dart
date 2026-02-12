import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

/// A specialized [PrintObserver] for tests that indents every line by two spaces.
class TestPrintObserver<S, E> extends PrintObserver<S, E> {
  const TestPrintObserver() : super(formatter: _indent);

  static String _indent(String msg) => '  $msg';
}
