# Hierarchical State Machine

This hierarchial state machine (HSM) resembles a UML statechart, written in
dart. States are oranized in parent/child relationships, allowing common event
handling to be performed by more generic, containing states. This machine also
supports parallel or "Orthogonal regions".

The most important information can be found in the `EventHandler` class:

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

