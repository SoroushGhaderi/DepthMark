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
  -> data/fotmob/historical/  completed-date Bronze files
  -> data/fotmob/live/        current-date Live snapshots
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
python3 scripts/orchestration/setup_clickhouse.py
python3 scripts/bronze/setup_clickhouse.py
python3 scripts/silver/setup_clickhouse.py
python3 scripts/gold/setup_clickhouse_gold.py
python3 scripts/gold/setup_clickhouse_gold.py --part scenarios
python3 scripts/gold/setup_clickhouse_gold.py --part signals
```

### Bronze

```bash
python3 scripts/bronze/scrape_fotmob.py 20251208
python3 scripts/bronze/scrape_fotmob.py --single-date 20251208
python3 scripts/bronze/scrape_fotmob.py --today
python3 scripts/bronze/scrape_fotmob.py --yesterday
python3 scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python3 scripts/bronze/sync_s3.py download --date 20251208 --dry-run
python3 scripts/bronze/load_clickhouse.py --date 20251208
python3 scripts/bronze/load_clickhouse.py --single-date 20251208
python3 scripts/bronze/load_clickhouse.py --full-history
python3 scripts/bronze/drop_clickhouse.py --dry-run
```

### Silver

```bash
python3 scripts/silver/load_clickhouse.py --date 20251208
python3 scripts/silver/load_clickhouse.py --month 202512 --dry-run
python3 scripts/silver/load_clickhouse.py --full-history --dry-run
python3 scripts/silver/drop_clickhouse.py --dry-run
```

### Gold

```bash
python3 scripts/gold/load_clickhouse_gold.py --date 20251208
python3 scripts/gold/load_clickhouse_gold.py --month 202512 --dry-run
python3 scripts/gold/load_clickhouse_gold.py --full-history --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part scenarios --dry-run
python3 scripts/gold/activations/build_signal_activations.py --full-history
python3 scripts/gold/activations/build_signal_activations.py --date 20251208 --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity player --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --full-history --kind signal --family shooting_goals --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance --dry-run
python3 scripts/gold/drop_clickhouse_scenarios.py --dry-run
```

### Orchestration, Quality, and Ops

```bash
python3 scripts/orchestration/pipeline.py 20251208
python3 scripts/orchestration/pipeline.py --date 20251208
python3 scripts/orchestration/pipeline.py --single-date 20251208
python3 scripts/orchestration/pipeline.py --full-history
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/quality/check_data_quality.py --month 202512 --strict
python3 scripts/quality/check_data_quality.py --full-history --strict
python3 scripts/quality/check_logging_style.py
python3 scripts/health_check.py --json
python3 scripts/ensure_directories.py
python3 scripts/refresh_turnstile.py
python3 scripts/mongodb/init_indexes.py
python3 scripts/mongodb/sync_signal_catalogs.py --dry-run
```

## Pipeline Runbook

### Standard Runs

```bash
python3 scripts/orchestration/pipeline.py 20251208
python3 scripts/orchestration/pipeline.py --single-date 20251208
python3 scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207
python3 scripts/orchestration/pipeline.py --month 202512
python3 scripts/orchestration/pipeline.py --full-history
```

### Partial Runs

```bash
python3 scripts/orchestration/pipeline.py 20251208 --bronze-only
python3 scripts/orchestration/pipeline.py 20251208 --silver-only
python3 scripts/orchestration/pipeline.py 20251208 --gold-only
python3 scripts/orchestration/pipeline.py 20251208 --skip-bronze
```

### Recommended Preflight and Validation

```bash
python3 scripts/health_check.py --json
python3 scripts/silver/load_clickhouse.py --date 20251208 --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/quality/check_logging_style.py
```

### Unified Warehouse Quality

`scripts/quality/check_data_quality.py` is the canonical read-only quality entry
point. Python discovers contracts, applies scope, executes SQL, and reports;
ClickHouse SQL performs duplicate grouping and identity-set reconciliation.

- Duplicate checks cover all existing `bronze.*` and `silver.*` tables using
  `BRONZE_REQUIRED_KEYS` and `SILVER_TABLE_KEYS`, all scenario tables using
  their DDL `ORDER BY` identity, all signal tables using catalog
  `row_identity`, and `gold.signal_activations` using `signal_instance_id`.
- Logical duplicates are calculated from `FINAL` and are strict failures.
  Multiple raw physical versions are reported separately as non-failing
  `ReplacingMergeTree` merge/storage diagnostics.
- A discovered table with no declared identity, or with absent identity
  columns, is reported as not validated. This is visible but is not itself a
  strict failure.
- Reconciliation is bidirectional for the eight Silver outputs: it compares
  distinct eligible Bronze and Silver identities and reports missing and
  unexpected keys. The personnel mapping combines starters, substitutes, and
  coaches exactly as the Silver DML does.
- Gold never participates in cross-layer reconciliation. Its scenarios,
  signals, and activations intentionally transform, filter, and change grain;
  only logical duplicate identity checks and physical-version diagnostics are
  meaningful there.
- `--date`, `--month`, and `--full-history` are supported. Omitting a scope is a
  backward-compatible full-history check. `--strict` returns `1` for logical
  duplicates or reconciliation mismatches; a clean/non-strict completed run
  returns `0`, argument errors return `2`, and connection/query failures return
  `1`.

Useful selections:

```bash
python3 scripts/quality/check_data_quality.py --date 20251208 --layers bronze,silver --strict
python3 scripts/quality/check_data_quality.py --month 202512 --layers gold --strict
python3 scripts/quality/check_data_quality.py --full-history --reconciliation-checks shot,card
python3 scripts/quality/check_bronze_to_silver_reconciliation.py --strict  # compatibility alias
```

Use drop scripts with `--dry-run` before destructive schema work:

```bash
python3 scripts/bronze/drop_clickhouse.py --dry-run
python3 scripts/silver/drop_clickhouse.py --dry-run
python3 scripts/gold/drop_clickhouse_scenarios.py --dry-run
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
`scripts/gold/run_gold_sql_jobs.py` and shared helpers in
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
  services/clickhouse_scoped_replace.py  staged derived-table replacement
  services/gold/          Gold application service and shared SQL job helpers
  services/silver/        Silver application service
  services/warehouse_scope.py  validated date/month/full-history scopes
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

