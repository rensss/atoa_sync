# Project Status

Last reviewed: 2026-06-22

## Baseline

- Product version: `0.1.2`
- Primary branch: `main`
- Remote: `origin` at `git@github.com:rensss/atoa_sync.git`
- Current main integration commit: `8a09aa0`
- Latest B04 implementation commit on `main`: `fee8063`
- Governance work branch: `codex/agent-governance` at `a07593a`
- Candidate implementation branch: `codex/stability-macos-ux` at `cbf31db`
- Integration branch: `codex/agent-governance` at `23b09d5`
- Latest released tag: `v0.1.2`
- Repository layout: Android code under `android/`, macOS code under `macos/`
- Supported receiver: native macOS `ReceiverService`

## Verified Current State

- `main` contains the released Android `0.1.2` implementation, native macOS
  receiver/media library, repository governance documents, and the approved
  Android stability and macOS UX implementation.
- Platform reorganization and removal of the obsolete Python receiver are
  complete.
- The stability and macOS UX design and implementation plan are present under
  `docs/superpowers/`.
- Branch `codex/stability-macos-ux` implements the approved Android stability
  and macOS UX plan. It was merged into `codex/agent-governance` at `23b09d5`
  and then into `main` at `8a09aa0` on 2026-06-22. Android work includes
  bounded/coalesced thumbnail requests, lifecycle guards, in-place queue
  updates, and sync-generation isolation. macOS work includes default Chinese
  localization, native toolbar controls, stable thumbnail sizing, Space-key
  Quick Look, failed-upload cleanup, serialized receiver lifecycle handling,
  settings, and version information.
- The candidate branch passes Android tests/build and 75 macOS tests, builds the
  macOS release target, and produces a signed app bundle with version `0.1.2`
  and build `35`. Independent final code review found no blocking issues. The
  integration merge at `23b09d5` passed Android tests/build, Swift tests, and
  macOS app verification on 2026-06-22.
- No Android device was connected for the required stress run. The current
  automation session also could not capture the macOS display for final visual
  QA, so neither platform milestone should be treated as fully accepted.
- B04 changes on `main` make macOS delete handling idempotent when a received
  file is already gone or already marked deleted. The implementation commit is
  `fee8063`. Build verification passed; XCTest execution is currently blocked
  by the local runner/system-policy issue recorded in
  `PROJECT_MEMORY/batches/2026-06-22-B04-macos-idempotent-delete.md`.

## Open Work

1. Complete physical-device Android stress testing for large libraries,
   navigation, lifecycle transitions, and repeated sync starts.
2. Perform final macOS visual and interaction QA for toolbar placement,
   localized menus, inspector/search layout, thumbnails, and Quick Look.
3. Reassess LAN authentication and transport security before use outside a
   trusted private network.

## Current Validation Record

Candidate commit `cbf31db` was validated on 2026-06-15 with:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos -c release
bash -n macos/build_and_run.sh
./macos/build_and_run.sh verify
plutil -lint "dist/Android Sync.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Android Sync.app"
```

All commands passed. The macOS suite ran 75 tests. The generated plist reported
`CFBundleShortVersionString=0.1.2` and `CFBundleVersion=35`. ADB reported no
connected devices, and display capture was unavailable in the automation
session.

Integration commit `23b09d5` was created on 2026-06-22 by merging
`codex/stability-macos-ux` into `codex/agent-governance`. The integrated commit
was validated on 2026-06-22 with:

```bash
git diff --check
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

All commands passed. Swift ran 75 tests. Android physical-device stress testing
and final macOS visual/interaction QA remain open.

Main merge commit `8a09aa0` was created on 2026-06-22 by merging
`codex/agent-governance` into `main`. The merge completed without conflicts.

B04 local macOS idempotent delete changes were validated on 2026-06-22 with:

```bash
swift build --package-path macos
```

The build passed. The following command built successfully but hung while
starting XCTest in this automation environment, including with escalated
permissions:

```bash
swift test --package-path macos --filter LibraryRepositoryTests
```

Direct `xcrun xctest` was rejected by macOS system policy for the unsigned
SwiftPM test bundle.

## Status Maintenance

Update this file whenever the primary branch, release version, active phase,
open work, or verified validation state changes. Never mark planned work as
complete solely because a plan or branch exists.
