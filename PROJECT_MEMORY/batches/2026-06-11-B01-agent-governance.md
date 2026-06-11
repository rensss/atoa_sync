# B01: Agent Governance Baseline

Date: 2026-06-11

## Objective

Create a tool-neutral agent entry point and durable project-memory structure
grounded in the current repository state.

## Scope

- Rename `AGENT.md` to `AGENTS.md`.
- Point Claude and GitHub Copilot instructions to `AGENTS.md`.
- Add status, architecture, risk, roadmap, ADR, handoff, freeze, milestone, and
  batch documentation under `PROJECT_MEMORY/`.
- Add contributor guidance.

## Non-Goals

- No application source or runtime behavior changes.
- No merge of `codex/stability-macos-ux`.
- No release or version change.

## Risks and Decisions

- Establishes ADR-007.
- Documents existing risks R-001 through R-010.

## Validation

Required before closing this batch:

```bash
git diff --check
rg -n "AGENT\\.md" --glob '!PROJECT_MEMORY/batches/2026-06-11-B01-agent-governance.md'
```

No platform test is required because this batch changes documentation only.

## Rollback

Revert the governance commit. Application source and released artifacts are
unaffected.

## Result

- `git diff --check`: passed.
- Singular `AGENT.md` reference scan: passed; no stale references outside this
  historical batch description.
- Platform tests were not run because application source and runtime behavior
  did not change.
- Commit: the commit containing this batch record.
