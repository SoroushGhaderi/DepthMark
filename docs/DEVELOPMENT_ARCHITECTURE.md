# DepthMark Development Architecture

This is the project-wide reference for how DepthMark is built and operated. It
owns architecture, layer boundaries, command surface, and runbook guidance.
Script coding standards live in `SCRIPTS_CONTRACT.md`.

## Scope

DepthMark is a FotMob-only medallion pipeline:

1. Bronze stores raw FotMob payloads on disk and loads raw tables into ClickHouse.
2. Silver builds cleaned, typed, reusable analytical tables in ClickHouse.
3. Gold materializes scenario and signal outputs in ClickHouse for product and BI
   use, plus shared activation metadata for product consumption.

```text
FotMob API
  -> data/fotmob/          raw Bronze files
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
  -> gold.*                shared Gold metadata and activation tables
```

## Layer Boundaries

1. Bronze is the only filesystem-backed data layer.
2. Silver and Gold are ClickHouse-only layers.
3. Bronze preserves source fidelity with minimal transformation.
4. Silver standardizes keys, types, and reusable entities.
5. Gold produces downstream-ready scenario and signal tables.
6. Warehouse tables must be schema-qualified as `bronze.*`, `silver.*`,
   `gold_scenarios.*`, `gold_signals.*`, or shared Gold metadata tables in
   `gold.*`.

## Gold Namespaces

DepthMark uses separate Gold ClickHouse databases for separate ownership
boundaries:

- `gold_scenarios.*`: scenario output tables.
- `gold_signals.*`: signal output tables.
- `gold.*`: shared Gold metadata and serving tables such as
  `gold.signal_activations`.

Scenario SQL targets `gold_scenarios.scenario_*`. Scenario bulk execution is
enabled in `scripts/gold/load_clickhouse_gold.py` and can be run with
`--part all` or `--part scenarios`. See
`docs/adr/0004-keep-gold-scenario-bulk-disabled-until-validated.md`.

## Credential Policy

The tracked Docker Compose files are local-development manifests. They may keep
local defaults for fast bootstrap, but production deployments must use separate
deployment configuration, non-default secrets, and `DEPTHMARK_ENV=production`.

Use `DEPTHMARK_ENV=local` only for local Docker development. ClickHouse setup
rejects empty, placeholder, or known local-development passwords outside local
development and limits the empty-password `default` user bootstrap path to local
development. See
`docs/adr/0005-local-dev-credentials-vs-production-policy.md`.

## Canonical Command Surface

Use these paths for documentation, automation, and daily operations. When using
the local Docker stack, prefix commands with
`docker compose exec depthmark-scraper` (see
`docs/data-flow/infrastructure.md` for setup and lifecycle).

### Setup

```bash
python scripts/orchestration/setup_clickhouse.py
python scripts/bronze/setup_clickhouse.py
python scripts/silver/setup_clickhouse.py
python scripts/gold/setup_clickhouse_gold.py
python scripts/gold/setup_clickhouse_gold.py --part scenarios
python scripts/gold/setup_clickhouse_gold.py --part signals
```

### Bronze

```bash
python scripts/bronze/scrape_fotmob.py 20251208
python scripts/bronze/scrape_fotmob.py --single-date 20251208
python scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python scripts/bronze/sync_s3.py download --date 20251208 --dry-run
python scripts/bronze/load_clickhouse.py --date 20251208
python scripts/bronze/load_clickhouse.py --single-date 20251208
python scripts/bronze/drop_clickhouse.py --dry-run
```

### Silver

```bash
python scripts/silver/load_clickhouse.py
python scripts/silver/load_clickhouse.py --single-date 20251208
python scripts/silver/load_clickhouse.py --dry-run
python scripts/silver/drop_clickhouse.py --dry-run
```

### Gold

```bash
python scripts/gold/load_clickhouse_gold.py
python scripts/gold/load_clickhouse_gold.py --single-date 20251208
python scripts/gold/load_clickhouse_gold.py --dry-run
python scripts/gold/load_clickhouse_gold.py --part signals --dry-run
python scripts/gold/load_clickhouse_gold.py --part scenarios --dry-run
python scripts/gold/activations/build_signal_activations.py
python scripts/gold/activations/build_signal_activations.py --dry-run
python scripts/gold/run_sql_job.py --dry-run
python scripts/gold/run_sql_job.py --kind signal --dry-run
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run
python scripts/gold/run_sql_job.py --kind signal --entity player --dry-run
python scripts/gold/run_sql_job.py --kind signal --family shooting_goals --dry-run
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance --dry-run
python scripts/gold/drop_clickhouse_scenarios.py --dry-run
```

### Orchestration, Quality, and Ops

