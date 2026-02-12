# Technical PRD: HSM Library Refactor (Opaque-Instance Architecture)

## 1. Objective

Refactor the HSM library to decouple structural definition from runtime execution. The hierarchy must be immutable post-compilation, with runtime data (`_active`, `_history`, `deferredQueue`) stored on private internal classes that are inaccessible to the developer.

## 2. Current State Analysis

* **Public Mutability**: `BaseState` and `State` expose fields like `parent` and `handlers` that are currently mutable by the developer.
* **Side-Effect Registration**: Child states currently register themselves to parents via constructor side-effects.
* **Runtime Overhead**: Structural properties like `path` and `lowestCommonAncestor` (LCA) are recalculated during transitions rather than pre-computed.

## 3. Targeted Architecture

### 3.1. The Blueprint Phase (`Definition` Classes)

Developers define the machine using immutable data structures.

* **Composability**: Definitions are pure data and can be nested into multiple machines without side effects.
* **Declarative Hierarchy**: Parents define their children explicitly, removing the need for `newChild()` side-effects.

### 3.2. The Compilation Phase (`compile()`)

Transforms the `MachineDefinition` into a private tree of `BaseState` nodes.

* **Validation Phase**: Each state executes a `validate()` method. All errors are collected into a list of strings and returned to the user for handling.
* **Optimization Phase**: Pre-calculates and caches `path` lists and `LCA` for every defined transition to minimize runtime CPU cycles.

### 3.3. The Opaque Runtime Layer

* **Private Implementation**: `BaseState` and `State` move to private or package-protected status to hide internal mutability.
* **High Performance**: Runtime fields (`_active`, `_history`, `deferredQueue`) remain on these internal objects for  access, but are hidden from the public API.

---

## 4. Complex Blueprint Example

```dart
/// Events used to drive the state transitions in the Game Blueprint.
enum GameEvent {
  /// Triggered when the initial loading sequence is complete.
  gameLoaded,

  /// Closes the settings menu and returns to the main menu.
  closeSettings,

  /// Movement region: Transitions from idling to walking.
  move,

  /// Movement region: Transitions from walking to idling.
  stop,

  /// Combat region: Initiates a fight from a peaceful state.
  attack,

  /// Combat region: Abandons a fight to return to a peaceful state.
  flee,

  /// Quits the game
  exitGame,
}

final gameBlueprint = MachineDefinition<String, GameEvent>(
  initial: 'loading',
  states: [
    StateDefinition(
      id: 'loading',
      on: {
        GameEvent.gameLoaded: Transition(target: 'checkAuth'), 
      },
    ),

    ChoiceStateDefinition(
      id: 'checkAuth',
      defaultTarget: 'loginScreen',
      options: [
        ChoiceOption(
          target: 'gameplay',
          guard: (e, d) => d['isLoggedIn'] == true,
        ),
      ],
    ),

    ParallelStateDefinition(
      id: 'gameplay',
      regions: [
        StateDefinition(
          id: 'movement',
          initial: 'idle',
          children: [
            StateDefinition(id: 'idle', on: {GameEvent.move: Transition(target: 'walking')}),
            StateDefinition(id: 'walking', on: {GameEvent.stop: Transition(target: 'idle')}),
          ],
        ),
        StateDefinition(
          id: 'combat',
          initial: 'peaceful',
          children: [
            StateDefinition(id: 'peaceful', on: {GameEvent.attack: Transition(target: 'fighting')}),
            StateDefinition(id: 'fighting', on: {GameEvent.flee: Transition(target: 'peaceful')}),
          ],
        ),
      ],
    ),

    StateDefinition(
      id: 'settingsMenu',
      initial: 'audio',
      on: {
        // Transition triggers shallow history restoration upon re-entry
        GameEvent.closeSettings: Transition(
          target: 'mainMenu', 
          kind: TransitionKind.external,
          history: HistoryType.shallow, 
        ),
      },
      children: [
        StateDefinition(id: 'audio'),
        StateDefinition(id: 'video'),
        
        // Fork Pseudostate targeting multiple regions
        ForkStateDefinition(
          id: 'resumeGame',
          targets: [
            ForkTarget(target: 'movement', history: HistoryType.deep),
            ForkTarget(target: 'combat', history: HistoryType.deep),
          ],
        ),
      ],
    ),

    StateDefinition(id: 'loginScreen'),
    StateDefinition(id: 'mainMenu'),
    TerminateStateDefinition(id: 'exitApp'),
  ],
);

final (machine, errors) = gameBlueprint.compile();
if (errors.isNotEmpty) {
  for (var error in errors) print('Validation Error: $error');
} else {
  machine?.start();
}
```

---

## 5. The `compile()` Algorithm

The `compile()` method must execute the following sequence:

### Step 1: Internal Tree Construction

1. Recursively traverse the `MachineDefinition` hierarchy.
2. Instantiate the corresponding `BaseState` for each definition.
3. Pre-calculate the `path` for each state by traversing up to the root.
4. Store these in a flat `Map<S, BaseState>` for  lookup during compilation.

### Step 2: Transition Memoization

For every state that defines a transition (Standard, Choice, or Fork):

1. Resolve the `target` ID to its corresponding `BaseState` node.
2. **Calculate & Store LCA**: Invoke the existing LCA algorithm.
3. **Store the resulting LCA node directly on the Transition object** to eliminate runtime tree traversal.

### Step 3: Global Validation

1. Invoke `BaseState.validate()` on every node in the tree.
2. `validate()` must return a `String?` (null if valid, string if invalid).
3. Collect all non-null strings into a `List<String>`.
4. Check for cross-state errors:
   * **Invalid Initials**: `initialState` IDs that do not exist as ancestor of a state.
   * **Dead Ends**: ChoiceStates with missing or unreachable default targets.
5. Return the tuple `(Machine?, List<String>)`.

Would you like me to start drafting the **Conductor instructions** for the first phase of this refactor?