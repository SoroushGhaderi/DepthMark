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
  ADR-worthy`, or` Deferred: reason`.

## Accepted Decisions

These decisions are already accepted. Keep them here only as orientation for
future sessions; do not re-open them unless new codebase evidence changes the
trade-off.


| ADR                                                                    | Decision                                                                                                                           | Follow-up constraint                                                                                                                                                                      |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0001-use-generic-gold-sql-runners.md`                                 | Gold signal and scenario SQL jobs are executed through generic runners, not new handwritten per-output Python wrappers.            | Legacy per-signal and per-scenario runners may remain only as migration debt.                                                                                                             |
| `0002-orchestrate-layer-entrypoints-via-cli.md`                        | Pipeline orchestration calls canonical script entry points through CLI subprocesses.                                               | Any command-surface change must update the orchestrator and docs together.                                                                                                                |
| `0003-split-gold-clickhouse-namespaces.md`                             | Gold outputs are split across `gold_scenarios.*`, `gold_signals.*`, and shared `gold.*` metadata.                                  | Docs, SQL, catalogs, and drop/backfill commands must name the specific namespace.                                                                                                         |
| `0004-keep-gold-scenario-bulk-disabled-until-validated.md`             | Scenario bulk loading is re-enabled. Scenarios follow the same failure pattern as signals.                                         | Operators can use `--part scenarios` to run scenarios only, or `--part all` for everything.                                                                                               |
| `0005-local-dev-credentials-vs-production-policy.md`                   | Tracked Docker Compose credentials are local-development defaults, not production policy.                                          | Production-like setup must use non-placeholder credentials and `DEPTHMARK_ENV=production`.                                                                                                |
| `0006-version-signal-activation-identity-scheme.md`                    | `signal_id_version` versions the activation identity scheme, not signal football logic.                                            | Changing `row_identity` is an activation identity migration concern.                                                                                                                      |
| `0007-sql-owns-analytical-transformations.md`                          | Silver and Gold analytical logic belongs in ClickHouse SQL; Python owns orchestration and validation.                              | Python exceptions for reusable analytical logic need a later ADR.                                                                                                                         |
| `0008-author-signal-catalogs-in-markdown.md`                           | Signal markdown frontmatter is the source of truth; MongoDB is a synchronized serving copy.                                        | Catalog changes originate in Git and must sync to MongoDB through the catalog sync script.                                                                                                |
| `0009-retire-legacy-gold-per-output-runners.md`                        | Legacy Gold per-output Python runner files are removed; `scripts/gold/run_gold_sql_jobs.py` is the only supported selected-job runner.   | Omitted selectors mean all, while signal `--entity` and `--family` are separate batch selectors.                                                                                          |
| `0010-introduce-src-application-services-behind-script-entrypoints.md` | Stable, layer-specific application services may live under `src/` behind existing script entry points.                             | Scripts keep CLI compatibility and exit-code semantics; services coordinate workflows but not Silver/Gold analytical logic. Bronze service extraction is a follow-up implementation task. |
| `0011-use-full-table-gold-activation-rebuilds.md`                      | Gold activation metadata originally used full-table rebuilds. ADR 0018 supersedes this for scoped runs.                              | Full-table activation replacement is now limited to explicit full-history runs.                                                                                                           |
| `0018-use-scope-aware-warehouse-replacement.md`                       | Silver, Gold outputs, and activations replace only their explicit date/month scope; full-history is explicit.                        | Jobs may read wider historical context, but replacement follows match-date lineage and scoped activations remain synchronized.                                                            |
| `0019-separate-logical-duplicates-from-physical-versions.md`          | Strict quality checks use logical `FINAL` duplicates; raw physical versions are non-failing diagnostics.                            | Merge timing must not change strict outcomes; physical version accumulation remains visible for operational follow-up.                                                                     |
| `0012-bronze-filesystem-retention-and-dlq-replay-policy.md`            | Bronze filesystem files and DLQ files are retained indefinitely. Cleanup is operator-initiated and manual.                         | Operators must query ClickHouse before deleting Bronze files. No load-confirmation markers.                                                                                               |
| `0013-fotmob-only-provider-scope.md`                                   | DepthMark is FotMob-only. No provider abstraction boundary exists or will be added until a concrete second provider needs support. | A second provider abstraction must be introduced alongside a concrete second provider.                                                                                                    |
| `0014-use-single-enriched-signal-activation-serving-table.md`          | Gold activations use one enriched serving table, not a thin index plus separate match aggregate.                                   | `gold_signals.sig_*` tables expose `signal_instance_id`; downstream services read details from `gold.signal_activations` before reaching for typed source tables.                         |
| `0015-redesign-telegram-notification-module.md`                       | Telegram module redesigned: thin transport, Jinja2 templates, dataclasses, single config source, clean break from old modules.    | New `src/services/telegram/` package replaces `metrics_alerts.py`, `alerting.py`, `layer_completion_alerts.py`. Callers must migrate.                                                       |
| `0017-split-fotmob-bronze-live-and-historical-storage.md`             | FotMob Bronze filesystem storage is split into independently owned Live and Historical aspects.                                  | Only `--today` writes Live data; completed-date selectors write Historical data, and Live payloads are never promoted automatically.                                                       |


