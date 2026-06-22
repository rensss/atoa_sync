# Project Memory

This directory is the durable technical memory for Android Sync. It separates
verified repository state from plans, assumptions, and historical context.

## Reading Order

1. `00_PROJECT_STATUS.md`
2. `HANDOFF.md`
3. `01_ARCHITECTURE.md`
4. `02_RISK_REGISTER.md`
5. `03_REFACTOR_ROADMAP.md`
6. `04_DECISION_LOG.md`
7. Relevant files in `milestones/`, `batches/`, and `freezes/`

## Update Rules

- Write facts that are verifiable from the repository or a recorded command.
- Include dates, branches, commits, and validation evidence where relevant.
- Distinguish planned, in progress, blocked, and completed work.
- Do not rewrite historical ADRs or freeze records. Add a superseding record.
- Keep `HANDOFF.md` short enough to read at the start of every task.
