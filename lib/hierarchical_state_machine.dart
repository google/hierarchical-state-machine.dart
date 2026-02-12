// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A hierarchical state machine (HSM) implementation for dart.
library;

// Public API
export 'src/machine.dart'
    show
        // Runtime state
        Machine,
        HsmState,
        MachineObserver,
        PrintObserver,
        // Runtime functions and data
        StateFunction,
        GuardFunction,
        ActionFunction,
        HistoryType,
        TransitionKind,
        // Blueprint States
        MachineBlueprint,
        BasicBlueprint,
        CompositeBlueprint,
        ParallelBlueprint,
        ChoiceBlueprint,
        ForkBlueprint,
        FinalBlueprint,
        // Blueprint Handlers
        TransitionBlueprint,
        DefaultTransitionBlueprint,
        CompletionBlueprint,
        ForkTransitionBlueprint,
        TerminateBlueprint,
        // Blueprint validation errors
        ValidationError,
        DuplicateStateIdError,
        MissingStateError,
        InvalidInitialStateError,
        ForkValidationError,
        InvalidRootError,
        UnknownDefinitionTypeError;
