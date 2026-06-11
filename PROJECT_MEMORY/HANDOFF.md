# Handoff

Last updated: 2026-06-11

## Start Here

The primary branch is `main` at code baseline `93c5b54` before the current
governance-document working changes. Product version is `0.1.2`.

The next implementation task is to review and validate
`codex/stability-macos-ux`, which is ahead of `main` with Android stability work
only. Do not assume it is merge-ready because it contains multiple commits.

## Immediate Procedure

```bash
git status --short --branch
git log --oneline main..codex/stability-macos-ux
git diff --stat main..codex/stability-macos-ux
./android/run_tests.sh
./android/build.sh
```

Then inspect the branch against risks R-001 and R-002 and the exit criteria in
`milestones/M1_android_stability.md`. A physical-device stress run is still
required before closing the milestone.

## Important Constraints

- Do not merge design plans as proof of implementation.
- Do not expose the receiver outside a trusted LAN.
- Preserve `.part` upload staging and size validation.
- Keep Android queue locks free of I/O and bitmap decoding.
- Do not start macOS UX work in the same batch as Android stability integration.

## Documentation on Completion

Update `00_PROJECT_STATUS.md`, this file, the relevant risk rows, the applicable
milestone, and a batch record with exact commands and results.
