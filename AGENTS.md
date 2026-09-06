# Project instructions

The user's explicit instructions take precedence over this file.

## Architecture

- Follow Flutter's official MVVM guidance. Dependencies flow only from View to ViewModel to Repository to Service.
- Keep business and data logic out of Views. Views render UI state and invoke ViewModel commands.
- Implement ViewModels as Riverpod Notifiers. Inject dependencies with Riverpod Providers.
- ViewModels must not call SQLite, GPS, camera, filesystem, clocks, or AI services directly.
- Repositories are the only data gateway and source of truth. Repositories may use Services, but must not depend on other Repositories.
- Services wrap one external data source and remain stateless.
- Provider dependencies flow only from Service Providers to Repository Providers to ViewModel Providers to Views.
- Organize UI by feature: onboarding, home, exploration, observation, journal, and settings.
- Do not add Stacked, Flutter Modular, GetIt, or another DI/navigation framework.

## Privacy and behavior

- Never display raw coordinates or route maps. Show only duration, approximate distance, photo count, and observation count.
- Re-encode captured photos without EXIF metadata before persisting them.
- Record location only while an exploration is active. Support pause, resume, manual stop, and a 30-minute automatic stop.
- Restore an exploration interrupted by process termination as paused. Restart location tracking only after a visible resume action.
- Allow manual stop with zero observations only after a confirmation dialog; zero-observation journals must not advance companion growth.
- Keep an exploration active and show an error while location shutdown is failing; automatic timeout shutdown must retry until it succeeds.
- A low-confidence or indeterminate AI result is not a failed exploration.
- Saving a journal entry must never block another exploration on the same day.

## Toolchain

- Use only the repository wrappers in `tool/`: extensionless scripts on macOS/Linux and `.cmd` entry points backed by `.ps1` scripts on Windows. Do not change system Java, Node.js, global PATH, or shell profiles.
- Do not install Android Studio, an Android emulator, or a global Android SDK.
- Keep SDK and package versions pinned in `.toolchain.lock`, Android project files, and `pubspec.lock`.
- When a toolchain version changes, update `.toolchain.lock`, POSIX scripts, PowerShell scripts, and user documentation together.
- Do not commit `android/local.properties`, credentials, device identifiers, or captured user data.

## Comments

- Add concise documentation comments to public classes, interfaces, providers, and non-obvious state transitions.
- Explain intent, constraints, privacy decisions, and architectural boundaries. Do not restate syntax or narrate every line.
- Keep comments next to the behavior they explain and update or remove them when behavior changes.
- Document why location, image metadata, persistence ordering, or error handling is implemented a particular way when that reason is not obvious from the code.

## Documentation

- Update `docs/architecture.md` in the same change whenever a View, ViewModel, Repository, Service, Provider, or feature file is added, moved, renamed, or changes responsibility.
- Record durable technical decisions and tradeoffs in `docs/adr/`; do not use an ADR as a substitute for current architecture documentation.
- Update `README.md` whenever setup, test, release, wrapper, supported-platform, or device instructions change.
- Keep roles separate: `README.md` is for users, `docs/architecture.md` describes the current code, ADRs explain decisions, and `AGENTS.md` contains mandatory implementation rules.

## Verification

- Replace GPS, camera, clock, AI, and database providers with fakes in automated tests.
- Run these checks before considering an implementation complete:
  - `./tool/flutterw analyze`
  - `./tool/flutterw test`
  - `./tool/flutterw build apk --debug`
  - `./tool/adbw devices -l`
- On Windows, run the equivalent `.\tool\flutterw.cmd` and `.\tool\adbw.cmd` commands.
