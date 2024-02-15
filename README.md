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

## What about...

### Fork / Join pseudo states

Concurent states already exist as `ParallelState`. Its not perfect semantic,
but you can implement this in your own machine.

### History and Deep History

The initial state is mutable and evaluated after `onEnter` of the target state.
Not perfectly semantic, but very workable in your own machine.

### Conditionals

Event handlers have guards and these can be used to make the choice of which
target is transitioned to on a given event.

### Event Deferral

Simple deferrals can be done locally by capturing events and replaying them
on exit. While not perfect, it does let the future state define its own
deferal list to re-capture the events.

