# DepthMark Development Architecture

This is the project-wide reference for how DepthMark is built and operated. It
owns architecture, layer boundaries, command surface, and runbook guidance.
Script coding standards live in `SCRIPTS_CONTRACT.md`.

## Scope

DepthMark is a FotMob-only medallion pipeline:

1. Bronze stores raw FotMob payloads on disk and loads raw tables into ClickHouse.
2. Silver builds cleaned, typed, reusable analytical tables in ClickHouse.
3. Gold materializes scenario and signal outputs in ClickHouse for product and BI
   use.

```text
FotMob API
  -> data/fotmob/          raw Bronze files
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
```

## Layer Boundaries

1. Bronze is the only filesystem-backed data layer.
2. Silver and Gold are ClickHouse-only layers.
3. Bronze preserves source fidelity with minimal transformation.
4. Silver standardizes keys, types, and reusable entities.
5. Gold produces downstream-ready scenario and signal tables.
6. Warehouse tables must be schema-qualified as `bronze.*`, `silver.*`, or
   `gold_scenarios.*` and `gold_signals.*`.

## Canonical Command Surface

Use these paths for documentation, automation, and daily operations.

### Setup

```bash
python scripts/orchestration/setup_clickhouse.py
python scripts/bronze/setup_clickhouse.py
python scripts/silver/setup_clickhouse.py
python scripts/gold/setup_clickhouse_gold.py
```

### Bronze

```bash
python scripts/bronze/scrape_fotmob.py 20251208
python scripts/bronze/load_clickhouse.py --date 20251208
python scripts/bronze/drop_clickhouse.py --dry-run
```

### Silver

```bash
python scripts/silver/load_clickhouse.py
python scripts/silver/load_clickhouse.py --dry-run
python scripts/silver/drop_clickhouse.py --dry-run
```

### Gold

```bash
python scripts/gold/load_clickhouse_gold.py
python scripts/gold/load_clickhouse_gold.py --dry-run
python scripts/gold/load_clickhouse_gold.py --part signals --dry-run
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance --dry-run
python scripts/gold/drop_clickhouse_scenarios.py --dry-run
```

### Orchestration, Quality, and Ops

```bash
python scripts/orchestration/pipeline.py 20251208
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
python scripts/quality/check_logging_style.py
python scripts/health_check.py --json
python scripts/ensure_directories.py
python scripts/refresh_turnstile.py
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
```

## Pipeline Runbook

### Standard Runs

```bash
python scripts/orchestration/pipeline.py 20251208
python scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207
python scripts/orchestration/pipeline.py --month 202512
```

### Partial Runs

```bash
python scripts/orchestration/pipeline.py 20251208 --bronze-only
python scripts/orchestration/pipeline.py 20251208 --silver-only
python scripts/orchestration/pipeline.py 20251208 --gold-only
python scripts/orchestration/pipeline.py 20251208 --skip-bronze
```

### Recommended Preflight and Validation

```bash
python scripts/health_check.py --json
python scripts/silver/load_clickhouse.py --dry-run
python scripts/gold/load_clickhouse_gold.py --dry-run
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
python scripts/quality/check_logging_style.py
```

Use drop scripts with `--dry-run` before destructive schema work:

```bash
python scripts/bronze/drop_clickhouse.py --dry-run
python scripts/silver/drop_clickhouse.py --dry-run
python scripts/gold/drop_clickhouse_scenarios.py --dry-run
```

## SQL Layout

```text
clickhouse/
  bronze/
    00_create_database.sql
    01_*.sql ... 15_*.sql
    99_optimize_tables.sql
  silver/
    ddl/
      00_create_database.sql
      01_*.sql ... 08_*.sql
      99_all_tables.sql
    dml/
      01_*.sql ... 08_*.sql
  gold/
    00_create_database.sql
    01_create_scenario_tables.sql
    create_table_{entity}_{family}_{subfamily}.sql
    scenario/
      team/scenario_*.sql
      player/scenario_*.sql
    signal/
      sig_*.sql
```

Current Gold inventory:

- 48 scenario SQL transforms in `clickhouse/gold/scenario/{team,player}/`
- 344 signal SQL transforms in `clickhouse/gold/signal/`
- 344 signal catalog markdown files in `scripts/gold/signal/catalogs/`

Gold SQL jobs are executed through the generic runner in
`scripts/gold/run_sql_job.py` and shared helpers in `scripts/gold/sql_jobs.py`.
Legacy per-output Python runners may exist during migration, but new Gold work
should not add handwritten per-signal or per-scenario runner files.

## Python Layout

