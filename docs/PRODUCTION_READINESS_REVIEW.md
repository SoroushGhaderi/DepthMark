# Production Readiness Review

Date: 2026-05-17
Reviewer: Codex
Project: DepthMark
Last updated: 2026-06-13

## Executive Summary

DepthMark has a clear medallion architecture and strong documentation contracts, but there are high-impact production risks that should be addressed before relying on it in a strict production environment. The most urgent issues are broken pipeline orchestration imports, routine use of expensive `OPTIMIZE ... FINAL` in normal load paths, and missing automated tests. Security hardening is also needed in ClickHouse bootstrap behavior and privilege patterns.

## Findings

### P0 (Fix now)

1. **Orchestrator import wiring** — `import scrape_fotmob` at `scripts/orchestration/pipeline.py:405` did not match actual script locations.
   - Status: **Resolved** by ADR 0002 (subprocess CLI orchestration).

2. **Routine full-table compaction** — `OPTIMIZE TABLE ... FINAL DEDUPLICATE` in normal load paths causes high CPU/IO load and merge pressure.
   - Status: Legacy per-output runners removed by ADR 0009; generic runner still applies pattern.

3. **No automated tests** — pytest configured but zero `test_*.py` files found.
   - Status: **Open**.

### P1 (This sprint)

4. **ClickHouse bootstrap security** — Fallback to `default` user with empty password and broad `GRANT ALL`.
   - Status: **Open**.

5. **Unsafe SQL interpolation** — f-string SQL with identifier/password interpolation in setup paths.
   - Status: **Open**.

### P2 (This quarter)

6. **No TTL retention policy** — No explicit retention in ClickHouse DDL.
   - Status: **Resolved** by ADR 0012 (manual-only retention, operator decides).

7. **Bronze `--truncate` lacks dry-run** — Destructive path has no preview mode.
   - Status: **Open**.

8. **Scheduler/cron incomplete** — Cron mount points to non-existent `crontab` file.
   - Status: **Open**.

### P3 (Nice to have)

9. **No per-query resource limits** — No `max_execution_time` or `max_memory_usage` guards.
   - Status: **Open**.

10. **Timezone handling** — No explicit UTC conversion in key transformations.
    - Status: **Open**.

## Security Audit

- Insecure fallback login path for ClickHouse bootstrap.
- Broad grant model (`GRANT ALL`) in setup flow.
- Dev-like compose secrets/defaults in tracked compose files.

## SQL Quality

- Frequent `FINAL` usage in silver source reads increases runtime cost.
- Runtime post-load `OPTIMIZE ... FINAL` appears as a systemic pattern.

## CI/CD

- No CI workflow files detected (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci` absent).

## Test Coverage

- No tests discovered while pytest is configured.

## Remediation Plan

### Phase 1 — P0 Stabilization

1. ~~Fix orchestration imports/calls to canonical `scripts/*` entry points.~~ (ADR 0002)
2. Remove/relocate routine `OPTIMIZE ... FINAL` from normal load flow.
3. Create initial automated tests:
   - Orchestrator smoke path (argument and routing behavior)
   - SQL loader behavior tests (dry-run + execution selection)
   - Contract-check invocation tests

### Phase 2 — P1 Hardening

1. Remove insecure default-user fallback from ClickHouse setup flow.
2. Tighten role/grant model to least privilege by layer responsibilities.
3. Sanitize/validate SQL identifier interpolation in setup helpers.

### Phase 3 — P2 Operational Improvements

1. ~~Define and apply TTL retention policy.~~ (ADR 0012 — manual-only retention)
2. Add `--dry-run` safety path for bronze truncate/reload operations.
3. Finalize scheduler runbook with overlap protection (lock strategy).

### Phase 4 — P3 Quality Upgrades

1. Add optional query-level resource guardrails in client wrapper.
2. Standardize explicit timezone handling in critical silver/gold SQL.

## Work Tracking

- [x] P0.1 Fix orchestration import/call wiring (ADR 0002)
- [ ] P0.2 Remove routine `OPTIMIZE ... FINAL` from runtime jobs
- [ ] P0.3 Add baseline test suite and validate discovery
- [ ] P1.1 Remove insecure ClickHouse default-user fallback
- [ ] P1.2 Refactor grants toward least privilege
- [ ] P1.3 Harden SQL composition in setup code
- [x] P2.1 Define/apply TTL policies (ADR 0012 — manual-only retention)
- [ ] P2.2 Add dry-run for truncate path
- [ ] P2.3 Add scheduler overlap protection + docs
- [ ] P3.1 Add query resource controls
- [ ] P3.2 Enforce explicit timezone conversions

## Notes

1. Follow `docs/SCRIPTS_CONTRACT.md` for CLI compatibility and dry-run behavior.
2. Keep changes incremental and verifiable by targeted checks first.
3. Prioritize P0 then P1 before broad refactors.