```bash
python scripts/orchestration/pipeline.py 20251208
python scripts/orchestration/pipeline.py --single-date 20251208
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
python scripts/orchestration/pipeline.py --single-date 20251208
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
    ddl/
      00_create_database.sql
      01_create_scenario_tables.sql
      create_table_signal_activations.sql
      signals/
        match/create_table_match_*.sql
        team/create_table_team_*.sql
        player/create_table_player_*.sql
      activations/
        create_table_signal_activations_stage.sql
    dml/
      scenarios/
        team/scenario_*.sql
        player/scenario_*.sql
      signals/
        match/sig_match_*.sql
        team/sig_team_*.sql
        player/sig_player_*.sql
      activations/
        signal_activation_final_insert.sql
```

Current Gold inventory:

- 48 scenario SQL transforms in `clickhouse/gold/dml/scenarios/{team,player}/`
  (23 team/match-grain, 25 player-grain)
- 344 signal SQL transforms in `clickhouse/gold/dml/signals/{match,team,player}/`
- 344 signal catalog markdown files in `scripts/gold/signal/catalogs/`
- 1 shared activation serving table in `gold.signal_activations`

Gold SQL jobs are executed through the generic runner in
`scripts/gold/run_sql_job.py` and shared helpers in
`src/services/gold/gold_dml_runner.py`. Do not add handwritten per-signal or
per-scenario runner files. Omit `--kind` to run all scenario and signal SQL jobs
through the generic runner, or use `--kind scenario` / `--kind signal` to select
one Gold output kind. Jobs can be selected exactly by `--id`; signal jobs can
also be filtered by `--entity {match,player,team}` or by `--family`. Do not
combine `--entity` and `--family`; treat them as separate signal batch selectors.

## Python Layout

```text
src/
  services/bronze/        Bronze loading and independent S3 sync services
  services/gold/          Gold application service and shared SQL job helpers
  services/silver/        Silver application service
  scrapers/fotmob/        FotMob API fetchers and request behavior
  processors/bronze/      Bronze transformation wiring
  storage/bronze/         Bronze persistence
  storage/s3_client.py    Low-level S3-compatible object operations
  storage/mongodb/        content catalog client/repositories
  utils/                  logging, contracts, alerts, metrics, health checks
scripts/                  operational CLI entry points
```

Scripts remain the documented operational boundary, but reusable workflow
coordination lives in layer-specific application services under `src/services/`
behind the same CLI entry points. Scripts keep CLI parsing, environment
bootstrap, command compatibility, and exit-code translation. Application
services may coordinate SQL discovery/execution, client setup, contract checks,
validation, alerts, and deterministic summaries. They must not become a home for
Silver or Gold analytical logic, which remains in ClickHouse SQL.

## MongoDB Content Catalog

Signal metadata is authored in markdown frontmatter under
`scripts/gold/signal/catalogs/*.md`. These markdown catalogs are the source of
truth for signal metadata; MongoDB is a synchronized serving/query copy. The sync
script stores:

1. flattened metadata fields for fast querying;
2. the full `frontmatter` object for full-fidelity reuse;
3. the full markdown body in `markdown_body`;
4. embedded SQL and runner source in `assets.sql.content` and
   `assets.runner.content`, with SHA-256 hashes and byte counts;
5. the relative source file path in `source_path`.

Current required frontmatter keys:

- `signal_id`
- `status`
- `entity`
- `family`
- `subfamily`
- `grain`
- `row_identity`
- `asset_paths`

Catalog `asset_paths.table` values must use the signal output namespace
`gold_signals.<signal_id>`. Shared signal activation metadata remains under
`gold.*`.

`row_identity` is the stable identity contract for one activated signal row and
is used to build deterministic activation IDs:

- team-grain rows should use: `match_id`, `triggered_side`
- player-grain rows should use: `match_id`, `triggered_player_id`, `triggered_team_id`

## Signal Activation IDs

DepthMark materializes deterministic signal activation IDs into each
`gold_signals.sig_*` source table and into the serving table
`gold.signal_activations`.

Creation flow:

1. DDL creates the activation serving table from
   `clickhouse/gold/ddl/create_table_signal_activations.sql`.
2. Gold signal SQL jobs populate `gold_signals.sig_*` tables. Signal table DDL
   defines `signal_instance_id` with a deterministic `DEFAULT` expression based
   on the catalog `row_identity`, so existing signal INSERT SQL keeps its stable
   column list. Signal DDL drops and recreates derived `gold_signals.sig_*`
   tables for this contract; do not use `ALTER TABLE` to patch the
   `signal_instance_id` column in place.
3. `scripts/gold/activations/build_signal_activations.py` scans active signal
   catalogs and reads each catalog `row_identity`.
4. The builder stages one row per signal output in ephemeral
   `gold.signal_activations_stage` (DDL:
   `clickhouse/gold/ddl/activations/create_table_signal_activations_stage.sql`),
   then truncates and repopulates `gold.signal_activations` using
   `clickhouse/gold/dml/activations/signal_activation_final_insert.sql`.
