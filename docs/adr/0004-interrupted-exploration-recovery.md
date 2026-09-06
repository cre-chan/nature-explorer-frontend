# ADR 0004: Recover interrupted explorations as paused

Status: accepted

## Context

An Android process can be terminated without giving Dart enough time to finish asynchronous persistence or foreground-service shutdown. Automatically restarting location tracking while restoring an exploration would also conflict with the rule that a foreground location session starts only after a visible user action.

## Decision

- Treat a persisted `active` exploration as an interrupted session on the next application launch.
- Ask `LocationService` to stop any remaining native location session, change the exploration to `paused`, and persist that state without starting tracking.
- Route interrupted and explicitly paused explorations to `PausedExplorationView`.
- Start tracking again only after the user presses the centered resume button.
- Allow a manual stop with zero observations after an explicit confirmation. Such an exploration can be saved to the journal without changing companion growth.

## Consequences

Background tracking continues while the application is merely backgrounded, but a subsequent cold start never resumes location collection implicitly. The exact moment of process termination cannot be recorded reliably; the paused state becomes authoritative during the next successful initialization. A stop failure must not be presented as paused, and remains an error that requires another stop attempt.
