# Initial Concept
A framework for building state machines similar to UML state charts. States are organized in parent/child relationships, allowing common event handling to be performed by more generic, containing states.

# Product Definition - Hierarchical State Machine

## Target Audience
- **Dart/Flutter Developers:** Building complex application logic, UI flows, and business processes.
- **Game Developers:** Needing robust state management for characters, NPCs, or game systems.
- **System Engineers:** Building embedded or server-side state-driven applications requiring high reliability.

## Key Features
- **Hierarchical State Organization:** Nested states allow common event handling to be performed by more generic, containing states, reducing redundancy.
- **Orthogonal Regions:** Support for parallel states enables managing concurrent, independent behaviors within a single machine.
- **Transitions with Guards and Actions:** Robust event handling including guard conditions to control transitions and side-effect actions.
- **Final States & Completion:** Native support for `FinalState` allows for automatic completion transitions in both composite and parallel states when regions finish their work.
- **Advanced Pseudo-States:** First-class support for `TerminateState` to halt execution and `ForkState` for explicit parallel entry.

## Design Principles
- **UML Fidelity:** Strive to mimic UML statechart semantics closely, including entry/exit actions and transition orders.
- **Type Safety:** Leverage Dart's strong type system to ensure state configurations and event processing are sound.
- **Performance:** Optimize for high-frequency event processing to satisfy the needs of real-time systems like games.

## Vision and Evolution
- **Extended Semantics:** Implement first-class support for History, Deep History, and Join pseudo-states.
- **Visual Tooling:** Develop compatibility with visual statechart diagrams or generate diagrams from code.
- **Asynchronous Excellence:** Provide first-class support for Dart's `Future` and `Stream` within handlers, while also facilitating event-based async result injection.
