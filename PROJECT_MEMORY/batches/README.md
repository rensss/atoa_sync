# Batches

Create one Markdown file per non-trivial implementation batch using:

```text
YYYY-MM-DD-BNN-short-name.md
```

Each record must contain:

- objective and explicit non-goals;
- files and modules changed;
- related risk and ADR IDs;
- behavioral invariants;
- exact validation commands and results;
- rollback procedure;
- final commit and follow-up work.

Prefer batches that change a few hundred lines or less. If a batch grows beyond
what can be independently reviewed and rolled back, split it before merging.
