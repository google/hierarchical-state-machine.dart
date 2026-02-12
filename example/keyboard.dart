import 'package:hierarchical_state_machine/hierarchical_state_machine.dart';

void main() async {
  final output = [];

  final machineDef = MachineBlueprint<String, String>(
    name: 'keyboard',
    root: .parallel(
      id: 'keyboard',
      children: [
        .composite(
          id: 'main_keypad',
          initial: 'main_default',
          children: [
            .composite(
              id: 'main_default',
              on: {
                'CAPS_LOCK': .new(target: 'caps_locked'),
                'ANY_KEY': .new(action: (e, d) => output.add(d)),
              },
            ),
            .composite(
              id: 'caps_locked',
              on: {
                'CAPS_LOCK': .new(target: 'main_default'),
                'ANY_KEY': .new(
                  action: (e, d) => output.add((d as String).toUpperCase()),
                ),
              },
            ),
          ],
        ),
        .composite(
          id: 'numeric_keypad',
          initial: 'numbers',
          children: [
            .composite(
              id: 'numbers',
              on: {
                'NUM_LOCK': .new(target: 'arrows'),
                'NUM_KEY': .new(action: (e, d) => output.add(d)),
              },
            ),
            .composite(
              id: 'arrows',
              on: {
                'NUM_LOCK': .new(target: 'numbers'),
                'NUM_KEY': .new(
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
                ),
              },
            ),
          ],
        ),
      ],
    ),
  );

  final (machine, errors) = machineDef.compile();
  if (errors.isNotEmpty) {
    print('Validation Errors: $errors');
    return;
  }

  machine!.start();

  print('Simulating typing...');
  for (var char in 'abcABC'.split('')) {
    await machine.handle('ANY_KEY', char);
  }
  for (var char in '123'.split('')) {
    await machine.handle('NUM_KEY', char);
  }

  print('Toggling CAPS_LOCK...');
  await machine.handle('CAPS_LOCK');
  for (var char in 'abcABC'.split('')) {
    await machine.handle('ANY_KEY', char);
  }

  print('Toggling NUM_LOCK...');
  await machine.handle('NUM_LOCK');
  for (var char in '123'.split('')) {
    await machine.handle('NUM_KEY', char);
  }

  print('Final Output: ${output.join()}');
}
