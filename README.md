# Hierarchical State Machine (HSM)

[![Pub Version](https://img.shields.io/pub/v/hierarchical_state_machine)](https://pub.dev/packages/hierarchical_state_machine)

Industrial-grade Statecharts for Dart. A type-safe, hierarchical state machine implementation following Precise Semantics (PSSM) principles.

## Why HSM?

Flat state machines lead to "state explosion." HSMs solve this through _hierarchy_:

- **Inheritance**: A `LoggedOut` state can handle a `Login` event, while its children (`Prompting`, `Authenticating`) focus only on their specific logic.
- **Composition**: Group related states into logical units.
- **Concurrency**: Multiple states can act serially or in parallel depending on the regions.

## Core Concepts

### 1. The Blueprint (Static Definition)

Define your logic once using a declarative, tree-like structure. Blueprints are immutable and validated during compilation.

### 2. The Machine (Runtime Instance)

Compile a Blueprint into a Machine instance. This separates your "business rules" from the "current state," allowing you to run multiple instances of the same logic simultaneously. You can share blueprints between machines (e.g. `Authentication`) if you share events.

## Quick Start

```dart
enum States { root, locked, unlocked, blinking }
enum Events { coin, push, timer }

final blueprint = MachineBlueprint<States, Events>(
  name: 'Turnstile',
  root: .composite(
    id: .root,
    initial: .locked,
    children: [
      .composite(
        id: .locked,
        on: { .coin: .new(guard: (e, d) => d == 0.25, target: .unlocked) },
      ),
      .composite(
        id: .unlocked,
        on: { .push: .new(target: .locked) },
      ),
    ],
  ),
);

final (hsm, errors) = blueprint.compile();
hsm!.start();

await hsm.handle(Events.coin, 0.25);
print(hsm.stateString); // Turnstile/States.unlocked
```

## Advanced Features

### Orthogonal Regions (Parallel)

Run multiple states at once. The parallel state is only "complete" when all regions reach their final states, or when one state explicity exits.

### History Semantics

Automatically remember where you were.

- **Shallow History**: Restores the immediate child.
- **Deep History**: Restores the entire active leaf configuration from any depth.

### Pseudo-states

- **Choice**: Dynamic branching based on runtime guards: a many-to-many target.
- **Fork**: Enter a parallel state at specific, non-default coordinates in different regions.
- **Terminate**: Halt processing of the machine from anywhere.
- **Final**: Work for the parent is complete; executes completers.

### Event Deferral

Capture events that cannot be handled in the current state and automatically replay them once the machine transitions to a state that can.

## Documentation

For a deep dive into transition segments, guard evaluations, and action execution order, see the [API Documentation](https://pub.dev/documentation/hierarchical_state_machine/latest/).

## Order of Execution

When an event is "handled" by a state; the order of operations is defined by PSSM. The following is a brief overview.

```dart
/// Order of operations for the following state, assuming event T1 is fired and
/// s11 is the current state.
///     1) T1 delivered to s1
///     2) Guard g() is called. If it returns false, stop.
///     3) a(), b(), t(), c(), d(), e()
/// ┌──────────────────────────|s|──────────────────────────┐
/// │┌────|s1|────┐                    ┌────|s2|───────────┐│
/// ││exit:b()    │                    │entry:c()          ││
/// ││┌──|s11|──┐ │                    │-*:d()->┌──|s21|──┐││
/// │││exit:a() │ │--T1{guard:g(),     │        │entry:e()│││
/// │││         │ │      action:t()}-->│        │         │││
/// ││└─────────┘ │                    │        └─────────┘││
/// │└────────────┘                    └───────────────────┘│
/// └───────────────────────────────────────────────────────┘
```

## Future Work

- **Serialization**: we plan to save the state of the machine and restore it at a later time.
