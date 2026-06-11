# Architecture Decision Log

Decisions are append-only. To change an accepted decision, add a new ADR that
explicitly supersedes it and obtain user approval before implementation.

## ADR-001: Platform-Owned Repository Layout

- Date: 2026-06-08
- Status: Accepted

Context: Active Android and macOS files were mixed at the repository root.

Decision: Android implementation belongs under `android/`; macOS implementation
belongs under `macos/`; shared metadata and releases remain at the root.

Consequences: Each platform is independently understandable and buildable.
Platform-specific files must not drift back to the root.

## ADR-002: Native macOS Receiver Is the Supported Receiver

- Date: 2026-06-08
- Status: Accepted

Context: A standalone Python receiver duplicated native macOS functionality.

Decision: Remove the Python receiver and use
`macos/Sources/AndroidSyncCore/ReceiverService.swift` as the supported local
computer receiver.

Consequences: Receiver protocol and storage changes must be implemented and
tested in `AndroidSyncCore`.

## ADR-003: Preserve Existing Platform Toolchains

- Date: 2026-06-08
- Status: Accepted

Context: The Android app uses direct Android SDK scripts and the macOS app uses
SwiftPM, SwiftUI, and SwiftData.

Decision: Continue those toolchains during the stability and UX refactor.

Consequences: Introducing Gradle, third-party Android libraries, another macOS
package manager, or a replacement UI framework requires a superseding ADR.

## ADR-004: Stream Then Atomically Commit Uploads

- Date: 2026-06-08
- Status: Accepted

Context: Partial network transfers must not appear as complete library media.

Decision: Stream uploads to `.incoming/*.part`, verify expected size, then move
the completed file into its final dated media directory.

Consequences: Every error and cancellation path must clean temporary files.
Direct writes to final media paths are prohibited.

## ADR-005: Append-Only Manifest with Tombstones

- Date: 2026-06-08
- Status: Accepted

Context: Android reconciliation requires durable knowledge of stored and
deleted media.

Decision: Record stored and deleted events in `uploads.jsonl`; represent
deletions as tombstones instead of erasing history.

Consequences: Readers must derive latest state per stable ID and tolerate
historical records. Future compaction must preserve equivalent semantics.

## ADR-006: Trusted-LAN Operation for Current Releases

- Date: 2026-06-11
- Status: Accepted risk

Context: Current protocol uses cleartext HTTP and no authentication.

Decision: Limit current operation to trusted private/link-local networks.

Consequences: Documentation must not imply internet-safe deployment. Public
exposure, authentication, or TLS requires a separate security decision and
protocol design.

## ADR-007: Batch-Governed Evolution

- Date: 2026-06-11
- Status: Accepted

Context: Stability, concurrency, storage, and UI work have different failure
modes and verification needs.

Decision: Implement non-trivial work as small batches with scope, risks,
validation evidence, and rollback instructions in `PROJECT_MEMORY/batches/`.

Consequences: Large all-at-once refactors are outside the approved execution
model. Milestone completion requires accumulated batch evidence.