## Queue


| Priority | Topic                                                             | Current status                                                                                             | Why this is ADR-worthy                                                                                                                                                                                                                                                                                      | Expected output                                                                                                                                    |
| -------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0       | Retire legacy Gold per-output Python runners                      | Accepted in `0009-retire-legacy-gold-per-output-runners.md`                                                | `scripts/gold/signal/runners/` contained hundreds of generated wrapper files and `scripts/gold/scenario/` contained legacy scenario wrappers, while ADR 0001 says new Gold work should use generic SQL runners. Keeping or deleting them affects command compatibility, review surface, and repo structure. | ADR deciding deprecation/removal policy, compatibility window, and docs updates.                                                                   |
| P0       | Re-enable or permanently keep disabled Gold scenario bulk loading | Accepted as disabled in `0004-keep-gold-scenario-bulk-disabled-until-validated.md`; re-enabled in same ADR | The Gold loader currently runs signals and activation builders, but scenario jobs are deliberately omitted. Re-enabling affects default Gold runs, failure blast radius, backfills, and runbook expectations.                                                                                               | ADR update or new ADR after representative scenario validation, plus loader/docs changes if accepted.                                              |
| P1       | FotMob-only provider scope and abstraction boundary               | Accepted in `0013-fotmob-only-provider-scope.md`                                                           | The repo is FotMob-only by docs and naming, but there are generic-looking layers under `src/processors`, `src/storage`, and pipeline flags such as `--skip-fotmob`. A provider abstraction would be hard to reverse once introduced.                                                                        | ADR confirming FotMob-only scope and the minimum evidence required before adding another provider abstraction.                                     |
| P1       | `src/` application-service boundary behind script entry points    | Accepted in `0010-introduce-src-application-services-behind-script-entrypoints.md`                         | ADR 0002 keeps CLI subprocesses as the orchestration boundary for now, while script-oriented helpers and storage/processors under `src/` already carry reusable behavior. Extracting stable services changes testing, imports, and failure handling.                                                        | ADR deciding whether scripts remain the application boundary or whether stable service APIs should be introduced behind the same CLI entry points. |
| P2       | Gold activation rebuild strategy                                  | Superseded by `0018-use-scope-aware-warehouse-replacement.md`                                              | Activation builders originally ran after signal execution and rebuilt all deterministic activation metadata. Scoped upstream replacement now provides the required correctness contract.                                                                 | ADR 0018 defines scoped versus full-history replacement, idempotency guarantees, and context boundaries.                                           |
| P2       | Signal definition versioning separate from activation identity    | Deferred: needs product/audit requirement                                                                  | ADR 0006 explicitly leaves signal-definition versioning for the future. Adding it would affect catalog frontmatter, MongoDB schema, downstream semantics, and migration policy.                                                                                                                             | ADR only if DepthMark needs historical signal logic audits, comparisons, or consumer-facing version semantics.                                     |
| P3       | Bronze filesystem retention and DLQ replay policy                 | Accepted in `0012-bronze-filesystem-retention-and-dlq-replay-policy.md`                                    | Bronze is the only filesystem-backed layer, and DLQ fallback exists under `src/storage/dlq.py`, but retention and replay contracts are not documented as an architectural decision.                                                                                                                         | ADR defining local/raw payload retention, DLQ replay ownership, and safe cleanup constraints.                                                      |


## Recommended Next Session

- **P2: Signal definition versioning** — Deferred: needs product/audit requirement

## Completed Sessions


| Session | Item                                | Outcome                                                              |
| ------- | ----------------------------------- | -------------------------------------------------------------------- |
| 1       | FotMob-only provider scope          | Accepted in `0013-fotmob-only-provider-scope.md`                     |
| 2       | `src/` application-service boundary | Accepted in `0010`; BronzeService extraction confirmed as follow-up  |
| 3       | Gold scenario bulk loading          | Re-enabled in `0004`; 48 scenarios + 344 signals in default Gold run |
| 4       | Telegram module redesign            | Accepted in `0015-redesign-telegram-notification-module.md`          |
| 5       | Unify configuration systems         | Accepted in `0016-unify-configuration-systems.md`                    |
| 6       | Split FotMob Live/Historical Bronze | Accepted in `0017-split-fotmob-bronze-live-and-historical-storage.md` |
| 7       | Logical duplicates vs physical versions | Accepted in `0019-separate-logical-duplicates-from-physical-versions.md` |
