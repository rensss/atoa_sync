# Refactor Roadmap

## Operating Rule

Work proceeds in independently verifiable batches. Do not combine Android
stability, macOS UX, protocol changes, and storage migrations in one batch.

## Phase 0: Repository and Receiver Consolidation

Status: Complete and frozen.

- Split Android and macOS ownership into platform directories.
- Remove the obsolete Python receiver.
- Make the native macOS receiver the supported computer-side implementation.
- Validate both platform build and test commands.

Freeze record: `freezes/phase0_freeze.md`

## Phase 1: Android Runtime Stability

Status: Implemented and merged to `main` at `8a09aa0`; physical-device stress
testing remains open.

- Bound grid and preview decode sizes.
- Add bounded thumbnail caching and request coalescing.
- Prevent stale thumbnail delivery after view reuse or lifecycle changes.
- Update queue rows and summaries in place.
- Isolate stale sync generations.
- Validate with unit tests, APK build, and physical-device stress testing.

Exit criteria are defined in `milestones/M1_android_stability.md`.

## Phase 2: macOS Receiver Correctness

Status: Implemented on `main` at `8a09aa0`; monitor during final QA.

- Separate listener failures from individual upload failures.
- Guarantee temporary-file cleanup on interruption and failure.
- Add receiver lifecycle and interrupted-upload regression coverage.
- Preserve atomic commit, metadata, unique naming, and tombstones.

## Phase 3: macOS UX and Application Tests

Status: Implemented on `main` at `8a09aa0`; final visual/interaction QA
remains open.

- Adopt native toolbar structure and stable thumbnail layout.
- Add runtime Chinese/English localization.
- Complete search, sorting, Inspector, Quick Look, and settings behavior.
- Add an `AndroidSyncMacTests` target for app-state and localization logic.

## Phase 4: Security and Operational Hardening

Status: Future.

- Decide authentication and transport-security requirements.
- Add CI for Android tests/build and Swift tests/build.
- Define manifest compaction and recovery.
- Define queue persistence and resumability requirements.
- Establish signed release and checksum publication procedures.

## Scope Boundaries

- Do not replace the dependency-free Android build without an approved ADR.
- Do not replace SwiftPM/SwiftUI/SwiftData without an approved ADR.
- Do not change the upload protocol or storage layout incidentally during UI
  work.
- Do not declare a phase complete until its milestone file contains passing
  evidence for the target commit.
