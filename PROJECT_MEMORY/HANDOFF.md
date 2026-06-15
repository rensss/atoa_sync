# Handoff

Last updated: 2026-06-15

## Start Here

The primary branch is `main` at `93c5b54`. Governance documents are on
`codex/agent-governance` at `c83955c`. Product version is `0.1.2`.

The candidate implementation branch `codex/stability-macos-ux` is at `2370006`.
It now contains the complete approved Android stability and macOS UX work plus
automated regression coverage. It is not merged and still needs physical-device
Android stress testing and final macOS visual/interaction QA.

## Immediate Procedure

```bash
git status --short --branch
git log --oneline main..codex/stability-macos-ux
git diff --stat main..codex/stability-macos-ux
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

Then perform the missing device and GUI checks recorded in
`batches/2026-06-15-B02-stability-macos-ux-candidate.md`. Review the branch
against risks R-001, R-002, R-004, and R-005 before integration. Preserve the
governance files when bringing the older feature branch onto current `main`.

## Important Constraints

- Do not merge design plans as proof of implementation.
- Do not expose the receiver outside a trusted LAN.
- Preserve `.part` upload staging and size validation.
- Keep Android queue locks free of I/O and bitmap decoding.
- Keep final Android integration evidence distinct from macOS acceptance even
  though both implementations currently share the candidate branch.

## Documentation on Completion

After device/GUI QA and integration, update `00_PROJECT_STATUS.md`, this file,
the relevant risk rows, the applicable milestone, and the batch record with the
final integration commit.
