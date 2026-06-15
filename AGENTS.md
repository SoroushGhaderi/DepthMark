# DepthMark Agent Guide

Use this guide when working inside the `depthmark` project. Keep changes aligned with the existing FotMob-only medallion pipeline and prefer small, explicit edits over broad rewrites.

## Location And Scope

This file belongs at the DepthMark project root because its instructions apply to the whole `depthmark` tree. Add a more specific `AGENTS.md` only inside a subdirectory that needs different rules.

Do not use this file as a Codex skill. Skills are reusable procedures with their own `SKILL.md` files, useful for repeated workflows across projects. This file is project context: architecture, commands, conventions, and safety rules for this repo.

## Project Overview

DepthMark is a Python data pipeline for FotMob football data.

- Bronze: raw FotMob API payloads on disk under `data/fotmob/`, plus raw ClickHouse tables in `bronze.*`.
- Silver: cleaned and conformed analytical tables in ClickHouse `silver.*`.
- Gold: analytics and product-ready scenario tables in ClickHouse
  `gold_scenarios.*`, signal tables in `gold_signals.*`, and shared metadata in
  `gold.*`.
- MongoDB stores content/catalog metadata, including signal catalog entries authored from markdown frontmatter.

DepthMark currently supports FotMob only. Do not add generic multi-provider abstractions unless explicitly requested.

## Important References

- `README.md`: project overview and documentation index.
- `docs/README.md`: documentation map.
- `docs/DEVELOPMENT_ARCHITECTURE.md`: architecture, canonical entry points, and runbook.
- `docs/data-flow/infrastructure.md`: Docker setup, quick start, and environment configuration.
- `docs/SCRIPTS_CONTRACT.md`: authoritative rules for scripts, script-oriented helpers, and application services behind script entry points.
- `scripts/README.md`: script layout and command surface.
- `clickhouse/gold/dml/signals/README.md` and `scripts/gold/signal/catalogs/README.md`: signal SQL/catalog guidance.

If these files conflict with code, resolve the mismatch intentionally and mention it in the change summary.

## Environment And Secrets

- Never commit `.env`, credentials, tokens, generated data, logs, or local warehouse artifacts.
- Use `.env.example` for documenting required configuration.
- Required local services come from the root `docker-compose.yml`.
- A useful local setup starts with:
  - `cp .env.example .env`
  - `docker compose up -d`
  - `python scripts/orchestration/setup_clickhouse.py`

## Canonical Commands

Run commands from the `depthmark` directory.

```bash
python scripts/orchestration/setup_clickhouse.py
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/bronze/scrape_fotmob.py 20251208
python scripts/bronze/load_clickhouse.py --date 20251208
python scripts/silver/load_clickhouse.py --dry-run
python scripts/gold/load_clickhouse_gold.py --dry-run
python scripts/gold/load_clickhouse_gold.py --part scenarios --dry-run
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
python scripts/quality/check_logging_style.py
python scripts/orchestration/pipeline.py 20251208
```

Use dry-run modes first for loaders, destructive operations, and catalog syncs when available.

## Architecture Rules

- Bronze is the only filesystem-backed layer.
- Silver and Gold are ClickHouse-only layers.
- Keep source fidelity in Bronze; standardize keys and types in Silver; materialize business-facing outputs in Gold.
- SQL should hold transformation and business logic. Python should orchestrate, execute, validate, and report.
- Stable application services may live under `src/services/` behind script entry points to coordinate reusable workflows, but they must not own Silver or Gold analytical logic.
- Use schema-qualified ClickHouse table names: `bronze.*`, `silver.*`,
  `gold_scenarios.*`, `gold_signals.*`, and Gold metadata tables in `gold.*`.
- Keep SQL deterministic and rerunnable.
- Preserve script entry points and CLI behavior unless the task explicitly asks for a breaking change.

## Code Style

- Python formatting follows Black with 100-character lines.
- Imports follow isort with the Black profile.
- Use descriptive `snake_case` names for functions and variables, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants.
- Prefer explicit, linear control flow.
- Public functions and CLI helpers should have type hints.
- Use `get_logger(__name__)` and structured logging for runtime code.
- Do not swallow exceptions silently; preserve useful error context when re-raising or reporting.
- Avoid mechanical rewrites of clean files.

## Scripts Contract

For files under `scripts/`, script-oriented helpers under `src/`, and application-service code under `src/services/` behind script entry points, follow `docs/SCRIPTS_CONTRACT.md`.

- Keep CLI parsing, execution, reporting, and shared helpers separated.
- Keep script entry points thin and backward-compatible when extracting reusable workflow coordination into `src/`.
- `--dry-run` must not mutate state.
- Exit code `0` means success; non-zero means failure.
- Root-level utility scripts are allowed, but new layer scripts should live under `scripts/bronze`, `scripts/silver`, `scripts/gold`, `scripts/orchestration`, `scripts/quality`, or `scripts/mongodb`.
- Load `.env` from the project root and parent root with `override=False` where scripts require local configuration.

## SQL And Catalog Work

- Silver SQL lives under `clickhouse/silver/ddl` and `clickhouse/silver/dml`.
- Gold scenario/signal SQL lives under `clickhouse/gold/dml/`; Gold DDL under `clickhouse/gold/ddl/`.
- New or changed scenario work should update SQL, runner code, DDL/contracts, and the relevant catalog docs.
- Scenario SQL targets `gold_scenarios.scenario_*`; do not add legacy
  `gold.scenario_*` targets.
- Signal metadata source of truth is markdown frontmatter under `scripts/gold/signal/catalogs/*.md`.
- Required signal frontmatter keys include `signal_id`, `status`, `entity`, `family`, `subfamily`, `grain`, `row_identity`, and `asset_paths`.

## Testing And Verification

Use the narrowest verification that proves the change.

```bash
pytest
python scripts/quality/check_logging_style.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/silver/load_clickhouse.py --dry-run
python scripts/gold/load_clickhouse_gold.py --dry-run
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
