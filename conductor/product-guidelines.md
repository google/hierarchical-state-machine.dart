# Product Guidelines - Hierarchical State Machine

## Documentation and Prose Style
- **Technical and Precise:** Definitions of state machine behavior and UML semantics must be unambiguous and consistent.
- **Tutorial-Driven:** Supplement technical specs with practical examples and "how-to" guides to aid adoption.
- **API-First Documentation:** Every public class, method, and property must have comprehensive DartDoc comments.

## Quality and Testing
- **High Coverage:** Maintain a code coverage of >80% to ensure logic paths are thoroughly tested.
- **Behavioral Verification:** Tests must specifically verify that state transition sequences adhere to UML expectations.

## API Management
- **Semantic Versioning:** Follow SemVer strictly to manage compatibility and versioning.
- **Deprecation Cycle:** Use the `@deprecated` annotation for at least one minor version cycle before removing old APIs.
- **Migration Guides:** Document breaking changes with clear migration steps and code examples.

## Architectural Integrity
- **Modular Design:** Ensure the core state machine engine remains decoupled from peripheral features like logging or visualization.
- **Immutability:** Favor immutable data structures for state configuration to prevent accidental side effects and enhance predictability.

## Dependency Management
- **Minimalism:** Strive for zero or minimal external dependencies to keep the library lightweight and maintainable.
- **Stable Packages:** If a dependency is necessary, only utilize well-established and stable packages from the Dart ecosystem.
