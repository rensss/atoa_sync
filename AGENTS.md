# Agent Instructions

This file is the repository-wide instruction entry point for coding agents.
Project state and design memory live under `PROJECT_MEMORY/`.

## Required Startup Sequence

Before planning or editing:

1. Read `PROJECT_MEMORY/00_PROJECT_STATUS.md`.
2. Read `PROJECT_MEMORY/HANDOFF.md`.
3. Read `PROJECT_MEMORY/01_ARCHITECTURE.md`.
4. Read `PROJECT_MEMORY/02_RISK_REGISTER.md`.
5. Read `PROJECT_MEMORY/03_REFACTOR_ROADMAP.md`.
6. Read `PROJECT_MEMORY/04_DECISION_LOG.md`.
7. Read the relevant platform README and applicable milestone or batch files.

Do not infer completion from a plan document. Confirm current behavior from the
checked-out branch, source, tests, and Git history.

## Project

Android Sync transfers photos and videos from Android to macOS or another
HTTP/WebDAV-compatible destination on the local network.

## Repository Layout

- `android/` owns the dependency-free Android app, tests, build scripts, and
  browser UI prototype.
- `macos/` owns the native Swift receiver, media library, tests, resources, and
  packaging scripts.
- `docs/` contains shared project documentation.
- `releases/` contains versioned release artifacts and historical release notes.
- `dist/` and platform build directories are generated output.

Keep platform-specific code inside its owning platform directory. Do not
reintroduce Android or macOS implementation files at the repository root.

## Working Guidelines

- Read the relevant platform README before changing platform behavior.
- Follow existing code patterns and scripts instead of introducing a new build
  system or dependency without a clear need.
- Keep changes scoped to the request and do not overwrite unrelated local work.
- Do not manually edit generated build output or commit ignored artifacts.
- Update documentation when commands, layout, configuration, or user-visible
  behavior changes.
- Treat decisions in `PROJECT_MEMORY/04_DECISION_LOG.md` as protected. Changing
  one requires explicit user approval and a superseding ADR.
- Check `PROJECT_MEMORY/02_RISK_REGISTER.md` before changing concurrency,
  networking, storage, lifecycle, or media decoding behavior.
- Keep each implementation batch reviewable and independently verifiable.
  Record non-trivial batches in `PROJECT_MEMORY/batches/`.
- Update `PROJECT_MEMORY/00_PROJECT_STATUS.md` and `PROJECT_MEMORY/HANDOFF.md`
  when a task changes the baseline, open work, validation state, or next action.
- Add milestone evidence under `PROJECT_MEMORY/milestones/` when a roadmap phase
  reaches its entry or exit criteria.
- Never claim a risk or milestone is closed without recording verification
  evidence and the commit or branch where that evidence applies.

## Verification

Run the checks relevant to the files changed:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh
```

Use the narrowest sufficient checks during development, then run the affected
platform's test suite before considering the work complete.

## Completion Contract

A development task is complete only when:

- the requested behavior is implemented;
- relevant tests or builds pass, or any unavailable check is stated explicitly;
- new risks and decisions are recorded;
- status and handoff documents reflect the resulting repository state;
- generated files and secrets are excluded from the change.
