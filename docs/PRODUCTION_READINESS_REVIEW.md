# Production Readiness Review

Date: 2026-08-08
Reviewer: Codex
Project: DepthMark
Last updated: 2026-08-08

## Executive Summary

DepthMark has two parallel source medallion paths with isolated FotMob and Oddspedia contracts, and the codebase is well documented. This review's implementation findings primarily concern the currently deployed FotMob warehouse path; Oddspedia currently has source-specific Bronze ingestion and Silver resolution, while its additional Silver entities and Gold outputs remain follow-up work under ADR 0023. The previous ClickHouse setup-time `OPTIMIZE ... FINAL DEDUPLICATE` risk is fixed by ADR 0020 and the explicit maintenance command. The remaining open findings are now limited to the explicitly deferred P2/P3 quality work. Root test collection passes, upstream pipeline failures gate downstream work, and ClickHouse bootstrap grants are bounded by database and runtime operation. Local default-user bootstrap remains available only for the explicit local-development environment.

## Oddspedia P0/P1 Hardening Update

The Oddspedia reliability work completed on 2026-08-08 closes the identified
P0/P1 risks in the source intake and Bronze-to-Silver boundary. The controls
are intentionally fail-closed: a failed or ambiguous upstream phase cannot be
presented as a complete date.

| Risk | Implemented control |
| --- | --- |
| Partial or stale discovery evidence | Complete pagination and target-date validation are required; verified empty dates use `no_events`; accepted inventories carry checksums; legacy or stale evidence is refreshed before admission. |
| Incorrect or incomplete rendered payloads | Event ID, date, team, market-schema, and terminal scrape audits run before payload acceptance and again before a completed scrape is recorded. |
| Concurrent workers hiding failures | Failed worker outcomes, driver-init failures, and incomplete futures are persisted in the manifest and remain retryable. |
| Cross-process date races | Mutating Oddspedia date commands serialize through `data/oddspedia/locks/`; UTC is used for operational timestamps and date boundaries; month commands exit non-zero when any date fails. |
| Partial ClickHouse Bronze loads | `load_bronze.py` stages all three source fact tables, validates counts, replaces the target partition, and records `staging`, `published`, or `failed` in `oddspedia_bronze.load_status`. Resolution reads only `published` batches. |
| Unsafe cross-source reference assumptions | Priority and resolution machine-verify exact FotMob Bronze/Silver fixture-ID sets for the previous/current/following date window. |

The full repository test suite passes (`227 passed`); logging-style and Python
compilation checks also pass. Browser executable paths can be supplied through
`ODDSPEDIA_CHROME_BIN` and `ODDSPEDIA_CHROMEDRIVER_PATH` when platform
auto-detection is insufficient. The remaining open findings below are P2/P3
quality improvements, not unaddressed Oddspedia P0/P1 blockers.

## Findings

### P0 (Fix now)

1. **Routine full-table compaction in setup flow** — normal setup previously selected `99_optimize_tables.sql` and ran full-table `OPTIMIZE TABLE ... FINAL DEDUPLICATE` across Bronze, causing setup to rewrite populated tables and clear physical-version diagnostics.
   - Status: **Fixed in ADR 0020**. Setup discovery now excludes `optimize` SQL files, and the legacy Bronze optimization SQL file was removed.

### P1 (This sprint)

2. **Unified pipeline keeps going after upstream failures** — the orchestrator previously allowed Bronze, ClickHouse load, Silver, and Gold steps to continue after upstream failures, which meant a Bronze failure could still be followed by Silver/Gold work against stale or incomplete inputs.
   - Status: **Fixed**. The unified pipeline now gates downstream stages on upstream success in daily, monthly, and full-history modes, with regression coverage for Bronze, Silver, and full-history ClickHouse failures.

3. **ClickHouse bootstrap was overly permissive** — the previous setup path fell back to the `default` user in local development and granted broad access (`GRANT ALL` on Bronze/Silver/Gold databases plus `CREATE DATABASE` and `TABLE ENGINE`) once a user was created.
   - Status: **Fixed**. Runtime users receive explicit per-database SELECT/INSERT/ALTER/schema-operation grants; `CREATE DATABASE` and table-engine bootstrap privileges are local-development-only.

4. **Bronze truncate path has no preview mode** — `scripts/bronze/load_clickhouse.py` exposes `--truncate`, and the destructive reload path previously had no dry-run branch. That made reload rehearsal harder even though the docs encourage previewing destructive actions first.
   - Status: **Fixed**. Bronze ClickHouse loading now supports `--dry-run`, including `--truncate --dry-run`, and skips truncation, loading, ClickHouse connection setup, and Telegram notification in preview mode.