5. Each staged/serving row carries:
   - `signal_instance_id = lower(hex(SHA256(concat('v1|', signal_id, '|', ...identity values))))`
   - `signal_id_version = 'v1'`
   - parsed signal metadata from `signal_id` pattern (`signal_prefix`, `signal_entity`,
     `signal_family`, `signal_subfamily`, `signal_name`, `signal_tags`)
   - common fixture/team/player context when available from the source signal
     table
   - source signal row details in `source_row_json` and `source_row_columns`
6. The same `gold.signal_activations` row also carries match-level summary
   fields that previously lived in `gold.signal_activations_match`, including
   `match_activation_instance_id`, `activated_signal_instance_ids`,
   `activated_signal_ids`, `activated_signal_entities`,
   `activated_signal_tags`, `activated_signal_names`, `total_signal_rows`, and
   `unique_signal_count`.
7. `scripts/gold/load_clickhouse_gold.py` runs the activation builder after
   successful signal execution (`--part signals` or `--part all`). Signal SQL
   failures skip activation rebuild until signals succeed or the builder is
   rerun manually.

To drop, recreate, and repopulate `gold.signal_activations` from scratch:

```bash
clickhouse-client --multiquery < clickhouse/gold/ddl/create_table_signal_activations.sql
python scripts/gold/activations/build_signal_activations.py
```

Activation rebuilds are full-table rebuilds: rebuild
`gold.signal_activations` from all active signal catalogs and signal output
tables.
Do not add incremental, date-scoped, or partition-scoped activation rebuilds
until a later ADR defines partition-safe replacement semantics for upstream
signal outputs and the derived activation serving table.

`signal_id_version` versions the activation identity scheme, not the authored
signal definition. Keep it stable across reruns and ordinary signal SQL/catalog
changes when `signal_id` and `row_identity` values are unchanged. Change the
version only for deliberate activation identity contract migrations, such as
hash serialization, null handling, required identity fields, or the meaning of
one activation row.

## Operational Guarantees

1. Bronze loading includes DLQ fallback via `src/storage/dlq.py` for failed
   inserts and replay context.
2. Layer contracts are enforced at runtime by the Bronze, Silver, and Gold
   contract assertions.
3. Silver and Gold loaders support `--dry-run` planning mode.
4. Gold bulk loading supports `--part all|signals|scenarios`. Scenario bulk
   execution is enabled and follows the same failure pattern as signals.
5. Standardized layer completion alerts are sent through
   `send_layer_completion_alert`.
6. Bronze runtime supports turnstile refresh automation through
   `scripts/refresh_turnstile.py`.
7. Bronze tables use `ReplacingMergeTree(inserted_at)` and can be compacted with
   `clickhouse/bronze/99_optimize_tables.sql`.
8. Bronze S3 upload/download is operator-invoked through
   `scripts/bronze/sync_s3.py`; neither scraping nor the pipeline invokes it.

## Engineering Standards

1. SQL contains transformation and business logic; Python handles orchestration,
   execution, and reporting.
2. SQL files should be deterministic and rerunnable.
3. Stable application services under `src/` sit behind script entry points and
   preserve the existing command surface.
4. Keep naming stable: Silver SQL uses `NN_<entity>.sql`, Gold scenarios use
   `scenario_<name>.sql`, and Gold signals use `sig_<name>.sql`.
   Gold signal table DDL files use
   `create_table_{entity}_{family}_{subfamily}.sql`.
5. New or changed scenario work must update SQL, Gold scenario DDL, and
   `scripts/gold/scenario/scenarios_catalog.md` when relevant.
6. New or changed signal work must update SQL, signal DDL, catalog
   markdown, and `scripts/gold/signal/catalogs/README.md` when relevant.

## Incident Handling

1. Identify the failing stage and SQL/script name from logs.
2. Re-run only the affected layer or date range when possible.
3. Run reconciliation and contract checks.
4. Inspect `data/dlq/` when insertion failures occur.
5. Use `scripts/refresh_turnstile.py` for token/cookie failures.

## Documentation Ownership

1. Keep `README.md` (project overview and documentation index) and `AGENTS.md`
   in the repository root.
2. Keep project-wide references, runbooks, and operational guidance in `docs/`.
3. Keep script layout and inventory in `scripts/README.md`.
4. Keep subsystem contracts next to the code they govern, such as
   `scripts/gold/scenario/SCENARIOS_CONTRACT.md` and
   `scripts/gold/signal/contracts/`.
5. Keep the source of truth for data flow and system diagrams in
   `docs/data-flow/`. Update `data-flow/` in the same change when layer
   boundaries, scripts, SQL jobs, or infrastructure change.

When architecture boundaries, commands, or layer ownership change, update this
file in the same change.
