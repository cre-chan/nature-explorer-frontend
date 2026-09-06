# ADR 0003: Explicit location session lifecycle

Status: accepted

## Context

Cancelling the Geolocator position stream left its Android foreground service and ongoing notification active on a Sony A102SO. This violates the product rule that location is recorded only while an exploration is active. The upstream cancellation issue remains open: <https://github.com/Baseflow/flutter-geolocator/issues/1682>.

## Decision

- Replace `geolocator` with the pinned `location` 10.0.2 package.
- Expose explicit asynchronous `startTracking` and `stopTracking` operations through `LocationService` instead of exposing an unowned position stream.
- Let `LocalExplorationRepository` own the stream subscription and await both stream cancellation and background-mode shutdown before changing an exploration to paused or completed.
- Start Android's location foreground service only from a visible, user-initiated exploration action and do not request `ACCESS_BACKGROUND_LOCATION`.
- Calculate distance with a private Dart Haversine implementation so the domain result does not depend on the selected platform plugin.

## Consequences

Pause, stop, automatic timeout, deletion, and disposal share one verifiable shutdown path. A shutdown failure remains visible as an active exploration and is surfaced to the user instead of falsely claiming that location recording stopped. The application takes responsibility for testing the notification and foreground service lifecycle on a physical Android device whenever the location package changes.
