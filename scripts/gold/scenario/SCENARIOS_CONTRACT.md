# Gold Scenarios Contract

This document defines the stable contract for Gold scenario jobs in DepthMark.

## Scope

This contract applies to:

- `clickhouse/gold/dml/scenarios/{team,player}/scenario_*.sql`
- `scripts/gold/run_gold_sql_jobs.py`
- `src/services/gold/gold_dml_runner.py`
- `scripts/gold/load_clickhouse_gold.py`
- `scripts/gold/scenario/SCENARIOS_CATALOG.md`

## Scenario Unit Contract

Each scenario is a 3-part unit:

1. SQL transformation file  
   `clickhouse/gold/dml/scenarios/{team,player}/scenario_<name>.sql`
2. Target table  
   `gold_scenarios.scenario_<name>`
3. Catalog entry in  
   `scripts/gold/scenario/SCENARIOS_CATALOG.md`

All three parts are required for a production-ready scenario.

## Naming Contract

1. Scenario ID format: `scenario_<name>` (snake_case).
2. SQL filename and target table suffix must match exactly by `<name>`.
3. Target table must be `gold_scenarios.scenario_<name>`.
4. Generic SQL job resolution must map `scenario_<name>` to `scenario_<name>.sql`.

## SQL Contract

1. Scenario SQL must be `INSERT INTO gold_scenarios.scenario_<name> ... SELECT ...`.
2. Scenario SQL must not include DDL (`CREATE`, `ALTER`, `DROP`).
3. Source tables must be schema-qualified (`bronze.*`, `silver.*`, `gold.*`).
4. `match_id` must be produced and valid (`> 0`, non-null in final rows).
   This is required by `assert_gold_layer_contracts`.
5. SQL must be re-runnable safely (ReplacingMergeTree + dedup model).
6. Use explicit aliases and deterministic filters for reproducibility.

## Runner Contract

1. The generic Gold SQL runner must:
   - connect via `ClickHouseClient`
   - read SQL from the selected scenario SQL file
   - execute insert SQL
   - run `OPTIMIZE TABLE <target> FINAL DEDUPLICATE`
   - return non-zero on failure
2. Runner should not embed business SQL in Python strings.
3. Individual scenario execution must remain available through
   `scripts/gold/run_gold_sql_jobs.py --date <YYYYMMDD> --kind scenario --id <scenario_id>`.
4. Scenario-kind execution must remain available through
   `scripts/gold/run_gold_sql_jobs.py --date <YYYYMMDD> --kind scenario`.

## Bulk Execution Contract

`scripts/gold/load_clickhouse_gold.py` is the canonical layer runner.

1. Executes base gold DDL files from `clickhouse/gold/ddl/`.
2. Scenario bulk execution is enabled through `--part scenarios` or `--part all`.
3. Supports `--dry-run` for plan/preview mode.
4. Runs `assert_gold_layer_contracts` after scenario and/or signal execution.
5. Requires `--date`, `--month`, or `--full-history` and commits through
   `ScopedReplacementBatch`.

## Catalog Contract

Each scenario entry in `SCENARIOS_CATALOG.md` must include:

1. Purpose
2. Tactical/statistical logic (threshold rationale)
3. Technical assets:
   - SQL file path
   - target table
4. Example execution command

## Validation Gate

Minimum operational checks:

1. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run`
2. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208`
3. `python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id <scenario_id> --dry-run`
4. `python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --dry-run`
5. Verify no gold contract failures (`invalid match_id`, missing scenario tables).

## Change Management Rules

1. Any new scenario must update:
   - `clickhouse/gold/ddl/01_create_scenario_tables.sql` (or active DDL file set)
   - `scripts/gold/scenario/SCENARIOS_CATALOG.md`
2. Renaming/deleting a scenario requires coordinated changes to:
   - SQL file
   - target table DDL
   - catalog entry
3. No breaking renames without documentation updates in:
   - `scripts/README.md`
   - `docs/DEVELOPMENT_ARCHITECTURE.md` (if boundaries or command surface changed)