```text
src/
  scrapers/fotmob/        FotMob API fetchers and request behavior
  processors/bronze/      Bronze transformation wiring
  processors/silver/      Silver transformation wiring
  processors/gold/        Gold transformation wiring
  storage/bronze/         Bronze persistence
  storage/silver/         Silver persistence
  storage/gold/           Gold persistence
  storage/mongodb/        content catalog client/repositories
  utils/                  logging, contracts, alerts, metrics, health checks
scripts/                  operational CLI entry points
```

## MongoDB Content Catalog

Signal metadata is authored in markdown frontmatter under
`scripts/gold/signal/catalogs/*.md`. The sync script stores:

1. flattened metadata fields for fast querying;
2. the full `frontmatter` object for full-fidelity reuse;
3. the full markdown body in `markdown_body`;
4. the relative source file path in `source_path`.

Current required frontmatter keys:

- `signal_id`
- `status`
- `entity`
- `family`
- `subfamily`
- `grain`
- `row_identity`
- `asset_paths`

`row_identity` is the stable identity contract for one activated signal row and
is used to build deterministic activation IDs:

- team-grain rows should use: `match_id`, `triggered_side`
- player-grain rows should use: `match_id`, `triggered_player_id`, `triggered_team_id`

## Signal Activation IDs

DepthMark materializes deterministic signal activation IDs into
`gold.signal_activations`.

Creation flow:

1. DDL creates the activation table from
   `clickhouse/gold/create_table_signal_activations.sql`.
2. Gold signal SQL jobs populate `gold_signals.sig_*` tables.
3. `scripts/gold/activations/build_signal_activations.py` scans active signal
   catalogs and reads each catalog `row_identity`.
4. The script inserts one activation row per signal output row with:
   - `signal_instance_id = lower(hex(SHA256(concat('v1|', signal_id, '|', ...identity values))))`
   - `signal_id_version = 'v1'`
   - parsed signal metadata from `signal_id` pattern (`signal_prefix`, `signal_entity`,
     `signal_family`, `signal_subfamily`, `signal_name`, `signal_tags`)
5. `scripts/gold/activations/build_signal_activations_match.py` aggregates
   row-level activations into `gold.signal_activations_match` with one
   row per `match_id`, including `activated_signal_instance_ids`,
   `activated_signal_ids`, `activated_signal_entities`,
   `activated_signal_tags`, `activated_signal_names`,
   `total_signal_rows`, and `unique_signal_count`.
6. `scripts/gold/load_clickhouse_gold.py` runs both activation scripts after
   successful signal execution (`--part signals` or `--part all`).

## Operational Guarantees

1. Bronze loading includes DLQ fallback via `src/storage/dlq.py` for failed
   inserts and replay context.
2. Layer contracts are enforced at runtime by the Bronze, Silver, and Gold
   contract assertions.
3. Silver and Gold loaders support `--dry-run` planning mode.
4. Gold bulk loading supports `--part all|signals`; scenario bulk execution is disabled until re-enabled intentionally.
5. Standardized layer completion alerts are sent through
   `send_layer_completion_alert`.
6. Bronze runtime supports turnstile refresh automation through
   `scripts/refresh_turnstile.py`.
7. Bronze tables use `ReplacingMergeTree(inserted_at)` and can be compacted with
   `clickhouse/bronze/99_optimize_tables.sql`.

## Engineering Standards

1. SQL contains transformation and business logic; Python handles orchestration,
   execution, and reporting.
2. SQL files should be deterministic and rerunnable.
3. Keep naming stable: Silver SQL uses `NN_<entity>.sql`, Gold scenarios use
   `scenario_<name>.sql`, and Gold signals use `sig_<name>.sql`.
   Gold signal table DDL files use
   `create_table_{entity}_{family}_{subfamily}.sql`.
4. New or changed scenario work must update SQL, Gold scenario DDL, and
   `scripts/gold/scenario/SCENARIOS_CATALOG.md` when relevant.
5. New or changed signal work must update SQL, signal DDL, catalog
   markdown, and `scripts/gold/signal/catalogs/README.md` when relevant.

## Incident Handling

1. Identify the failing stage and SQL/script name from logs.
2. Re-run only the affected layer or date range when possible.
3. Run reconciliation and contract checks.
4. Inspect `data/dlq/` when insertion failures occur.
5. Use `scripts/refresh_turnstile.py` for token/cookie failures.

## Documentation Ownership

1. Keep `README.md` and `AGENTS.md` in the repository root.
2. Keep project-wide references in `docs/`.
3. Keep script layout and inventory in `scripts/README.md`.
4. Keep subsystem contracts next to the code they govern, such as
   `scripts/gold/scenario/SCENARIOS_CONTRACT.md` and
   `scripts/gold/signal/contracts/`.

When architecture boundaries, commands, or layer ownership change, update this
file in the same change.
