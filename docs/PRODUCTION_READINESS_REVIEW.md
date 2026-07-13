# Production Readiness Review

Date: 2026-07-07
Reviewer: Codex
Project: DepthMark
Last updated: 2026-07-11

## Executive Summary

DepthMark has a clear medallion architecture with isolated FotMob and Oddspedia source domains, and the codebase is well documented. This review's findings primarily concern the FotMob warehouse pipeline; Oddspedia now has its own source-specific ingestion and resolution workflow under ADR 0021. The previous ClickHouse setup-time `OPTIMIZE ... FINAL DEDUPLICATE` risk is fixed by ADR 0020 and the explicit maintenance command. The remaining highest-impact issues are the unified pipeline continuing after upstream failures and the test suite failing to collect from the repo root because the package paths are not on `PYTHONPATH` during pytest discovery. ClickHouse bootstrap also remains more permissive than ideal for a production posture, especially around local default-user fallback and broad grants.

## Findings

### P0 (Fix now)

1. **Routine full-table compaction in setup flow** — normal setup previously selected `99_optimize_tables.sql` and ran full-table `OPTIMIZE TABLE ... FINAL DEDUPLICATE` across Bronze, causing setup to rewrite populated tables and clear physical-version diagnostics.
   - Status: **Fixed in ADR 0020**. Setup discovery now excludes `optimize` SQL files, and the legacy Bronze optimization SQL file was removed.

### P1 (This sprint)

2. **Unified pipeline keeps going after upstream failures** — the orchestrator previously allowed Bronze, ClickHouse load, Silver, and Gold steps to continue after upstream failures, which meant a Bronze failure could still be followed by Silver/Gold work against stale or incomplete inputs.
   - Status: **Fixed**. The unified pipeline now gates downstream stages on upstream success in daily, monthly, and full-history modes, with regression coverage for Bronze, Silver, and full-history ClickHouse failures.

3. **ClickHouse bootstrap is still overly permissive** — `scripts/clickhouse_setup_common.py:87-205` falls back to the `default` user in local development, and `scripts/clickhouse_setup_common.py:208-241` grants broad access (`GRANT ALL` on Bronze/Silver/Gold databases plus `CREATE DATABASE` and `TABLE ENGINE`) once a user is created. The local-dev gate helps, but the permission model is still much wider than least-privilege production practice.
   - Status: **Open**.

4. **Bronze truncate path has no preview mode** — `scripts/bronze/load_clickhouse.py` exposes `--truncate`, and the destructive reload path previously had no dry-run branch. That made reload rehearsal harder even though the docs encourage previewing destructive actions first.
   - Status: **Fixed**. Bronze ClickHouse loading now supports `--dry-run`, including `--truncate --dry-run`, and skips truncation, loading, ClickHouse connection setup, and Telegram notification in preview mode.

5. **Pytest discovery is broken from the repo root** — `pytest.ini:1-16` configures pytest but does not add the project root to `PYTHONPATH`, while the test files import `src...` and `scripts...` modules directly. A baseline `pytest -q tests/unit` run currently fails during collection with `ModuleNotFoundError` for both package roots.
   - Status: **Open**.

### P2 (This quarter)

6. **`SELECT *` still appears in production Gold SQL** — `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_half_time_talk_fail.sql:104-130` uses `SELECT * FROM (...)` in a scheduled Gold query, and the same pattern exists in other Gold SQL and helper code such as `src/warehouse/quality.py:381-384`. This is readable in small cases, but it makes column intent opaque and can turn into a wide scan / maintenance problem as queries grow.
   - Status: **Open**.

### P3 (Nice to have)

7. **No CI workflow files detected** — the repository still has no visible GitHub Actions, GitLab CI, Jenkins, or CircleCI config. That leaves linting, tests, and schema validation dependent on manual execution.
   - Status: **Open**.

8. **No scheduler lockfile or overlap guard visible in the repo** — I did not find a cron or lock wrapper for long-running pipeline jobs. The codebase has good dry-run support, but I would still expect a lock strategy to be documented or embedded for any external scheduler.
   - Status: **Open**.

## Security Audit

- Default-user ClickHouse bootstrap is still present in the local-dev path.
- Grant scope is broad for new ClickHouse users.
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
- A plain `pytest -q tests/unit` run currently fails collection because `src` and `scripts` are not importable from the test environment without extra path setup.

## Remediation Plan

### Phase 1 - P0 Stabilization

1. Keep routine `OPTIMIZE ... FINAL` out of setup; use `scripts/maintenance/optimize_clickhouse.py` only as an explicit operator maintenance command.
2. Fix pytest discovery so the root package layout is importable without ad hoc environment setup.
3. Add a regression test for the unified orchestrator's failure behavior so upstream errors stop downstream writes by default.

### Phase 2 - P1 Hardening

1. Tighten ClickHouse bootstrap grants toward least privilege.
2. Add a dry-run branch for Bronze truncate/reload operations.
3. Decide whether the unified pipeline should fail fast or document its partial-success semantics very explicitly.

### Phase 3 - P2 Operational Improvements

1. Replace remaining production `SELECT *` usage with explicit column projections.
2. Add SQL logic tests and schema migration idempotency tests.
3. Introduce a documented lock strategy for any external scheduler or cron wrapper.

### Phase 4 - P3 Quality Upgrades

1. Add CI for lint, unit tests, and SQL validation.
2. Add query-level resource guardrails where the warehouse routinely scans large tables.

## Work Tracking

- [x] P0.1 Remove routine `OPTIMIZE ... FINAL` from runtime setup
- [ ] P0.2 Repair pytest collection/import path configuration
- [x] P0.3 Make orchestrator failure handling explicit and safe
- [ ] P1.1 Remove insecure ClickHouse default-user fallback where possible
- [ ] P1.2 Refactor grants toward least privilege
- [x] P1.3 Add dry-run for Bronze truncate path
- [ ] P2.1 Replace remaining production `SELECT *` usage
- [ ] P2.2 Add SQL logic and migration tests
- [ ] P2.3 Add scheduler overlap protection docs or a lock wrapper
- [ ] P3.1 Add CI workflow coverage
- [ ] P3.2 Add query resource controls

## Notes

1. Follow `docs/SCRIPTS_CONTRACT.md` for CLI compatibility and dry-run behavior.
2. Keep changes incremental and verify the narrowest failure mode first.
3. When the next round of changes lands, re-run the test collection check before expanding coverage work.
