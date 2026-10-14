# DepthMark Agent Guide

Use this guide when working inside the `depthmark` project. Keep changes aligned with its source-isolated football warehouse and prefer small, explicit edits over broad rewrites.

## Location And Scope

This file belongs at the DepthMark project root because its instructions apply to the whole `depthmark` tree. Add a more specific `AGENTS.md` only inside a subdirectory that needs different rules.

Do not use this file as a Codex skill. Skills are reusable procedures with their own `SKILL.md` files, useful for repeated workflows across projects. This file is project context: architecture, commands, conventions, and safety rules for this repo.

## Project Overview

DepthMark is a Python football data warehouse with two explicit source domains.
FotMob and Oddspedia each have an independent Bronze → Silver → Gold medallion
pipeline. Their raw contracts remain isolated; cross-source matching is an
explicit integration relationship between source-specific Silver outputs.

- FotMob Bronze: completed-date payloads under `data/fotmob/historical/`,
  current-date snapshots under `data/fotmob/live/`, and raw ClickHouse tables
  in `bronze.*` sourced only from Historical storage.
- FotMob Silver and Gold: cleaned analytical tables in `silver.*`, plus
  scenarios/signals in `gold_scenarios.*`, `gold_signals.*`, and shared metadata
  in `gold.*`.
- Oddspedia Bronze: artifacts under `data/oddspedia/` and source facts in
  `oddspedia_bronze.*`.
- Oddspedia Silver and Gold: source-specific conformed odds/event entities and
  odds-derived product outputs. Existing `silver.oddspedia_match_resolution`
  is the current cross-source relationship table, not the whole Oddspedia
  medallion path.
- MongoDB stores content/catalog metadata, including signal catalog entries authored from markdown frontmatter.
- Oddspedia artifacts live under `data/oddspedia/historical/`, structured source
  facts live in `oddspedia_bronze.*`, and `silver.oddspedia_match_resolution`
  links an Oddspedia event to at most one canonical FotMob fixture.

Do not introduce a generic provider framework. FotMob and Oddspedia remain
explicit source domains with isolated raw contracts; `silver.match` remains the
canonical FotMob fixture reference used by the cross-source resolution edge.

## Important References

- `README.md`: project overview and documentation index.
- `docs/README.md`: documentation map.
- `docs/DEVELOPMENT_ARCHITECTURE.md`: architecture, canonical entry points, and runbook.
- `docs/data-flow/infrastructure.md`: Docker setup, quick start, and environment configuration.
- `docs/SCRIPTS_CONTRACT.md`: authoritative rules for scripts, script-oriented helpers, and application services behind script entry points.
- `scripts/README.md`: script layout and command surface.
- `clickhouse/gold/dml/signals/README.md` and `catalogs/signals/README.md`: signal SQL/catalog guidance.

If these files conflict with code, resolve the mismatch intentionally and mention it in the change summary.

## Environment And Secrets

- Never commit `.env`, credentials, tokens, generated data, logs, or local warehouse artifacts.
- Use `.env.example` for documenting required configuration.
- Required local services come from the root `docker-compose.yml`.
- `scripts/bootstrap.sh` initializes a server end to end (generated `.env`
  secrets, stack, setup, MongoDB, schedule); use `scripts/bootstrap.sh --local`
  for local development. Never hard-code secrets or require hand-edited
  commands; new setup steps belong in the bootstrap (ADR 0030).

## Canonical Commands

Run commands from the `depthmark` directory.

```bash
scripts/bootstrap.sh --local
scripts/install_schedule.sh
python scripts/orchestration/run_scheduled_job.py fotmob-daily --dry-run
python scripts/orchestration/setup_fotmob_warehouse.py
python scripts/maintenance/recreate_clickhouse_tables.py --drifted
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/bronze/scrape_fotmob.py 20251208
python scripts/report_scraping.py --date 20251208
python scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python scripts/bronze/load_fotmob_bronze.py --date 20251208
python scripts/silver/load_fotmob_silver.py --date 20251208 --dry-run
python scripts/silver/load_fotmob_silver.py --month 202512 --dry-run
python scripts/silver/load_fotmob_silver.py --full-history --dry-run
python scripts/gold/load_fotmob_gold.py --date 20251208 --dry-run
python scripts/gold/load_fotmob_gold.py --month 202512 --dry-run
python scripts/gold/load_fotmob_gold.py --full-history --dry-run
python scripts/gold/load_fotmob_gold.py --date 20251208 --part scenarios --dry-run
python scripts/quality/check_data_quality.py --full-history --strict
python scripts/quality/check_logging_style.py
python scripts/orchestration/run_fotmob_pipeline.py 20251208
python scripts/orchestration/run_fotmob_pipeline.py --single-date 20251208
python scripts/oddspedia/discover_oddspedia_events.py --date 20260301
python scripts/oddspedia/prioritize_oddspedia_events.py --date 20260301 --silver-reference-window-ready
python scripts/oddspedia/scrape_oddspedia_matches.py --date 20260301 --priority-tier lower
python scripts/oddspedia/run_oddspedia_pipeline.py --date 20260301 --silver-reference-window-ready
python scripts/oddspedia/run_oddspedia_pipeline.py --start-date 20260301 --end-date 20260307 --silver-reference-window-ready
python scripts/oddspedia/setup_oddspedia_warehouse.py --dry-run
python scripts/oddspedia/load_oddspedia_bronze.py --date 20260301 --dry-run
python scripts/oddspedia/load_oddspedia_bronze.py --start-date 20260301 --end-date 20260307 --dry-run
python scripts/oddspedia/resolve_oddspedia_events.py --date 20260301 --dry-run
```

