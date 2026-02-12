# PUBLIC API FOR `library package:hierarchical_state_machine/hierarchical_state_machine.dart`
## Class: `BasicBlueprint`
### Constructors
```dart
  factory BasicBlueprint.choice({required S id, required DefaultTransitionBlueprint<S, E> defaultTransition, List<TransitionBlueprint<S, E>> options});
  factory BasicBlueprint.composite({required S id, Map<E, TransitionBlueprint<S, E>>? on, Set<E> defer, List<CompletionBlueprint<S, E>>? completion, void Function()? entry, void Function()? exit, List<BasicBlueprint<S, E>> children, S? initial, void Function()? initialAction});
  factory BasicBlueprint.finish({required S id});
  factory BasicBlueprint.fork({required S id, required List<ForkTransitionBlueprint<S, E>> transitions});
  BasicBlueprint({required S id});
  factory BasicBlueprint.parallel({required S id, Map<E, TransitionBlueprint<S, E>>? on, List<CompletionBlueprint<S, E>>? completion, void Function()? entry, void Function()? exit, List<BasicBlueprint<S, E>> children});
  factory BasicBlueprint.terminate({required S id});
```
### Fields
```dart
  S id;
```
## Class: `ChoiceBlueprint`
### Constructors
```dart
  ChoiceBlueprint({required S id, required DefaultTransitionBlueprint<S, E> defaultTransition, List<TransitionBlueprint<S, E>> options});
```
### Fields
```dart
  DefaultTransitionBlueprint<S, E> defaultTransition;
  List<TransitionBlueprint<S, E>> options;
```
## Class: `CompletionBlueprint`
### Constructors
```dart
  CompletionBlueprint({S? target, bool Function()? guard, void Function()? action, TransitionKind kind, HistoryType history});
```
### Fields
```dart
  void Function()? action;
  bool Function()? guard;
  HistoryType history;
  TransitionKind kind;
  S? target;
```
## Class: `CompositeBlueprint`
### Constructors
```dart
  CompositeBlueprint({required S id, Map<E, TransitionBlueprint<S, E>>? on, Set<E> defer, List<CompletionBlueprint<S, E>>? completion, void Function()? entry, void Function()? exit, List<BasicBlueprint<S, E>> children, S? initial, void Function()? initialAction});
```
### Fields
```dart
  List<BasicBlueprint<S, E>> children;
  List<CompletionBlueprint<S, E>>? completion;
  Set<E> defer;
  void Function()? entry;
  void Function()? exit;
  S? initial;
  void Function()? initialAction;
  Map<E, TransitionBlueprint<S, E>>? on;
```
## Class: `DefaultTransitionBlueprint`
### Constructors
```dart
  DefaultTransitionBlueprint({required S target, void Function(E?, Object?)? action, TransitionKind kind, HistoryType history});
```
### Fields
```dart
  void Function(E?, Object?)? action;
  HistoryType history;
  TransitionKind kind;
  S target;
```
## Class: `DuplicateStateIdError`
### Constructors
```dart
  DuplicateStateIdError(S id);
```
### Fields
```dart
  S id;
```
## Class: `FinalBlueprint`
### Constructors
```dart
  FinalBlueprint({required S id});
```
## Class: `ForkBlueprint`
### Constructors
```dart
  ForkBlueprint({required S id, required List<ForkTransitionBlueprint<S, E>> transitions});
```
### Fields
```dart
  List<ForkTransitionBlueprint<S, E>> transitions;
```
## Class: `ForkTransitionBlueprint`
### Constructors
```dart
  ForkTransitionBlueprint({required S target, void Function(E?, Object?)? action, HistoryType history});
```
### Fields
```dart
  void Function(E?, Object?)? action;
  HistoryType history;
  S target;
```
## Class: `ForkValidationError`
### Constructors
```dart
  ForkValidationError(S forkId, String details);
```
### Fields
```dart
  String details;
  S forkId;
```
## Class: `HsmState`
### Fields
```dart
  S id;
  bool isActive;
  HsmState<S, E>? parent;
  List<HsmState<S, E>> path;
```
## Class: `InvalidInitialStateError`
### Constructors
```dart
  InvalidInitialStateError(S initialStateId, S parentId);
```
### Fields
```dart
  S initialStateId;
  S parentId;
```
## Class: `InvalidRootError`
### Constructors
```dart
  InvalidRootError();
```
## Class: `Machine`
### Fields
```dart
  bool isHandlingEvent;
  bool isRunning;
  String name;
  MachineObserver<S, E> observer;
  Stream<Machine<S, E>> onSettled;
  void Function()? onTerminated;
  HsmState<S, E> root;
  Future<void> settled;
  String stateString;
```
### Methods
```dart
  HsmState<S, E>? getState(S id);
  Future<bool> handle(E event, [dynamic data]);
  bool start();
  bool stop();
  String toString();
```
## Class: `MachineBlueprint`
### Constructors
```dart
  MachineBlueprint({String? name, required BasicBlueprint<S, E> root});
```
### Fields
```dart
  String? name;
  BasicBlueprint<S, E> root;
```
### Methods
```dart
  (Machine<S, E>?, List<ValidationError>) compile({void Function()? onTerminated, MachineObserver<S, E>? observer});
```
## Class: `MachineObserver`
### Constructors
```dart
  MachineObserver();
```
### Methods
```dart
  void onEventDeferred(HsmState<S, E> state, E event, dynamic data);
  void onEventDropped(HsmState<S, E> state, E event, dynamic data);
  void onEventError(Machine<S, E> machine, E event, dynamic data, Object error, StackTrace stackTrace);
  void onEventHandled(HsmState<S, E> state, E event, dynamic data);
  void onEventHandling(Machine<S, E> machine, E event, dynamic data);
  void onEventQueued(Machine<S, E> machine, E event, dynamic data);
  void onEventUnhandled(HsmState<S, E> state, E event, dynamic data);
  void onInternalTransition(HsmState<S, E> state, E? event, dynamic data);
  void onMachineStarted(Machine<S, E> machine);
  void onMachineStarting(Machine<S, E> machine);
  void onMachineStopped(Machine<S, E> machine);
  void onMachineTerminated(Machine<S, E> machine);
  void onStateEnter(HsmState<S, E> state);
  void onStateExit(HsmState<S, E> state);
  void onTransition(HsmState<S, E> source, HsmState<S, E> target, E? event, dynamic data, TransitionKind kind);
```
## Class: `MissingStateError`
### Constructors
```dart
  MissingStateError(S id, S sourceId, String context);
```
### Fields
```dart
  String context;
  S id;
  S sourceId;
```
## Class: `ParallelBlueprint`
### Constructors
```dart
  ParallelBlueprint({required S id, List<BasicBlueprint<S, E>> children, void Function()? entry, void Function()? exit, Map<E, TransitionBlueprint<S, E>>? on, List<CompletionBlueprint<S, E>>? completion});
```
## Class: `PrintObserver`
### Constructors
```dart
  PrintObserver({String Function(String) formatter});
```
### Fields
```dart
  String Function(String) formatter;
```
### Methods
```dart
  void onEventDeferred(HsmState<S, E> state, E event, dynamic data);
  void onEventDropped(HsmState<S, E> state, E event, dynamic data);
  void onEventError(Machine<S, E> machine, E event, dynamic data, Object error, StackTrace stackTrace);
  void onEventHandled(HsmState<S, E> state, E event, dynamic data);
  void onEventHandling(Machine<S, E> machine, E event, dynamic data);
  void onEventQueued(Machine<S, E> machine, E event, dynamic data);
  void onEventUnhandled(HsmState<S, E> state, E event, dynamic data);
  void onInternalTransition(HsmState<S, E> state, E? event, dynamic data);
  void onMachineStarted(Machine<S, E> machine);
  void onMachineStarting(Machine<S, E> machine);
  void onMachineStopped(Machine<S, E> machine);
  void onMachineTerminated(Machine<S, E> machine);
  void onStateEnter(HsmState<S, E> state);
  void onStateExit(HsmState<S, E> state);
  void onTransition(HsmState<S, E> source, HsmState<S, E> target, E? event, dynamic data, TransitionKind kind);
```
## Class: `TerminateBlueprint`
### Constructors
```dart
  TerminateBlueprint({required S id});
```
## Class: `TransitionBlueprint`
### Constructors
```dart
  TransitionBlueprint({S? target, bool Function(E?, Object?)? guard, void Function(E?, Object?)? action, TransitionKind kind, HistoryType history});
```
### Fields
```dart
  void Function(E?, Object?)? action;
  bool Function(E?, Object?)? guard;
  HistoryType history;
  TransitionKind kind;
  S? target;
```
## Class: `UnknownDefinitionTypeError`
### Constructors
```dart
  UnknownDefinitionTypeError(Type type, S id);
```
### Fields
```dart
  S id;
  Type type;
```
## Class: `ValidationError`
### Constructors
```dart
  ValidationError(String message);
```
### Fields
```dart
  String message;
```
### Methods
```dart
  String toString();
```
