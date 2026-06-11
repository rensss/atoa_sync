# Project Status

Last reviewed: 2026-06-11

## Baseline

- Product version: `0.1.2`
- Primary branch: `main`
- Remote: `origin` at `git@github.com:rensss/atoa_sync.git`
- Code baseline before this governance update: `93c5b54`
- Governance work branch: `codex/agent-governance`
- Latest released tag: `v0.1.2`
- Repository layout: Android code under `android/`, macOS code under `macos/`
- Supported receiver: native macOS `ReceiverService`

## Verified Current State

- `main` contains the released Android `0.1.2` implementation and native macOS
  receiver/media library.
- Platform reorganization and removal of the obsolete Python receiver are
  complete.
- The stability and macOS UX design and implementation plan are present under
  `docs/superpowers/`.
- The full stability and macOS UX plan is not implemented on `main`.
- Branch `codex/stability-macos-ux` contains Android-only work beyond `main`,
  including bounded thumbnail requests, thumbnail lifecycle guards, in-place
  queue updates, and sync-generation isolation. It has not been merged.

## Open Work

1. Review and validate `codex/stability-macos-ux` against current `main`.
2. Merge or selectively port the verified Android stability batches.
3. Implement the remaining macOS UX and lifecycle work from the approved plan.
4. Add regression coverage for the macOS application target.
5. Reassess LAN authentication and transport security before use outside a
   trusted private network.

## Current Validation Record

The platform split was previously validated with:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos
```

These commands have not been rerun for this documentation-only governance
change. Future status updates must record the exact checks run.

## Status Maintenance

Update this file whenever the primary branch, release version, active phase,
open work, or verified validation state changes. Never mark planned work as
complete solely because a plan or branch exists.
