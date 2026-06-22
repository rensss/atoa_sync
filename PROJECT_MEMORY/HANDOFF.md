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
