# B04: macOS Idempotent Delete Handling

Date: 2026-06-22

## Objective

Prevent repeated deletion actions on an already removed received file from
surfacing the user-facing "The received file no longer exists." error.

## Scope

- Make `LibraryRepository.delete` tolerant of missing media files by treating a
  missing active file as a completed delete request and writing a tombstone.
- Make deletion of an `UploadRecord` that is already marked deleted a no-op.
- Add repository regression coverage for missing-file deletion and repeated
  deletion of an already deleted record.

## Non-Goals

- Changing rename behavior for missing files.
- Changing manifest tombstone semantics or Android reconciliation.
- Changing trash handling for files that still exist.

## Risks and Decisions

- Risks: R-008, deletion/tombstone behavior covered by ADR-005.
- Protected decisions in `04_DECISION_LOG.md` were not changed.

## Validation

Run from `/Users/ios_k/Desktop/PProject/Android_sync`:

```bash
swift build --package-path macos
```

The build completed successfully.

`swift test --package-path macos` initially compiled and ran the macOS test
suite far enough to expose the new regression tests failing against the old
delete implementation. After the fix, repeated attempts to run
`swift test --package-path macos --filter LibraryRepositoryTests` built
successfully but hung while starting the XCTest runner, both inside the sandbox
and with escalated permissions. A direct `xcrun xctest` invocation could not be
used as a replacement because macOS rejected the unsigned SwiftPM test bundle
with `library load denied by system policy`.

## Rollback

Revert the `LibraryRepository.delete` change and the associated test additions.
This restores the previous behavior where a missing file causes
`LibraryRepositoryError.missingFile`.

## Result

- Commit: pending.
- Outcome: implementation and regression tests are present; build verification
  passed. XCTest execution remains blocked by the local runner/system-policy
  issue described above.
