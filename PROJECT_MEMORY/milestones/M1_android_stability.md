# M1: Android Runtime Stability

Status: In progress

## Entry Criteria

- [x] Stability design and implementation plan exist.
- [x] Current Android tests and build commands are documented.
- [x] Relevant risks R-001 and R-002 are registered.

## Exit Criteria

- [ ] Grid thumbnail requests are bounded to display-scale dimensions.
- [ ] Preview requests have a documented upper bound.
- [ ] Thumbnail cache has a strict memory/entry bound.
- [ ] Duplicate decode requests are coalesced.
- [ ] Stale async thumbnail results cannot update reused or detached views.
- [ ] Queue status and pagination updates do not rebuild the full screen.
- [ ] Stale synchronization generations cannot mutate the active run.
- [ ] `./android/run_tests.sh` passes on the target commit.
- [ ] `./android/build.sh` passes and verifies the APK signature.
- [ ] Physical-device stress test covers large media libraries, rapid
  navigation, background/foreground transitions, and repeated sync starts.
- [ ] No OOM, ANR, queue-state regression, or stale-thumbnail defect is observed.

## Candidate Evidence

Branch `codex/stability-macos-ux` contains candidate commits for these controls.
They are not accepted milestone evidence until reviewed and validated against
the final integration commit.

## Rollback

Revert the integration batch as a unit. Do not remove the existing bounded
`TaskWindow` behavior introduced before this milestone.
