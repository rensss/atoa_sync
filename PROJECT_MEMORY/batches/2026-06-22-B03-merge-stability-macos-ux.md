# B03: Merge Stability and macOS UX Candidate

Date: 2026-06-22

## Objective

Merge the approved `codex/stability-macos-ux` candidate into the current
governance branch while preserving repository memory and agent instructions.

## Scope

- Merge `codex/stability-macos-ux` into `codex/agent-governance`.
- Preserve governance files added after the candidate branch diverged from
  `main`.
- Update project memory to record the integration commit and remaining
  validation gaps.

## Non-Goals

- No merge into `main`.
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

## Rollback

Revert merge commit `23b09d5` as a unit if the integrated branch must return to
the governance-only baseline.

## Result

- Commit: `23b09d5`.
- Outcome: candidate implementation is integrated and automated checks pass on
  `codex/agent-governance`.
- Follow-up: complete physical-device Android stress testing and macOS
  visual/interaction QA, then decide whether to merge the integrated branch into
  `main`.
