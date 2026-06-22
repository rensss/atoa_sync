# B03: Merge Stability and macOS UX Candidate

Date: 2026-06-22

## Objective

Merge the approved `codex/stability-macos-ux` candidate into the current
governance branch and then into `main` while preserving repository memory and
agent instructions.

## Scope

- Merge `codex/stability-macos-ux` into `codex/agent-governance`.
- Merge `codex/agent-governance` into `main`.
- Preserve governance files added after the candidate branch diverged from
  `main`.
- Update project memory to record the integration commit and remaining
  validation gaps.

## Non-Goals

- No release or version change.
- No claim that physical-device Android stress testing or macOS visual QA is
  complete.

## Risks and Decisions

- Risks: R-001, R-002, R-004, R-005.
- Protected decisions in `04_DECISION_LOG.md` were not changed.

## Validation

Merge command:

```bash
git merge --no-ff codex/stability-macos-ux
```

The merge completed without conflicts and created integration commit `23b09d5`.
The integrated commit was validated with:

```bash
git diff --check
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

All commands passed. Swift ran 75 tests. Android physical-device stress testing
and macOS visual/interaction QA remain open.

The `main` merge also completed without conflicts and created merge commit
`8a09aa0`.

## Rollback

Revert main merge commit `8a09aa0` as a unit if `main` must return to the
pre-integration baseline.

## Result

- Commit: `8a09aa0`.
- Outcome: candidate implementation is integrated into `main`; automated checks
  passed on the integrated content before the final `main` merge.
- Follow-up: complete physical-device Android stress testing and macOS
  visual/interaction QA.
