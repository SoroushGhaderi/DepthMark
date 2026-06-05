# Scripts Layout

This file is a compact inventory of script locations and supported entry points.
For the project-wide command surface and runbook, use `../docs/DEVELOPMENT_ARCHITECTURE.md`.
For script behavior rules, naming/style handwriting, function design, and update policy, use `../docs/SCRIPTS_CONTRACT.md`.

## Supported Entry Points

Use these paths for new automation and daily runs:

- `scripts/bronze/scrape_fotmob.py`
- `scripts/bronze/load_clickhouse.py`
- `scripts/bronze/drop_clickhouse.py`
- `scripts/bronze/setup_clickhouse.py`
- `scripts/silver/load_clickhouse.py`
- `scripts/silver/drop_clickhouse.py`
- `scripts/silver/setup_clickhouse.py`
- `scripts/gold/load_clickhouse_gold.py`
- `scripts/gold/drop_clickhouse_scenarios.py`
- `scripts/gold/setup_clickhouse_gold.py`
- `scripts/orchestration/pipeline.py`
- `scripts/orchestration/setup_clickhouse.py`

### Dry-Run Support

- `scripts/silver/load_clickhouse.py --dry-run`
- `scripts/gold/load_clickhouse_gold.py --dry-run`
- `scripts/gold/load_clickhouse_gold.py --part signals --dry-run`

## Operational Utility Scripts

- `scripts/ensure_directories.py`
- `scripts/health_check.py`
- `scripts/refresh_turnstile.py`
- `scripts/mongodb/init_indexes.py`
- `scripts/mongodb/sync_signal_catalogs.py`
- `scripts/gold/activations/build_signal_activations.py`

## Quality Check Scripts

- `scripts/quality/check_bronze_to_silver_reconciliation.py`
- `scripts/quality/check_logging_style.py`

## Scenario Scripts

These `scripts/gold/scenario/scenario_*.py` runners are discovered and executed by `scripts/gold/load_clickhouse_gold.py`.
Scenario standards are defined in `scripts/gold/scenario/SCENARIOS_CONTRACT.md`.

Current inventory: 48 scenario runners and 48 matching SQL transforms.

- Runner files: `scripts/gold/scenario/scenario_*.py`
- SQL files: `clickhouse/gold/scenario/{team,player}/scenario_*.sql`
- Catalog: `scripts/gold/scenario/SCENARIOS_CATALOG.md`

## Signal Scripts

These `scripts/gold/signal/runners/sig_*.py` runners are also discovered and executed by `scripts/gold/load_clickhouse_gold.py`.
Legacy `signal_*.py` runners are still supported by the loader for migration compatibility, but new work should use `sig_*.py`.
After successful signal runner execution, the loader runs `scripts/gold/activations/build_signal_activations.py`
to populate deterministic per-match activation IDs in `gold.signal_activations`.
The activation ID key uses each signal catalog `row_identity` definition.

Current inventory: 211 signal runners, 211 matching SQL transforms, and 211 matching markdown catalogs.

- Runner files: `scripts/gold/signal/runners/sig_*.py`
- SQL files: `clickhouse/gold/signal/sig_*.sql`
- Contracts: `scripts/gold/signal/contracts/`

## Signal Catalogs

Per-signal docs live in `scripts/gold/signal/catalogs/` and include tactical logic plus output schema tables:

- `scripts/gold/signal/catalogs/README.md`
- `scripts/gold/signal/catalogs/sig_*.md`

Before deep review of many full catalogs, use a token-efficient manual flow:

- read only `catalogs/README.md` table first
- shortlist max 8 active candidates by `entity/family/subfamily` (+ `grain` when available)
- read only frontmatter + Purpose + Trigger for shortlisted candidates
