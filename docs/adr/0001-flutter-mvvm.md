# ADR 0001: Flutter MVVM architecture

Status: accepted

## Context

The prototype needs one Android-first codebase, native camera and location access, offline persistence, and replaceable AI/cloud integrations.

## Decision

- Use Flutter 3.47.2 with Riverpod for state and dependency injection and go_router for routing.
- Follow Flutter's official MVVM dependency direction: View to ViewModel to Repository to Service.
- Treat repositories as the only data gateway and source of truth.
- Keep platform plugins behind stateless services and inject all implementations through providers.
- Organize UI by user-facing feature. Do not introduce a use-case layer until repeated complex cross-repository logic justifies it.
- Use SQLite locally and preserve identifiers and synchronization state for a later remote repository implementation.
- Do not use Stacked, Flutter Modular, GetIt, or an Android IDE-managed SDK.

## Consequences

Views remain simple, platform dependencies are replaceable in tests, and future cloud/AI work changes repository or service implementations rather than UI code. The tradeoff is more explicit interfaces and provider wiring in the prototype.

