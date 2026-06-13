# Data Engineering Review Remediation Plan

Date: 2026-05-17
Scope: Follow-up plan for the DE audit findings across security, reliability, ClickHouse operations, and test readiness.

## Goal

Resolve the highest-risk issues first (P0/P1), then close medium-risk improvements (P2/P3) without breaking existing script contracts or medallion boundaries.

## Baseline Findings Summary

### P0 (Fix now)

1. Orchestrator module import/entrypoint wiring is inconsistent with actual script layout.
2. `OPTIMIZE TABLE ... FINAL DEDUPLICATE` is executed in routine load paths and scenario/signal runners.
3. No test files currently exist despite pytest configuration.

### P1 (This sprint)

1. ClickHouse bootstrap path allows fallback to `default` user with empty password and broad grants.
2. Unsafe SQL string composition exists in setup paths.

### P2 (This quarter)

1. No explicit TTL retention policy for high-volume warehouse tables.
2. Bronze `--truncate` path has no dry-run preview.
3. Scheduler/cron path is incomplete for overlap-safe production execution.

### P3 (Nice to have)

1. Add query-level resource limits (`max_execution_time`, `max_memory_usage`) in ClickHouse execution paths.
2. Make timezone normalization explicit in key transformations.

## Execution Plan

## Phase 1 - P0 Stabilization

1. Fix orchestration imports/calls to canonical `scripts/*` entry points.
   - Status: Resolved by ADR 0002 (subprocess CLI orchestration).
2. Remove/relocate routine `OPTIMIZE ... FINAL` from normal load flow.
   - Status: Legacy per-output runners removed by ADR 0009; generic runner still applies pattern.
3. Create initial automated tests:
   - Orchestrator smoke path (argument and routing behavior)
   - SQL loader behavior tests (dry-run + execution selection)
   - Contract-check invocation tests

Definition of done:
- Pipeline entrypoint runs without import failures.
- Normal runtime no longer runs full-part `FINAL` optimization loops.
- CI-local `pytest` discovers and runs baseline tests.

## Phase 2 - P1 Hardening

1. Remove insecure default-user fallback from ClickHouse setup flow.
2. Tighten role/grant model to least privilege by layer responsibilities.
3. Sanitize/validate SQL identifier interpolation in setup helpers.

Definition of done:
- Setup scripts fail closed on invalid/unsafe user config.
- No broad `GRANT ALL` pattern remains where avoidable.
- Security-sensitive setup paths are covered by tests.

## Phase 3 - P2 Operational Improvements

1. Introduce table retention/TTL policy by layer and table class.
2. Add `--dry-run` safety path for bronze truncate/reload operations.
3. Finalize scheduler runbook with overlap protection (lock strategy).

Definition of done:
- TTL strategy documented and applied to target tables.
- Destructive paths have preview mode.
- Scheduler mode has explicit locking and runbook documentation.

## Phase 4 - P3 Quality Upgrades

1. Add optional query-level resource guardrails in client wrapper.
2. Standardize explicit timezone handling in critical silver/gold SQL.

## Work Tracking Checklist

- [x] P0.1 Fix orchestration import/call wiring (resolved by ADR 0002)
- [ ] P0.2 Remove routine `OPTIMIZE ... FINAL` from runtime jobs
- [ ] P0.3 Add baseline test suite and validate discovery
- [ ] P1.1 Remove insecure ClickHouse default-user fallback
- [ ] P1.2 Refactor grants toward least privilege
- [ ] P1.3 Harden SQL composition in setup code
- [x] P2.1 Define/apply TTL policies (documented as manual-only retention by ADR 0012)
- [ ] P2.2 Add dry-run for truncate path
- [ ] P2.3 Add scheduler overlap protection + docs
- [ ] P3.1 Add query resource controls
- [ ] P3.2 Enforce explicit timezone conversions

## Notes For Next Iterations

1. Follow `docs/SCRIPTS_CONTRACT.md` for CLI compatibility and dry-run behavior.
2. Keep changes incremental and verifiable by targeted checks first.
3. Prioritize P0 then P1 before broad refactors.