Scoped derived loads share this function flow:

1. CLI parsers call `execution_scope_from_args()` to create a required
   `WarehouseExecutionScope`.
2. Silver and Gold services convert SQL files into `ScopedSqlJob` values with a
   target table and match-date expression.
3. `ScopedReplacementBatch.run()` stages all selected jobs before any commit.
4. `_prepare()` redirects each `INSERT INTO` to a calculation table, builds the
   requested monthly replacement, and validates row counts.
5. `_commit()` uses `REPLACE PARTITION` for date/month scopes or
   `EXCHANGE TABLES` for full history.

Date scopes reconstruct the containing month by copying unaffected target rows
and taking the selected date from the fresh calculation. A staging failure
leaves targets unchanged. ClickHouse has no cross-table transaction, so a
commit failure can be partial; rerunning the identical scope converges safely.

Programmatic callers must pass the scope explicitly:

| Previous call shape | Current call shape |
| --- | --- |
| `SilverService.run(dry_run=...)` | `SilverService.run(scope=scope, dry_run=...)` |
| `SilverService.run_load_jobs(dry_run=...)` | `SilverService.run_load_jobs(scope, dry_run=...)` |
| `GoldService.run(part=..., dry_run=...)` | `GoldService.run(scope=scope, part=..., dry_run=...)` |
| `GoldService.run_selected_jobs(part, dry_run=...)` | `GoldService.run_selected_jobs(part, scope, dry_run=...)` |
| `execute_gold_sql_job(client, job, dry_run=..., log=...)` | `execute_gold_sql_job(client, job, scope=scope, dry_run=..., log=...)` |
| `build_signal_activations(..., dry_run=...)` | `build_signal_activations(..., scope=scope, dry_run=...)` |

Construct `scope` with `WarehouseExecutionScope.for_date("20251208")`,
`WarehouseExecutionScope.for_month("202512")`, or
`WarehouseExecutionScope.full_history()`. CLI code should use
`execution_scope_from_args()` instead of constructing scopes manually.

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
   calculates the serving rows with
   `clickhouse/gold/dml/activations/signal_activation_final_insert.sql`, and
   commits only the requested output scope.
5. Each staged/serving row carries:
   - `signal_instance_id = lower(hex(SHA256(concat('v1|', signal_id, '|', ...identity values))))`
   - `signal_id_version = 'v1'`
   - parsed signal metadata from `signal_id` pattern (`signal_prefix`, `signal_entity`,
     `signal_family`, `signal_subfamily`, `signal_name`, `signal_tags`)
   - common fixture, league, venue, team, and player context when available
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
docker compose exec depthmark-clickhouse clickhouse-client --multiquery < clickhouse/gold/ddl/create_table_signal_activations.sql
python3 scripts/gold/activations/build_signal_activations.py --full-history
```

The builder requires `--date`, `--month`, or `--full-history`. Date and month
runs replace only their output partition scope; explicit full-history uses a
staged whole-table exchange. ADR 0018 supersedes ADR 0011 for scoped runs.

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
9. Historical scraping writes beneath `data/fotmob/historical/` and compresses
   each complete local date into
   `historical/matches/YYYYMMDD/YYYYMMDD_matches.tar`; incomplete dates remain
   uncompressed for safe resumption.
10. `--today` writes refreshable, uncompressed snapshots beneath
    `data/fotmob/live/`. Live data is not loaded, synchronized to S3, or promoted
    into Historical storage automatically.

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
   `scripts/gold/scenario/SCENARIOS_CATALOG.md` when relevant.
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
