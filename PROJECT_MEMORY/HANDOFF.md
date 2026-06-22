# Handoff

Last updated: 2026-06-22

## Start Here

The primary branch is `main` at `93c5b54`. Governance documents and the merged
stability/macOS UX candidate are on `codex/agent-governance` at `23b09d5`.
Product version is `0.1.2`.

The candidate implementation branch `codex/stability-macos-ux` is at `cbf31db`.
It contains the complete approved Android stability and macOS UX work plus
automated regression coverage. Independent final code review approved the
candidate with no blocking issues. It was merged into `codex/agent-governance`
at `23b09d5` on 2026-06-22. The merged commit passed automated Android/macOS
validation and still needs physical-device Android stress testing and final
macOS visual/interaction QA.

## Immediate Procedure

```bash
git status --short --branch
git log --oneline main..codex/agent-governance
git diff --stat main..codex/agent-governance
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

The automated checks above passed on 2026-06-22 for integration commit
`23b09d5`. Perform the missing device and GUI checks recorded in
`batches/2026-06-15-B02-stability-macos-ux-candidate.md`. Review the integrated
branch against risks R-001, R-002, R-004, and R-005 before merging it into
`main`.

## Important Constraints

- Do not merge design plans as proof of implementation.
- Do not expose the receiver outside a trusted LAN.
- Preserve `.part` upload staging and size validation.
- Keep Android queue locks free of I/O and bitmap decoding.
- Keep final Android integration evidence distinct from macOS acceptance even
  though both implementations currently share the candidate branch.

## Documentation on Completion

After device/GUI QA and any `main` integration, update `00_PROJECT_STATUS.md`,
this file, the relevant risk rows, the applicable milestone, and the batch
record with the final `main` integration commit.
