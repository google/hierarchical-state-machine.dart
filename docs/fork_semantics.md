# Forks

Forks are a pseudostate in the UML 2.5.1 / PSSM specifications. Forks are tricky. According to the spec:

> fork Pseudostates serve to split an incoming Transition into two or
> more Transitions terminating on Vertices in orthogonal Regions of a
> composite State. The Transitions outgoing from a fork Pseudostate
> cannot have a guard or a trigger.

And also:
> Only Transitions that occur in mutually orthogonal Regions may be fired
> simultaneously. This constraint guarantees that the new active state
> configuration resulting from executing the set of Transitions is well formed

background: in this library, all states inherit from BaseState. Parallel states
are just States in which all children are active (orthogonal regions). There
are no Regions in this library; the children of Parallel states are states and
regions.

## Validation

To be valid a fork must:

1. Fork states must have more than one target states.
2. The LCA of all the targets must be a parallel state (e.g. [A, B, C].lca())
   is ParallelState)
3. The number of state targets in the Fork must be less than or equal to the
   number of direct children states in the Parallel State.
4. Each child state can only be activated one time. That is, for each state path
   in the fork targets, the state after the LCA state is the child of a Parallel
   state, therefore there can be no duplicates of that child state in all the
   targets.

If any of these checks fail before machine.start(); an exception must be thrown
describing the collected failures of invalid vectors from the fork state. This
should be as helpful as possible to the developer.

## Targets and transitions

Fork transitions are like normal full transitions with specific constraints:

1. **No Guards:** They cannot have guards (UML 14.2.3.7).
2. **Concurrency:** All outgoing transitions fire "concurrently" in a single Run-To-Completion step. The order of execution is undefined.
3. **Actions:** Each outgoing transition can have an associated action (effect behavior) which will be executed before entry phase.
4. **Entry Logic:**
    * The transition leaves the Fork Pseudostate (no exit behavior is executed on the Fork itself).
    * The target state is entered **explicitly**.
    * If the target is a Parallel State or Composite State, it continues entering its children via **Default Entry** (Initial State) or **History**, unless those children are also targets of a chained Fork.

## Advanced Forks

If a developer wishes to target nested parallel states, they must have a fork as
a target of another fork.

```dart
ForkB([B1, B2])
ForkA([ForkB, C1])
```
