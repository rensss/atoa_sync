# Risk Register

Severity: Critical, High, Medium, Low.

| ID | Severity | Status | Risk | Required Control |
|---|---|---|---|---|
| R-001 | High | Open on `main`; controls validated on `codex/agent-governance` at `23b09d5`; device stress pending | Android thumbnail decoding can create excessive bitmap memory pressure or apply stale async results to reused views. | Bound decode sizes, use a bounded cache, coalesce requests, verify view identity, and handle `OutOfMemoryError`. |
| R-002 | High | Open on `main`; controls validated on `codex/agent-governance` at `23b09d5`; device stress pending | Rebuilding large queue views or copying/filtering the full queue on the UI thread can cause ANR, flashing, or lost scroll position. | Use bounded queue windows and in-place row/summary updates. Run queue regression tests and device smoke tests. |
| R-003 | High | Accepted, constrained | Receiver has no authentication and Android permits cleartext HTTP. Exposure beyond a trusted LAN permits unauthorized upload or metadata access. | Keep network access restricted to private/link-local peers. Do not expose the port publicly. Add authentication/TLS before broader deployment. |
| R-004 | High | Open on `main`; controls validated on `codex/agent-governance` at `23b09d5` | Interrupted or failed uploads may leave `.incoming/*.part` files if every failure path does not clean up. | Ensure connection close and storage failure paths remove temporary files; add interruption tests. |
| R-005 | Medium | Open on `main`; controls validated on `codex/agent-governance` at `23b09d5` | Receiver-wide failure and single-upload failure currently share `.failed`, which can incorrectly mark the whole receiver as unavailable. | Separate listener lifecycle failures from per-upload failures and test both event paths. |
| R-006 | Medium | Mitigated | Duplicate names can overwrite user media. | `LibraryRepository` generates unique destination names. Preserve this behavior and its tests. |
| R-007 | Medium | Mitigated | Incomplete uploads can be committed as valid files. | Stream to `.part`, compare actual and expected size, then move into place. Preserve size-mismatch tests. |
| R-008 | Medium | Open | Manifest is append-only JSONL; corruption or unbounded growth can degrade startup and reconciliation. | Keep parsing tolerant, add malformed-line coverage, and design compaction before long-term high-volume use. |
| R-009 | Medium | Open | Android queue state is process-local. App termination can lose waiting, failed, and retry state. | Decide whether persistence is required before claiming resumable synchronization. |
| R-010 | Low | Open | Command-line Android build depends on locally installed SDK tools and paths, reducing reproducibility. | Document prerequisites and consider a pinned CI environment without replacing the current build system casually. |

## Closed Risks

| ID | Closed In | Evidence |
|---|---|---|
| R-C01 | `v0.1.1` | Queue rendering was capped with `TaskWindow` to avoid creating every media row at once. |
| R-C02 | `0621390` | Obsolete Python receiver removed; native macOS receiver is the single supported implementation. |

## Change Rule

Any change touching media decoding, queue synchronization, receiver lifecycle,
network exposure, temporary files, manifest parsing, or deletion must name the
relevant risk IDs in its batch record. A risk closes only with reproducible
verification evidence and a commit reference.
