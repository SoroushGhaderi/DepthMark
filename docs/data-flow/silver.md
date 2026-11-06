# Silver Layer — Source-specific conformation

Silver is the second layer in each source pipeline. It standardizes keys,
types, and reusable analytical entities from that source's Bronze facts. It is
ClickHouse-only and all analytical transformations are pure SQL.

The two Silver paths are parallel:

```text
FotMob Bronze       → FotMob Silver       → FotMob Gold
Oddspedia Bronze    → Oddspedia Silver    → Oddspedia Gold
                         │
                         └── explicit cross-source match relationship
```

The existing FotMob tables below describe the implemented FotMob Silver path.
Oddspedia Silver owns cleaned event/odds entities and the auditable
`oddspedia_silver.match_resolution` relationship; that relationship reads the
canonical FotMob `fotmob_silver.match` reference but does not replace the Oddspedia
Silver path.

## Overview

```text
fotmob_bronze.* (15 tables)
  → fotmob_silver.* (8 tables)
```

## Oddspedia Silver resolution boundary

The current Oddspedia Silver implementation is the explicit relationship
`oddspedia_silver.match_resolution`. Before it reads Oddspedia facts,
`resolve_oddspedia_events.py` requires the date's latest
`oddspedia_bronze.load_status` row to be `published`; `staging` and `failed`
batches are not valid Silver input. When the operator supplies
`--silver-reference-window-ready`, the resolver also machine-verifies exact
FotMob fixture-ID set equality between `fotmob_bronze.match_reference` and
`fotmob_silver.match` for the previous, current, and following UTC dates. The flag is
an operator assertion that enables the check; it does not replace the check.

```bash
python3 scripts/oddspedia/resolve_oddspedia_events.py --date 20260301 --silver-reference-window-ready --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --month 202603 --silver-reference-window-ready --dry-run
```

Silver SQL lives under `clickhouse/silver/`:
- `ddl/` — table creation (8 tables + `00_create_database.sql` + `99_all_tables.sql`)
- `dml/` — INSERT...SELECT from Bronze (8 scripts)

## Tables

| Table | Grain | Source Bronze Tables |
| --- | --- | --- |
| `fotmob_silver.match` | one row per match | `fotmob_bronze.general`, `fotmob_bronze.venue`, `fotmob_bronze.timeline` |
| `fotmob_silver.period_stat` | one row per match per period | `fotmob_bronze.period` |
| `fotmob_silver.player_match_stat` | one row per player per match | `fotmob_bronze.player`, `fotmob_bronze.starters`, `fotmob_bronze.substitutes` |
| `fotmob_silver.momentum` | one row per match timestamp | `fotmob_bronze.momentum` |
| `fotmob_silver.shot` | one row per shot | `fotmob_bronze.shotmap` |
| `fotmob_silver.card` | one row per card | `fotmob_bronze.cards` |
| `fotmob_silver.match_personnel` | one row per coach/sub per match | `fotmob_bronze.coaches`, `fotmob_bronze.substitutes` |
| `fotmob_silver.team_form` | one row per team form entry | `fotmob_bronze.team_form` |

## Data Flow

### 1. DDL Setup (`scripts/fotmob/setup_fotmob_silver.py`)

Creates the `fotmob_silver` database and all 8 tables:
```bash
python3 scripts/fotmob/setup_fotmob_silver.py
```

### 2. DML Execution (`scripts/fotmob/load_fotmob_silver.py`)

Requires one explicit scope and executes all DML scripts in order:
```bash
python3 scripts/fotmob/load_fotmob_silver.py --date 20251208
python3 scripts/fotmob/load_fotmob_silver.py --single-date 20251208
python3 scripts/fotmob/load_fotmob_silver.py --month 202512
python3 scripts/fotmob/load_fotmob_silver.py --full-history
python3 scripts/fotmob/load_fotmob_silver.py --date 20251208 --dry-run
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

`assert_silver_layer_contracts()` in `src/warehouse/contracts.py` checks:
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
| SQL syntax error | Fix SQL, re-run `load_fotmob_silver.py` with the same scope |
| Contract assertion fails | Check Bronze data quality, re-run |
| Staging failure | Targets remain unchanged; inspect retained stage tables and rerun |
| Partial commit failure | Rerun the identical scope to converge all tables |
| ClickHouse connection | Non-zero exit, re-run |