Use dry-run modes first for loaders, destructive operations, and catalog syncs when available.

## Architecture Rules

- Each source has its own Bronze, Silver, and Gold stage.
- Bronze is the only filesystem-backed layer; Silver and Gold are ClickHouse-only.
- Keep source fidelity in Bronze; standardize keys and types in Silver; materialize business-facing outputs in Gold.
- Keep cross-source joins explicit and read-only; they must not merge raw source contracts.
- SQL should hold transformation and business logic. Python should orchestrate, execute, validate, and report.
- Stable source-owned or warehouse workflow modules may sit behind script entry points to coordinate reusable workflows, but they must not own Silver or Gold analytical logic.
- Use schema-qualified ClickHouse table names: `bronze.*`, `oddspedia_bronze.*`, `silver.*`,
  `gold_scenarios.*`, `gold_signals.*`, and Gold metadata tables in `gold.*`.
- Keep SQL deterministic and rerunnable.
- Preserve script entry points and CLI behavior unless the task explicitly asks for a breaking change.
- Name canonical source workflow scripts
  `<verb>_<source>[_<layer-or-entity>].py`; old names may remain only as
  warning-emitting compatibility adapters.
- Use `scripts/report_scraping.py` as the only canonical scraping-report entry
  point. It selects `fotmob`, `oddspedia`, or `all` through `--source`; source
  adapters remain explicit and read-only.

## Code Style

- Python formatting follows Black with 100-character lines.
- Imports follow isort with the Black profile.
- Use descriptive `snake_case` names for functions and variables, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants.
- Prefer explicit, linear control flow.
- Public functions and CLI helpers should have type hints.
- Use `get_logger(__name__)` and structured logging for runtime code.
- Do not swallow exceptions silently; preserve useful error context when re-raising or reporting.
- Avoid mechanical rewrites of clean files.

## Git Branch Naming

- Use conventional branch names such as `feat/<description>`,
  `fix/<description>`, or `chore/<description>`.
- Do not prefix DepthMark branches with `codex/`.

## Scripts Contract

For files under `scripts/`, script-oriented helpers under `src/`, and source or warehouse workflow modules behind script entry points, follow `docs/SCRIPTS_CONTRACT.md`.

- Keep CLI parsing, execution, reporting, and shared helpers separated.
- Keep script entry points thin and backward-compatible when extracting reusable workflow coordination into `src/`.
- `--dry-run` must not mutate state.
- Exit code `0` means success; non-zero means failure.
- Root-level utility scripts are allowed; source-specific Oddspedia commands live under `scripts/oddspedia`, while existing layer scripts live under `scripts/bronze`, `scripts/silver`, `scripts/gold`, `scripts/orchestration`, `scripts/quality`, or `scripts/mongodb`.
- Load `.env` from the project root and parent root with `override=False` where scripts require local configuration.

## SQL And Catalog Work

- Setup DDL is create-only: `CREATE DATABASE IF NOT EXISTS` and
  `CREATE TABLE IF NOT EXISTS`, never `DROP`, `ALTER`, `TRUNCATE`, or `RENAME`.
  Setup fails on schema drift; apply schema changes to existing tables with
  `scripts/maintenance/recreate_clickhouse_tables.py` (ADR 0026).
- Silver SQL lives under `clickhouse/silver/ddl` and `clickhouse/silver/dml`.
- Gold scenario/signal SQL lives under `clickhouse/gold/dml/`; Gold DDL under `clickhouse/gold/ddl/`.
- New or changed scenario work should update SQL, runner code, DDL/contracts, and the relevant catalog docs.
- Scenario SQL targets `gold_scenarios.scenario_*`; do not add legacy
  `gold.scenario_*` targets.
- Signal metadata source of truth is markdown frontmatter under `catalogs/signals/*.md`.
- Required signal frontmatter keys include `signal_id`, `status`, `entity`, `family`, `subfamily`, `grain`, `row_identity`, and `asset_paths`.

## Testing And Verification

Use the narrowest verification that proves the change.

```bash
pytest
python scripts/quality/check_logging_style.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/silver/load_fotmob_silver.py --date 20251208 --dry-run
python scripts/gold/load_fotmob_gold.py --date 20251208 --dry-run
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
```

Some checks require Docker services, ClickHouse, MongoDB, or real credentials. If a check cannot run locally, say why and describe the remaining risk.

## Data Safety

- Treat `data/`, `logs/`, `store/`, `.env*`, credentials, and generated warehouse files as local-only.
- Do not run destructive drop scripts without dry-run output first unless explicitly instructed.
- Do not rename contract fields, schema columns, or CLI arguments casually.
- Prefer backward-compatible changes to script outputs, table schemas, and catalog formats.

## Documentation Expectations

Update documentation in the same change when behavior, command surfaces, schema contracts, or operational runbooks change. Keep docs implementation-accurate and remove stale guidance instead of adding contradictory notes.
