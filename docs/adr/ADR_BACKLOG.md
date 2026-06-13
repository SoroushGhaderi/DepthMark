# ADR Backlog

Use this backlog to run future architecture-decision sessions one item at a
time. The backlog is not an implementation task list. Each unresolved item
should become its own ADR only after it has been pressure-tested against the
current codebase, docs, scripts contract, and operational runbooks.

DepthMark is better with this backlog when it stays narrow: it should preserve
the order of hard-to-reverse decisions that the codebase already implies, not
collect every cleanup chore. Implementation work belongs in issues or
remediation plans unless it resolves a real architectural trade-off.

## How To Run One Session

1. Pick the highest-priority unresolved item.
2. Review the current code and docs before writing the ADR.
3. Ask one decision question, with a recommended answer.
4. If the recommendation is accepted, update code and docs in the same change
   when needed.
5. Add or update the ADR under `docs/adr/`.
6. Run the narrowest useful verification command and record any remaining risk.
7. Update this backlog row to `Accepted in NNNN-title.md`, `Skipped: not
   ADR-worthy`, or `Deferred: reason`.

## Accepted Decisions

These decisions are already accepted. Keep them here only as orientation for
future sessions; do not re-open them unless new codebase evidence changes the
trade-off.

| ADR | Decision | Follow-up constraint |
| --- | --- | --- |
| `0001-use-generic-gold-sql-runners.md` | Gold signal and scenario SQL jobs are executed through generic runners, not new handwritten per-output Python wrappers. | Legacy per-signal and per-scenario runners may remain only as migration debt. |
| `0002-orchestrate-layer-entrypoints-via-cli.md` | Pipeline orchestration calls canonical script entry points through CLI subprocesses. | Any command-surface change must update the orchestrator and docs together. |
| `0003-split-gold-clickhouse-namespaces.md` | Gold outputs are split across `gold_scenarios.*`, `gold_signals.*`, and shared `gold.*` metadata. | Docs, SQL, catalogs, and drop/backfill commands must name the specific namespace. |
| `0004-keep-gold-scenario-bulk-disabled-until-validated.md` | Scenario bulk loading remains disabled until the generic scenario path is validated intentionally. | Operators should use `scripts/gold/run_sql_job.py --kind scenario ...` for scenario validation. |
| `0005-local-dev-credentials-vs-production-policy.md` | Tracked Docker Compose credentials are local-development defaults, not production policy. | Production-like setup must use non-placeholder credentials and `DEPTHMARK_ENV=production`. |
| `0006-version-signal-activation-identity-scheme.md` | `signal_id_version` versions the activation identity scheme, not signal football logic. | Changing `row_identity` is an activation identity migration concern. |
| `0007-sql-owns-analytical-transformations.md` | Silver and Gold analytical logic belongs in ClickHouse SQL; Python owns orchestration and validation. | Python exceptions for reusable analytical logic need a later ADR. |
| `0008-author-signal-catalogs-in-markdown.md` | Signal markdown frontmatter is the source of truth; MongoDB is a synchronized serving copy. | Catalog changes originate in Git and must sync to MongoDB through the catalog sync script. |
| `0009-retire-legacy-gold-per-output-runners.md` | Legacy Gold per-output Python runner files are removed; `scripts/gold/run_sql_job.py` is the only supported selected-job runner. | Omitted selectors mean all, while signal `--entity` and `--family` are separate batch selectors. |
| `0010-introduce-src-application-services-behind-script-entrypoints.md` | Stable, layer-specific application services may live under `src/` behind existing script entry points. | Scripts keep CLI compatibility and exit-code semantics; services coordinate workflows but not Silver/Gold analytical logic. |
| `0011-use-full-table-gold-activation-rebuilds.md` | Gold activation metadata is rebuilt with full-table rebuilds, not incremental or scoped activation patches. | Scoped rebuilds need a later ADR defining partition-safe replacement semantics for upstream signal outputs and match-level aggregates. |

