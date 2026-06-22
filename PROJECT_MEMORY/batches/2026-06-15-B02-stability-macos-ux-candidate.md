# B02: Stability and macOS UX Candidate

Date: 2026-06-15

## Objective

Record the completed candidate implementation and automated verification for
the approved Android stability and macOS UX plan.

## Scope

- Android thumbnail memory, request coalescing, lifecycle guards, queue refresh,
  ordering, and synchronization generations.
- macOS localization, toolbar placement, thumbnail layout, Quick Look, failed
  upload cleanup, receiver lifecycle serialization, settings, and version data.
- Regression tests, platform documentation, packaging, and changelog entries.

## Non-Goals

- Merging the candidate branch into `main`.
- Closing the Android stability milestone without a physical-device stress run.
- Claiming final macOS visual acceptance without interactive GUI inspection.
- Changing LAN authentication or cleartext transport policy.

## Risks and Decisions

- Risks: R-001, R-002, R-004, R-005.
- Protected decisions in `04_DECISION_LOG.md` were not changed.

## Invariants

- Android queue locks remain free of bitmap decoding and network I/O.
- macOS uploads remain staged as `.part` files and validated before commit.
- Unique destination naming and tolerant manifest parsing remain intact.
- The receiver remains limited to trusted local networks.

## Validation

Run from
`/Users/ios_k/Desktop/PProject/Android_sync/.worktrees/stability-macos-ux`
at candidate commit `cbf31db`:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos -c release
bash -n macos/build_and_run.sh
./macos/build_and_run.sh verify
plutil -lint "dist/Android Sync.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Android Sync.app"
git diff --check
```

All commands exited successfully. The macOS suite ran 75 tests. The app bundle
reported version `0.1.2`, build `35`, and passed strict deep code-signature
verification. The Android APK was produced successfully.

An independent final code review found and drove fixes for Quick Look keyboard
event routing, preview observer lifecycle, and Android home-grid status refresh.
The final review approved `cbf31db` with no blocking issues.

`adb devices -l` reported no connected devices. macOS display capture was also
unavailable in the automation session, so device stress and final visual QA are
explicit follow-ups.

## Rollback

Do not merge `codex/stability-macos-ux`, or revert its integration commit as a
unit after merge. No persistent data migration is introduced. Failed-upload
cleanup behavior should be retained if individual macOS commits are ported.

## Result

- Commit: candidate `cbf31db`; merged into `codex/agent-governance` at
  `23b09d5` and then into `main` at `8a09aa0` on 2026-06-22.
- Outcome: implementation, candidate automated verification, and merged-commit
  automated validation are complete; acceptance is blocked on device/GUI
  evidence.
- Follow-up: run the missing manual checks and record final acceptance evidence.
