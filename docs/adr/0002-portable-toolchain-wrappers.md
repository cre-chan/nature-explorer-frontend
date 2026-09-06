# ADR 0002: Portable user-local toolchain wrappers

Status: accepted

## Context

Contributors must be able to build the Android prototype on macOS, Linux, and Windows without Android Studio, a global Flutter SDK, or changes to system Java and shell profiles. The selected SDK binaries differ by operating system and CPU.

## Decision

- Keep Flutter, Temurin JDK, and Android SDK in each operating system's user-data directory.
- Pin every supported archive URL and SHA-256 in `.toolchain.lock`.
- Support macOS arm64/x64 and Linux x64 with POSIX shell scripts.
- Support Windows x64 with PowerShell scripts instead of requiring a Unix compatibility layer.
- Reject unsupported CPU and OS combinations before downloading.
- Expose all Flutter, Dart, ADB, and SDK Manager commands through repository wrappers.
- Generate `android/local.properties` from the selected user-local paths.

## Consequences

The project does not depend on global PATH contents or IDE-managed SDKs, and setup is reproducible across supported hosts. POSIX and PowerShell implementations duplicate a small set of pinned constants, so changes to a toolchain version must update both scripts and `.toolchain.lock` in the same commit. Linux arm64 and other combinations without a matching official Flutter bundle remain explicitly unsupported.
