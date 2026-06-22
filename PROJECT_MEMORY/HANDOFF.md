# Handoff

Last updated: 2026-06-22

## Start Here

The primary branch is `main` at `8a09aa0`. Product version is `0.1.2`.
Governance documents and the approved stability/macOS UX implementation are now
merged into `main`.

The candidate implementation branch `codex/stability-macos-ux` is at `cbf31db`.
It contains the complete approved Android stability and macOS UX work plus
automated regression coverage. Independent final code review approved the
candidate with no blocking issues. It was merged into `codex/agent-governance`
at `23b09d5` and then into `main` at `8a09aa0` on 2026-06-22. The integrated
commit passed automated Android/macOS validation and still needs
physical-device Android stress testing and final macOS visual/interaction QA.

## Immediate Procedure

```bash
git status --short --branch
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

The automated checks above passed on 2026-06-22 for integration commit
`23b09d5`. Perform the missing device and GUI checks recorded in
`batches/2026-06-15-B02-stability-macos-ux-candidate.md`. Review risks R-001
and R-002 before accepting the Android stability milestone.

## Latest Local Work

B04 macOS idempotent delete handling is ready on `main`.
`LibraryRepository.delete` no longer reports `missingFile` when an active
record's file is already gone, and deletion of an already deleted record is a
no-op. Regression tests were added in `LibraryRepositoryTests`.

Validation for B04: `swift build --package-path macos` passed on 2026-06-22.
The following command built successfully but hung while starting XCTest in this
automation environment, including with escalated permissions:

```bash
swift test --package-path macos --filter LibraryRepositoryTests
```

Direct `xcrun xctest` was blocked by macOS system policy for the unsigned
SwiftPM test bundle.

## Important Constraints

- Do not merge design plans as proof of implementation.
- Do not expose the receiver outside a trusted LAN.
- Preserve `.part` upload staging and size validation.
- Keep Android queue locks free of I/O and bitmap decoding.
- Keep final Android integration evidence distinct from macOS acceptance even
  though both implementations currently share the candidate branch.

## Documentation on Completion

After device/GUI QA, update `00_PROJECT_STATUS.md`, this file, the relevant
risk rows, the applicable milestone, and the batch record with the evidence.