## Queue

| Priority | Topic | Current status | Why this is ADR-worthy | Expected output |
| --- | --- | --- | --- | --- |
| P0 | Retire legacy Gold per-output Python runners | Accepted in `0009-retire-legacy-gold-per-output-runners.md` | `scripts/gold/signal/runners/` contained hundreds of generated wrapper files and `scripts/gold/scenario/` contained legacy scenario wrappers, while ADR 0001 says new Gold work should use generic SQL runners. Keeping or deleting them affects command compatibility, review surface, and repo structure. | ADR deciding deprecation/removal policy, compatibility window, and docs updates. |
| P0 | Re-enable or permanently keep disabled Gold scenario bulk loading | Accepted as disabled in `0004-keep-gold-scenario-bulk-disabled-until-validated.md`; validation decision unresolved | The Gold loader currently runs signals and activation builders, but scenario jobs are deliberately omitted. Re-enabling affects default Gold runs, failure blast radius, backfills, and runbook expectations. | ADR update or new ADR after representative scenario validation, plus loader/docs changes if accepted. |
| P1 | FotMob-only provider scope and abstraction boundary | Unresolved | The repo is FotMob-only by docs and naming, but there are generic-looking layers under `src/processors`, `src/storage`, and pipeline flags such as `--skip-fotmob`. A provider abstraction would be hard to reverse once introduced. | ADR confirming FotMob-only scope and the minimum evidence required before adding another provider abstraction. |
| P1 | `src/` application-service boundary behind script entry points | Accepted in `0010-introduce-src-application-services-behind-script-entrypoints.md` | ADR 0002 keeps CLI subprocesses as the orchestration boundary for now, while script-oriented helpers and storage/processors under `src/` already carry reusable behavior. Extracting stable services changes testing, imports, and failure handling. | ADR deciding whether scripts remain the application boundary or whether stable service APIs should be introduced behind the same CLI entry points. |
| P2 | Gold activation rebuild strategy | Accepted in `0011-use-full-table-gold-activation-rebuilds.md` | Activation builders currently run after signal execution and rebuild deterministic activation metadata. Incremental rebuilds, full rebuilds, and partition/date-scoped rebuilds have different correctness and operational recovery trade-offs. | ADR defining full-table versus scoped rebuild policy, required idempotency guarantees, and verification commands. |
| P2 | Signal definition versioning separate from activation identity | Deferred: needs product/audit requirement | ADR 0006 explicitly leaves signal-definition versioning for the future. Adding it would affect catalog frontmatter, MongoDB schema, downstream semantics, and migration policy. | ADR only if DepthMark needs historical signal logic audits, comparisons, or consumer-facing version semantics. |
| P3 | Bronze filesystem retention and DLQ replay policy | Accepted in `0012-bronze-filesystem-retention-and-dlq-replay-policy.md` | Bronze is the only filesystem-backed layer, and DLQ fallback exists under `src/storage/dlq.py`, but retention and replay contracts are not documented as an architectural decision. | ADR defining local/raw payload retention, DLQ replay ownership, and safe cleanup constraints. |

## Recommended Next Session

Start with **P1: FotMob-only provider scope and abstraction boundary**.

Recommended default decision: confirm FotMob-only scope and defer any provider
abstraction until there is a concrete second provider to support.

Decision question to ask:

> Should DepthMark confirm FotMob-only scope and remove or document the
> generic-looking layers under `src/processors`, `src/storage`, and pipeline
> flags such as `--skip-fotmob` as FotMob-specific? My recommendation is confirm
> FotMob-only scope because adding a provider abstraction without a second
> provider to validate against would be speculative and hard to reverse.

Key files to inspect:

- `docs/DEVELOPMENT_ARCHITECTURE.md`
- `src/processors/`
- `src/storage/`
- `scripts/bronze/scrape_fotmob.py`
- `config.yaml`

Suggested verification:

```bash
python scripts/quality/check_logging_style.py
```
