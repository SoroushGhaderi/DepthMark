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
python scripts/silver/setup_clickhouse.py
```

### 2. DML Execution (`scripts/silver/load_clickhouse.py`)

Discovers and executes all DML scripts in order:
```bash
python scripts/silver/load_clickhouse.py          # full load
python scripts/silver/load_clickhouse.py --single-date 20251208  # single date
python scripts/silver/load_clickhouse.py --dry-run # preview only
```

Each DML script is an `INSERT...SELECT` that:
1. Reads from one or more `bronze.*` tables.
2. Casts types and standardizes keys.
3. Refreshes the target `silver.*` table with a full-table replacement.

The Silver service (`src/services/silver/`) coordinates:
- SQL file discovery by prefix (`01_*.sql` through `08_*.sql`)
- Sequential execution
- Layer contract assertion after completion

### 3. Contract Validation

`assert_silver_layer_contracts()` in `src/utils/layer_contracts.py` checks:
- All 8 tables exist.
- Required columns are present with correct types.
- Row counts are non-zero after a full load.
- Duplicate business keys are treated as a load failure.

## Key Design Decisions

- **SQL owns transformation logic.** Python orchestrates and executes, but all
  cleaning, typing, and joining logic lives in ClickHouse SQL.
- **Full-table reloads.** Silver does not support date-scoped incremental
  loads — it rebuilds from the full Bronze dataset and truncates each target
  table before inserting the fresh snapshot.
- **Deterministic and rerunnable.** Each DML script is idempotent because the
  previous table contents are removed before the new load lands.

## Failure Modes

| Failure | Recovery |
| --- | --- |
| Bronze tables missing | Run Bronze loader first |
| SQL syntax error | Fix SQL, re-run `load_clickhouse.py` |
| Contract assertion fails | Check Bronze data quality, re-run |
| ClickHouse connection | Non-zero exit, re-run |
