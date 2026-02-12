# Technology Stack - Hierarchical State Machine

## Core Language and Runtime
- **Language:** Dart 3.10+
- **Runtime:** Dart VM (Console/Server) and Web (via dart2js/wasm).

## Frameworks and Libraries
- **Core Engine:** Pure Dart (No external state management dependencies).
- **Asynchronous Utilities:** `package:async` for managing complex event streams and future-based actions.

## Quality Assurance and Testing
- **Testing Framework:** `package:test` for unit and behavioral verification.
- **Mocking:** `package:mocktail` or `package:mockito` for creating fakes and mocks in transition tests.
- **Linting:** Standard Dart linter with `package:lints`.

## Development and Build Tools
- **Package Management:** Dart Pub.
- **Code Generation:** `package:build_runner` (as needed for future extensions).
- **Automation:** CI/CD Integration (e.g., GitHub Actions) for automated testing and analysis.

## Documentation and Examples
- **API Documentation:** DartDoc for automated HTML documentation.
- **Examples:** Dedicated `example/` directory for code samples.
- **Conceptual Guides:** Markdown-based documentation in the `docs/` folder.
