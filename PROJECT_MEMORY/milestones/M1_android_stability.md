# M1: Android Runtime Stability

Status: In progress

## Entry Criteria

- [x] Stability design and implementation plan exist.
- [x] Current Android tests and build commands are documented.
- [x] Relevant risks R-001 and R-002 are registered.

## Exit Criteria

- [x] Grid thumbnail requests are bounded to display-scale dimensions.
- [x] Preview requests have a documented upper bound.
- [x] Thumbnail cache has a strict memory/entry bound.
- [x] Duplicate decode requests are coalesced.
- [x] Stale async thumbnail results cannot update reused or detached views.
- [x] Queue status and pagination updates do not rebuild the full screen.
- [x] Stale synchronization generations cannot mutate the active run.
- [x] `./android/run_tests.sh` passes on the target commit.
- [x] `./android/build.sh` passes and verifies the APK signature.
- [ ] Physical-device stress test covers large media libraries, rapid
  navigation, background/foreground transitions, and repeated sync starts.
- [ ] No OOM, ANR, queue-state regression, or stale-thumbnail defect is observed.

## Candidate Evidence

Branch `codex/stability-macos-ux` at `cbf31db` contains the candidate controls.
On 2026-06-15, `./android/run_tests.sh` and `./android/build.sh` passed. No
Android device was connected, so the physical-device criteria and final
no-regression observation remain open. These controls were merged into
`codex/agent-governance` at `23b09d5` on 2026-06-22, but are not accepted on
`main` until device evidence is recorded.

On 2026-06-22, the integrated commit passed `./android/run_tests.sh` and
`./android/build.sh`. It was merged into `main` at `8a09aa0`. Physical-device
stress testing remains open.

## Rollback

Revert the integration batch as a unit. Do not remove the existing bounded
`TaskWindow` behavior introduced before this milestone.
