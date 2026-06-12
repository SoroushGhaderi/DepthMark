# Data Engineering Project Review

Date: 2026-05-17
Reviewer: Codex
Project: DepthMark

## Executive Summary

DepthMark has a clear medallion architecture and strong documentation contracts, but there are high-impact production risks that should be addressed before relying on it in a strict production environment. The most urgent issues are broken pipeline orchestration imports, routine use of expensive `OPTIMIZE ... FINAL` in normal load paths, and missing automated tests. Security hardening is also needed in ClickHouse bootstrap behavior and privilege patterns.

## Critical Issues

1. `[scripts/orchestration/pipeline.py:405]` import path does not match real script locations.
   - Evidence: `import scrape_fotmob` at `[scripts/orchestration/pipeline.py:405]`.
   - Evidence: only `scripts/bronze/scrape_fotmob.py` exists.
   - Impact: orchestration can fail at runtime due to `ModuleNotFoundError`.
   - Status update 2026-06-12: resolved by invoking documented layer CLI entry points through subprocesses; see `docs/adr/0002-orchestrate-layer-entrypoints-via-cli.md`.

2. Routine full-table compaction pattern in runtime jobs.
   - Evidence: `[scripts/silver/load_clickhouse.py:108]` runs `OPTIMIZE TABLE ... FINAL DEDUPLICATE`.
   - Evidence: scenario/signal runners also run the same pattern, e.g. `[scripts/gold/scenario/scenario_hollow_dominance.py:57]` and `[scripts/gold/signal/runners/sig_match_discipline_cards_referee_showdown.py:57]`.
   - Impact: high CPU/IO load, long merges, potential cluster instability at scale.
   - Recommended fix: remove `FINAL` from normal flow and move heavy compaction to controlled maintenance windows.

3. No automated test files discovered.
   - Evidence: pytest configured at `[pyproject.toml:132]` and `[pytest.ini:1]`, but repository scan found zero `test_*.py` files.
   - Impact: high regression risk for SQL logic, orchestration behavior, and data contracts.
   - Recommended fix: add baseline tests for orchestrator routing, loader dry-run behavior, and contract checks.

## Warnings

1. ClickHouse bootstrap security fallback is too permissive.
   - Evidence: fallback to `default` user with empty password at `[scripts/clickhouse_setup_common.py:63]`, `[scripts/clickhouse_setup_common.py:90]`.
   - Evidence: broad grants at `[scripts/clickhouse_setup_common.py:152]`.
   - Recommended fix: remove insecure fallback and apply least-privilege role model.

2. SQL interpolation in setup path can be unsafe.
   - Evidence: direct f-string SQL with identifier/password interpolation at `[scripts/clickhouse_setup_common.py:138]` and `[scripts/clickhouse_setup_common.py:149]`.
   - Recommended fix: strict identifier validation/escaping and safer query construction.

3. Exposed database ports and default credentials in compose files.
   - Evidence: `[docker/docker-compose.yml:12]`, `[docker/docker-compose.yml:37]`, `[docker/docker-compose.yml:47]`, `[docker/docker-compose.clickhouse.yml:19]`.
   - Recommended fix: isolate dev defaults from production deployment manifests and enforce secret rotation.

4. Scheduler path is incomplete for production cron reliability.
   - Evidence: cron mount points to non-existent `crontab` file (`[docker/docker-compose.yml:137]`) and cron command is commented (`[docker/docker-compose.yml:153]`).
   - Recommended fix: add concrete schedule artifacts, overlap protection, and runbook.

5. Bronze destructive path lacks dry-run preview.
   - Evidence: `--truncate` at `[scripts/bronze/load_clickhouse.py:1107]` executes truncation logic `[scripts/bronze/load_clickhouse.py:1239]` without dry-run mode.
   - Recommended fix: add `--dry-run` for truncate/reload planning.

6. No explicit TTL policy for warehouse retention.
   - Evidence: no TTL statements found in ClickHouse SQL files.
   - Recommended fix: define retention policy by layer/table category.

## Suggestions

1. Add query-level resource safety controls in DB client.
   - Reference: query execution path at `[src/storage/clickhouse_client.py:221]`.
2. Standardize explicit UTC conversion in transformations.
   - Reference: parsing logic in `[clickhouse/silver/dml/01_match.sql:5]`.

## ClickHouse Schema Findings

Issues found:
- No explicit TTL retention policy in current DDL.
- Runtime strategy depends on expensive post-load optimization.

## SQL Quality Findings

Issues found:
- Frequent `FINAL` usage in silver source reads increases runtime cost.
- Runtime post-load `OPTIMIZE ... FINAL` appears as a systemic pattern.

## CronJob Reliability Findings

Issues found:
- No active, versioned cron schedule file detected in repository root.
- Scheduler service exists but activation/config remains incomplete.

## Security Audit

Issues found:
- Insecure fallback login path for ClickHouse bootstrap.
- Broad grant model (`GRANT ALL`) in setup flow.
- Dev-like compose secrets/defaults in tracked compose files.

## Test Coverage Gaps

Issues found:
- No tests discovered while pytest is configured.

## Documentation Gaps

No issues found.

## CI/CD Assessment

Issues found:
- No CI workflow files detected (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci` absent).

## Performance Hotspots

Issues found:
- Routine `OPTIMIZE TABLE ... FINAL DEDUPLICATE` usage in loaders/runners.
- Heavy `FINAL` usage in source reads can amplify latency and merge pressure.

## Prioritized Action Plan

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Fix orchestrator import/call wiring to canonical entry points | Small | High |
| P0 | Remove routine `OPTIMIZE ... FINAL` from normal runtime jobs | Medium | High |
| P0 | Add baseline automated tests and ensure pytest discovery | Medium | High |
| P1 | Harden ClickHouse bootstrap auth path and remove default empty-password fallback | Medium | High |
| P1 | Replace broad grants with least-privilege role model | Medium | High |
| P1 | Harden SQL interpolation in setup paths | Small | High |
| P2 | Define and apply TTL retention policy | Medium | Medium |
| P2 | Add dry-run safety for truncate/reload path | Small | Medium |
| P2 | Finalize cron schedule artifacts with overlap protection | Medium | Medium |
| P3 | Add per-query execution/memory limits in client paths | Small | Medium |
| P3 | Standardize explicit timezone handling in critical SQL | Small | Medium |
