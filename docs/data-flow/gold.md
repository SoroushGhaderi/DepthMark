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
| SQL | `clickhouse/gold/dml/signals/<entity>/sig_<name>.sql` | Transformation logic |
| Table DDL | `clickhouse/gold/ddl/signals/{match,team,player}/` | Output table schema |
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
- 23 team/match-grain scenarios in `clickhouse/gold/dml/scenarios/team/`
- 25 player-grain scenarios in `clickhouse/gold/dml/scenarios/player/`

Catalog: `scripts/gold/scenario/SCENARIOS_CATALOG.md`

## Data Flow

### 1. DDL Setup (`scripts/gold/setup_clickhouse_gold.py`)

Creates all Gold databases and tables:
```bash
python3 scripts/gold/setup_clickhouse_gold.py              # all
python3 scripts/gold/setup_clickhouse_gold.py --part scenarios
python3 scripts/gold/setup_clickhouse_gold.py --part signals
```

### 2. SQL Job Execution (`scripts/gold/run_gold_sql_jobs.py`)

The generic runner discovers and executes Gold SQL jobs:
```bash
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --id sig_player_shooting_goals_shot_conversion_peak
python3 scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity player
python3 scripts/gold/run_gold_sql_jobs.py --full-history --kind signal --family shooting_goals
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance
```

Job discovery uses `GoldSqlJob` in `src/services/gold/gold_dml_runner.py`:
- Files prefixed `sig_*.sql` → signal jobs
- Files prefixed `scenario_*.sql` → scenario jobs
- Selection by `--id`, `--entity`, `--family`, or `--kind`

### 3. Bulk Loading (`scripts/gold/load_clickhouse_gold.py`)

Runs all Gold SQL jobs and scoped activation replacement. One explicit scope is
required:
```bash
python3 scripts/gold/load_clickhouse_gold.py --date 20251208
python3 scripts/gold/load_clickhouse_gold.py --single-date 20251208
python3 scripts/gold/load_clickhouse_gold.py --month 202512
python3 scripts/gold/load_clickhouse_gold.py --full-history
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part scenarios
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run
```

Execution order:
1. `execution_scope_from_args()` builds a `WarehouseExecutionScope`.
2. `build_scoped_gold_job()` turns discovered scenario and signal files into
   `ScopedSqlJob` values.
3. `ScopedReplacementBatch` stages and validates every selected Gold output
   before committing any table.
4. Date runs reconstruct the containing month partition; month runs replace the
   selected month; full-history runs exchange complete staged tables.
5. Activation replacement runs with the same scope after every selected signal
   table commits successfully.

### 4. Activation Rebuild (`scripts/gold/activations/build_signal_activations.py`)

Builds `gold.signal_activations` from all active signal catalogs, then replaces
only the requested output scope:

1. **Stage** — insert one enriched row per `gold_signals.sig_*` output into ephemeral
   `gold.signal_activations_stage` (created from
   `clickhouse/gold/ddl/activations/create_table_signal_activations_stage.sql`).
2. **Calculate** — run
   `clickhouse/gold/dml/activations/signal_activation_final_insert.sql` into a
   scoped calculation table with per-match summary aggregates.
3. **Commit** — replace the selected monthly partition, reconstruct the
   containing month for a date run, or exchange the complete table for an
   explicit full-history run.

Per-row enrichment in the stage pass:

1. Scans active signal catalogs in `scripts/gold/signal/catalogs/`.
2. Reads each catalog's `row_identity` fields.
3. For each signal output row in `gold_signals.sig_*`:
   - Computes `signal_instance_id = SHA256("v1|signal_id|<identity values>")`
   - Parses signal metadata from the `signal_id` pattern
   - Copies common fixture/team/player context
   - Stores full source row in `source_row_json`

The final insert adds match-level summary fields on every activation row
(`match_activation_instance_id`, `activated_signal_ids`, `total_signal_rows`,
and related arrays).

```bash
python3 scripts/gold/activations/build_signal_activations.py --date 20251208
python3 scripts/gold/activations/build_signal_activations.py --month 202512
python3 scripts/gold/activations/build_signal_activations.py --full-history
python3 scripts/gold/activations/build_signal_activations.py --date 20251208 --dry-run
```

Serving-table DDL: `clickhouse/gold/ddl/create_table_signal_activations.sql`

`load_clickhouse_gold.py` invokes the builder after successful signal runs.
If any signal SQL job fails, activation rebuild is skipped until signals succeed
or you rerun the builder manually.

Key fields in `gold.signal_activations`:
- `signal_instance_id` — deterministic identity hash
- `signal_id_version` — identity scheme version (`v1`)
- `signal_id`, `signal_entity`, `signal_family`, `signal_subfamily`
- `match_id`, `match_kickoff_utc`, `league_name`, `stadium_name`,
  `triggered_team_id`, `triggered_player_id` — context fields
- `source_row_json` — full source signal row
- `activated_signal_instance_ids` — match-level summary array
- `unique_signal_count` — distinct signal count per match

### 5. Drop Scripts

```bash
python3 scripts/gold/drop_clickhouse_scenarios.py --dry-run
python3 scripts/gold/drop_clickhouse_scenarios.py --part scenarios
python3 scripts/gold/drop_clickhouse_scenarios.py --part signals
python3 scripts/gold/drop_clickhouse_scenarios.py --part all
```

## Key Design Decisions

- **SQL owns transformation logic.** Gold SQL files contain all analytical
  logic; Python orchestrates execution.
- **Generic runners only.** No handwritten per-signal or per-scenario Python
  wrappers (ADR 0001, 0009).
- **Scope-aware staged replacement.** ADR 0018 supersedes ADR 0011 for date and
  month runs; full-table exchange is reserved for explicit full-history runs.
- **`ReplacingMergeTree` with `FINAL`** for idempotent signal outputs.
- **Versioned activation identity.** `signal_id_version` (`v1`) prefixes the
  activation hash (ADR 0006).

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Signal SQL fails | Re-run `run_gold_sql_jobs.py --date <YYYYMMDD> --kind signal --id <signal>` |
| Scenario SQL fails | Re-run `run_gold_sql_jobs.py --date <YYYYMMDD> --kind scenario --id <scenario>` |
| Activation replacement fails | Re-run `build_signal_activations.py` with the same scope |
| Signal SQL failures block activations | Fix signals and rerun `load_clickhouse_gold.py` with the same scope |
| Staging fails | Existing targets remain unchanged; inspect retained stage tables |
| Commit partially fails | Rerun the identical scope to converge committed and pending tables |
| DDL mismatch | Re-run `setup_clickhouse_gold.py` |
| ClickHouse connection | Non-zero exit, re-run |
