# Phase 0 Freeze: Repository and Receiver Consolidation

Frozen: 2026-06-08

## Included Baseline

- Commit: `0621390` (`Reorganize Android and macOS projects`)
- Android implementation and prototype owned by `android/`
- Native Swift package and receiver owned by `macos/`
- Obsolete standalone Python receiver removed
- Root retained for shared project metadata, releases, and documentation

## Frozen Contracts

- Native macOS `ReceiverService` is the supported local receiver.
- Android browser prototype remains under `android/prototype/`.
- macOS packaged output remains under root `dist/`.
- Platform build and test commands are invoked from the repository root.

## Recorded Validation

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos
```

The phase may be superseded only through a new roadmap phase and ADR. This file
is a historical snapshot and must not be edited to describe later behavior.
