# Silver Layer

Silver standardizes keys, types, and reusable analytical entities from Bronze.
It is a ClickHouse-only layer — all transformations are pure SQL.

## Overview

```text
bronze.* (15 tables)
  → silver.* (8 tables)
```

Silver SQL lives under `clickhouse/silver/`:
- `ddl/` — table creation (8 tables + `00_create_database.sql` + `99_all_tables.sql`)
- `dml/` — INSERT...SELECT from Bronze (8 scripts)

## Tables

| Table | Grain | Source Bronze Tables |
| --- | --- | --- |
| `silver.match` | one row per match | `bronze.general`, `bronze.venue`, `bronze.timeline` |
| `silver.period_stat` | one row per match per period | `bronze.period` |
| `silver.player_match_stat` | one row per player per match | `bronze.player`, `bronze.starters`, `bronze.substitutes` |
| `silver.momentum` | one row per match timestamp | `bronze.momentum` |
| `silver.shot` | one row per shot | `bronze.shotmap` |
| `silver.card` | one row per card | `bronze.cards` |
| `silver.match_personnel` | one row per coach/sub per match | `bronze.coaches`, `bronze.substitutes` |
| `silver.team_form` | one row per team form entry | `bronze.team_form` |

## Data Flow

### 1. DDL Setup (`scripts/silver/setup_clickhouse.py`)

Creates the `silver` database and all 8 tables:
```bash
python3 scripts/silver/setup_clickhouse.py
```

### 2. DML Execution (`scripts/silver/load_clickhouse.py`)

Requires one explicit scope and executes all DML scripts in order:
```bash
python3 scripts/silver/load_clickhouse.py --date 20251208
python3 scripts/silver/load_clickhouse.py --single-date 20251208
python3 scripts/silver/load_clickhouse.py --month 202512
python3 scripts/silver/load_clickhouse.py --full-history
python3 scripts/silver/load_clickhouse.py --date 20251208 --dry-run
```

`--single-date` remains a backward-compatible alias for `--date`.

The scoped function flow is:

1. `execution_scope_from_args()` returns a validated
   `WarehouseExecutionScope`.
2. `SilverService.build_scoped_jobs()` discovers SQL by prefix and creates one
   `ScopedSqlJob` per target.
3. `ScopedReplacementBatch` computes every selected table in staging using all
   available Bronze history.
4. After all staging succeeds, date runs reconstruct and replace the containing
   month partition, month runs replace that month, and full-history runs
   exchange complete staged tables.
5. Layer contract assertions run after all commits succeed.

### 3. Contract Validation

`assert_silver_layer_contracts()` in `src/utils/layer_contracts.py` checks:
- All 8 tables exist.
- Required columns are present with correct types.
- Row counts are non-zero after a full load.
- Duplicate business keys are treated as a load failure.

## Key Design Decisions

- **SQL owns transformation logic.** Python orchestrates and executes, but all
  cleaning, typing, and joining logic lives in ClickHouse SQL.
- **Scope-aware replacement.** Date and month runs never truncate whole tables.
- **Historical context.** Jobs currently read full Bronze history while
  replacing only the requested match-date output scope.
- **Deterministic and rerunnable.** Repeating a scope replaces the same logical
  rows and removes rows that stopped qualifying after source corrections.

## Failure Modes

| Failure | Recovery |
| --- | --- |
| Bronze tables missing | Run Bronze loader first |
| SQL syntax error | Fix SQL, re-run `load_clickhouse.py` with the same scope |
| Contract assertion fails | Check Bronze data quality, re-run |
| Staging failure | Targets remain unchanged; inspect retained stage tables and rerun |
| Partial commit failure | Rerun the identical scope to converge all tables |
| ClickHouse connection | Non-zero exit, re-run |
