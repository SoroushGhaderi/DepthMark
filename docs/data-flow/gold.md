# Gold Layer

Gold materializes product-facing scenario and signal outputs for downstream
consumption. It is a ClickHouse-only layer across three namespaces.

## Overview

```text
silver.* (8 tables)
  → gold_scenarios.*  (48 scenario tables)
  → gold_signals.*    (344 signal tables)
  → gold.*            (1 shared activation serving table)
```

## Namespaces

| Database | Purpose | Table Pattern |
| --- | --- | --- |
| `gold_scenarios` | Scenario outputs at team/match or player grain | `scenario_*` |
| `gold_signals` | Signal outputs at match, team, or player grain | `sig_*` |
| `gold` | Shared activation serving metadata | `signal_activations` |

## Signal System

### Anatomy of a Signal

Each signal consists of 4 artifacts:

| Artifact | Location | Purpose |
| --- | --- | --- |
| SQL | `clickhouse/gold/signal/sig_<name>.sql` | Transformation logic |
| Table DDL | `clickhouse/gold/create_table_signals/` | Output table schema |
| Catalog | `scripts/gold/signal/catalogs/sig_<name>.md` | Metadata + documentation |
| Index | `scripts/gold/signal/catalogs/README.md` | Signal inventory |

### Signal Taxonomy

Signals are organized by:
- **Entity**: `match`, `player`, `team`
- **Family**: `shooting`, `creativity`, `possession`, `discipline`, `goalkeeping`
- **Subfamily**: `goals`, `playmaking`, `passing`, `cards`, `defense`
- **Grain**: `match_team`, `match_player`

Example: `sig_player_shooting_goals_shot_conversion_peak`
- Prefix: `sig`
- Entity: `player`
- Family: `shooting`
- Subfamily: `goals`
- Name: `shot_conversion_peak`

### Signal Contracts

- `SIGNAL_CORE_CONTRACT.md` — creative logic and football semantics
- `SIGNAL_EXECUTION_CONTRACT.md` — routine implementation rules

## Scenario System

Scenarios are narrative-driven analysis outputs:
- 23 team/match-grain scenarios in `clickhouse/gold/scenario/team/`
- 25 player-grain scenarios in `clickhouse/gold/scenario/player/`

Catalog: `scripts/gold/scenario/scenarios_catalog.md`

## Data Flow

### 1. DDL Setup (`scripts/gold/setup_clickhouse_gold.py`)

Creates all Gold databases and tables:
```bash
python scripts/gold/setup_clickhouse_gold.py              # all
python scripts/gold/setup_clickhouse_gold.py --part scenarios
python scripts/gold/setup_clickhouse_gold.py --part signals
```

### 2. SQL Job Execution (`scripts/gold/run_sql_job.py`)

The generic runner discovers and executes Gold SQL jobs:
```bash
python scripts/gold/run_sql_job.py --dry-run
python scripts/gold/run_sql_job.py --kind signal
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak
python scripts/gold/run_sql_job.py --kind signal --entity player
python scripts/gold/run_sql_job.py --kind signal --family shooting_goals
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance
```

Job discovery uses `GoldSqlJob` in `src/services/gold/sql_jobs.py`:
- Files prefixed `sig_*.sql` → signal jobs
- Files prefixed `scenario_*.sql` → scenario jobs
- Selection by `--id`, `--entity`, `--family`, or `--kind`

### 3. Bulk Loading (`scripts/gold/load_clickhouse_gold.py`)

Runs all Gold SQL jobs and activation rebuilds:
```bash
python scripts/gold/load_clickhouse_gold.py              # all
python scripts/gold/load_clickhouse_gold.py --part signals
python scripts/gold/load_clickhouse_gold.py --part scenarios
python scripts/gold/load_clickhouse_gold.py --dry-run
```

Execution order:
1. Scenario SQL jobs (if `--part scenarios` or `--part all`)
2. Signal SQL jobs (if `--part signals` or `--part all`)
3. Activation rebuild (after signal execution)

### 4. Activation Rebuild (`scripts/gold/activations/build_signal_activations.py`)

Rebuilds `gold.signal_activations` from all active signal catalogs:

1. Scans active signal catalogs in `scripts/gold/signal/catalogs/`.
2. Reads each catalog's `row_identity` fields.
3. For each signal output row in `gold_signals.sig_*`:
   - Computes `signal_instance_id = SHA256("v1|signal_id|<identity values>")`
   - Parses signal metadata from the `signal_id` pattern
   - Copies common fixture/team/player context
   - Stores full source row in `source_row_json`
4. Rebuilds match-level summary fields per activation row.

Key fields in `gold.signal_activations`:
- `signal_instance_id` — deterministic identity hash
- `signal_id_version` — identity scheme version (`v1`)
- `signal_id`, `signal_entity`, `signal_family`, `signal_subfamily`
- `match_id`, `team_id`, `player_id` — context fields
- `source_row_json` — full source signal row
- `activated_signal_instance_ids` — match-level summary array
- `unique_signal_count` — distinct signal count per match

### 5. Drop Scripts

```bash
python scripts/gold/drop_clickhouse_scenarios.py --dry-run
python scripts/gold/drop_clickhouse_scenarios.py --part scenarios
python scripts/gold/drop_clickhouse_scenarios.py --part signals
python scripts/gold/drop_clickhouse_scenarios.py --part all
```

## Key Design Decisions

- **SQL owns transformation logic.** Gold SQL files contain all analytical
  logic; Python orchestrates execution.
- **Generic runners only.** No handwritten per-signal or per-scenario Python
  wrappers (ADR 0001, 0009).
- **Full-table activation rebuilds.** No incremental or date-scoped rebuilds
  (ADR 0011).
- **`ReplacingMergeTree` with `FINAL`** for idempotent signal outputs.
- **Versioned activation identity.** `signal_id_version` (`v1`) prefixes the
  activation hash (ADR 0006).

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Signal SQL fails | Re-run `run_sql_job.py --kind signal --id <signal>` |
| Scenario SQL fails | Re-run `run_sql_job.py --kind scenario --id <scenario>` |
| Activation rebuild fails | Re-run `build_signal_activations.py` |
| DDL mismatch | Re-run `setup_clickhouse_gold.py` |
| ClickHouse connection | Non-zero exit, re-run |