5. **Pytest discovery is broken from the repo root** — `pytest.ini:1-16` configures pytest but does not add the project root to `PYTHONPATH`, while the test files import `src...` and `scripts...` modules directly. A baseline `pytest -q tests/unit` run currently fails during collection with `ModuleNotFoundError` for both package roots.
   - Status: **Fixed**. Root `pytest -q` now collects and passes the repository test suite.

### P2 (This quarter)

6. **`SELECT *` still appears in production Gold SQL** — `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_half_time_talk_fail.sql:104-130` uses `SELECT * FROM (...)` in a scheduled Gold query, and the same pattern exists in other Gold SQL and helper code such as `src/warehouse/quality.py:381-384`. This is readable in small cases, but it makes column intent opaque and can turn into a wide scan / maintenance problem as queries grow.
   - Status: **Open**.

### P3 (Nice to have)

7. **No CI workflow files detected** — the repository still has no visible GitHub Actions, GitLab CI, Jenkins, or CircleCI config. That leaves linting, tests, and schema validation dependent on manual execution.
   - Status: **Open**.

8. **No scheduler lockfile or overlap guard visible in the repo** — the optional cron container still needs a deployment-specific schedule, but source commands now use a cross-process sport/date lock and document the external scheduler contract.
   - Status: **Mitigated**. Scheduler overlap is protected by `data/oddspedia/locks/`; choosing and deploying a cron schedule remains an operator concern.

## Security Audit

- Default-user ClickHouse bootstrap is restricted to the explicit local-dev path.
- New ClickHouse users receive database-scoped grants for the warehouse runtime;
  schema-bootstrap privileges are not granted in production.
- `.env`-style secrets are documented, but production hardening still depends on external discipline rather than runtime enforcement.

## SQL Quality

- Routine `OPTIMIZE TABLE ... FINAL DEDUPLICATE` is no longer part of the normal setup path.
- `SELECT *` remains in some production Gold queries and in the data-quality helper.
- Silver and Gold use explicit `ReplacingMergeTree` / partitioning patterns, which is a solid base.

## CI/CD

- No CI workflow files are present in the repository scan.
- No automated schema migration pipeline was found.
- Local verification still depends on running scripts manually.

## Test Coverage

- There are unit tests under `tests/unit/`, but no SQL logic tests or migration-idempotency tests were found in the repo scan.
- A plain `pytest -q` run collects and passes the repository test suite.

## Remediation Plan

### Phase 1 - P0 Stabilization

1. Keep routine `OPTIMIZE ... FINAL` out of setup; use `scripts/maintenance/optimize_clickhouse.py` only as an explicit operator maintenance command.
2. Fix pytest discovery so the root package layout is importable without ad hoc environment setup. **Done.**
3. Add a regression test for the unified orchestrator's failure behavior so upstream errors stop downstream writes by default.
   **Done.** Downstream stages stop after failed upstream stages in daily,
   monthly, and full-history modes.

### Phase 2 - P1 Hardening

1. Tighten ClickHouse bootstrap grants toward least privilege. **Done.**
2. Add a dry-run branch for Bronze truncate/reload operations. **Done.**
3. Decide whether the unified pipeline should fail fast or document its partial-success semantics very explicitly.
   **Done.** The pipeline fails closed after upstream errors, and the
   date-scoped Oddspedia commands document their independent-date/month exit
   semantics.

### Phase 3 - P2 Operational Improvements

1. Replace remaining production `SELECT *` usage with explicit column projections.
2. Add SQL logic tests and schema migration idempotency tests.
3. Introduce a documented lock strategy for any external scheduler or cron wrapper. **Done for Oddspedia date operations.** External scheduler selection remains deployment-specific.

### Phase 4 - P3 Quality Upgrades

1. Add CI for lint, unit tests, and SQL validation.
2. Add query-level resource guardrails where the warehouse routinely scans large tables.

## Work Tracking

- [x] P0.1 Remove routine `OPTIMIZE ... FINAL` from runtime setup
- [x] P0.2 Repair pytest collection/import path configuration
- [x] P0.3 Make orchestrator failure handling explicit and safe
- [x] P1.1 Restrict ClickHouse default-user fallback to local development
- [x] P1.2 Refactor grants toward least privilege
- [x] P1.3 Add dry-run for Bronze truncate path
- [ ] P2.1 Replace remaining production `SELECT *` usage
- [ ] P2.2 Add SQL logic and migration tests
- [x] P2.3 Add scheduler overlap protection docs or a lock wrapper
- [ ] P3.1 Add CI workflow coverage
- [ ] P3.2 Add query resource controls

## Notes

1. Follow `docs/SCRIPTS_CONTRACT.md` for CLI compatibility and dry-run behavior.
2. Keep changes incremental and verify the narrowest failure mode first.
3. When the next round of changes lands, re-run the test collection check before expanding coverage work.
