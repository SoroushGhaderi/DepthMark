# Scripts Layout

This file is a compact inventory of script locations and supported entry points.
For the project-wide command surface and runbook, use `../docs/DEVELOPMENT_ARCHITECTURE.md`.
For script behavior rules, naming/style handwriting, function design, and update policy, use `../docs/SCRIPTS_CONTRACT.md`.

Scripts are the supported operational entry points. They may delegate reusable
workflow coordination to stable services under `src/`, but they must preserve
their CLI behavior, dry-run semantics, and exit-code contract.

## Supported Entry Points

Use these paths for new automation and daily runs:

- `scripts/bronze/scrape_fotmob.py`
- `scripts/bronze/sync_s3.py`
- `scripts/bronze/load_clickhouse.py`
- `scripts/bronze/drop_clickhouse.py`
- `scripts/bronze/setup_clickhouse.py`
- `scripts/silver/load_clickhouse.py`
- `scripts/silver/drop_clickhouse.py`
- `scripts/silver/setup_clickhouse.py`
- `scripts/gold/load_clickhouse_gold.py`
- `scripts/gold/run_gold_sql_jobs.py`
- `scripts/gold/drop_clickhouse_scenarios.py`
- `scripts/gold/setup_clickhouse_gold.py`
- `scripts/orchestration/pipeline.py`
- `scripts/orchestration/setup_clickhouse.py`
- `scripts/maintenance/optimize_clickhouse.py`

### Single-Date Mode

All layer scripts accept `--single-date YYYYMMDD` as a named alternative to
existing date arguments. This provides a consistent interface across the
pipeline:

```bash
python3 scripts/orchestration/pipeline.py --single-date 20251208
python3 scripts/orchestration/pipeline.py --date 20251208
python3 scripts/bronze/scrape_fotmob.py --single-date 20251208
python3 scripts/bronze/scrape_fotmob.py --today
python3 scripts/bronze/scrape_fotmob.py --yesterday
python3 scripts/bronze/sync_s3.py upload --single-date 20251208
python3 scripts/bronze/sync_s3.py download --single-date 20251208
python3 scripts/bronze/load_clickhouse.py --single-date 20251208
python3 scripts/silver/load_clickhouse.py --single-date 20251208
python3 scripts/gold/load_clickhouse_gold.py --single-date 20251208
```

FotMob scraping has two filesystem aspects beneath the configured Bronze root:
Historical (`data/fotmob/historical/`) and Live (`data/fotmob/live/`). Explicit
dates, ranges, `--month`, and `--yesterday` write Historical data. `--today`
always refreshes Live listings and match payloads and never compresses them.
Historical selectors reject today and future dates; a current-month scope ends
at yesterday.

### Warehouse Scope Modes

Silver and Gold commands require an explicit output scope:

```bash
python3 scripts/silver/load_clickhouse.py --date 20251208 --dry-run
python3 scripts/silver/load_clickhouse.py --month 202512 --dry-run
python3 scripts/silver/load_clickhouse.py --full-history --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run
python3 scripts/gold/load_clickhouse_gold.py --month 202512 --dry-run
python3 scripts/gold/load_clickhouse_gold.py --full-history --dry-run
```

The generic Gold SQL runner and activation builder use the same selectors.
`scripts/bronze/load_clickhouse.py --full-history` discovers all dates in
Historical storage and never reads Live storage. Pipeline `--full-history`
skips scraping and runs the remaining selected warehouse stages.

### Dry-Run Support

- `scripts/bronze/sync_s3.py upload --date 20251208 --dry-run`
- `scripts/bronze/sync_s3.py download --date 20251208 --dry-run`
- `scripts/silver/load_clickhouse.py --date 20251208 --dry-run`
- `scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run`
- `scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity player --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --full-history --kind signal --family shooting_goals --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance --dry-run`

### Bronze S3 Sync

`scripts/bronze/sync_s3.py` is the only supported S3 transfer entry point.
Scraping and `scripts/orchestration/pipeline.py` never invoke it. Both `upload`
and `download` require an explicit `--date`, `--start-date/--end-date`,
`--month`, or `--all` scope. Existing destinations are protected unless
`--force` is supplied; uploads reject incomplete dates unless
`--allow-incomplete` is explicitly supplied.

## Operational Utility Scripts

- `scripts/ensure_directories.py`
- `scripts/health_check.py`
- `scripts/refresh_turnstile.py`
- `scripts/maintenance/optimize_clickhouse.py`
- `scripts/mongodb/init_indexes.py`
- `scripts/mongodb/sync_signal_catalogs.py`

`scripts/maintenance/optimize_clickhouse.py` is explicit ClickHouse storage
maintenance. It is dry-run by default and only mutates tables with `--execute`:

```bash
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze --table general --execute
python3 scripts/maintenance/optimize_clickhouse.py --layer gold --database gold_signals
```
- `scripts/gold/activations/build_signal_activations.py`

## Quality Check Scripts

- `scripts/quality/check_data_quality.py` — canonical read-only duplicate check
  across Bronze, Silver, and Gold plus Bronze-to-Silver reconciliation. Supports
  date, month, and full-history scopes, layer/check selection, samples, and
  strict exits.
- `scripts/quality/check_bronze_to_silver_reconciliation.py`
  — compatibility alias for Bronze/Silver duplicate checks and reconciliation.
- `scripts/quality/check_logging_style.py`

```bash
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/quality/check_data_quality.py --month 202512 --layers gold --strict
python3 scripts/quality/check_data_quality.py --full-history --strict
python3 scripts/quality/check_bronze_to_silver_reconciliation.py --strict
```

Gold duplicate checking uses scenario DDL identities, signal catalog
`row_identity`, and activation `signal_instance_id`. Gold is never reconciled
to Bronze or Silver because its outputs have intentionally different filters,
business logic, and grains.

Logical duplicate identities are evaluated with `FINAL` and participate in
strict failure. Raw physical versions awaiting `ReplacingMergeTree` merges are
reported as non-failing operational diagnostics.

## Scenario Scripts

Scenario SQL jobs are executed by `scripts/gold/run_gold_sql_jobs.py`.
Do not add handwritten `scripts/gold/scenario/scenario_*.py` runner files.
Scenario standards are defined in `scripts/gold/scenario/SCENARIOS_CONTRACT.md`.

Current inventory: 48 matching SQL transforms.

- SQL files: `clickhouse/gold/dml/scenarios/{team,player}/scenario_*.sql`
- Catalog: `scripts/gold/scenario/SCENARIOS_CATALOG.md`

## Signal Scripts

Signal SQL jobs are discovered and executed through `scripts/gold/run_gold_sql_jobs.py`
and shared helpers in `src/services/gold/gold_dml_runner.py`. Do not add handwritten
per-signal runner files. Use `--id` for one exact signal; use `--entity` or
`--family` as separate signal batch selectors such as `--entity player` or
`--family shooting_goals`.
Every execution also requires `--date`, `--month`, or `--full-history`.
After successful signal SQL execution, the loader runs `scripts/gold/activations/build_signal_activations.py`
to populate deterministic per-match activation IDs in `gold.signal_activations`.
The builder stages rows in ephemeral `gold.signal_activations_stage`, then runs
`clickhouse/gold/dml/activations/signal_activation_final_insert.sql` into a
calculation table and commits the same output scope as the signal run. Signal
SQL failures skip activation replacement until signals succeed or the builder
is rerun with the same scope. The activation ID key uses each signal catalog
`row_identity` definition.

Current inventory: 344 matching SQL transforms and 344 matching markdown catalogs.

- SQL files: `clickhouse/gold/dml/signals/*/sig_*.sql`
- Contracts: `scripts/gold/signal/contracts/`

## Signal Catalogs

Per-signal docs live in `scripts/gold/signal/catalogs/` and include tactical logic plus output schema tables:

- `scripts/gold/signal/catalogs/README.md`
- `scripts/gold/signal/catalogs/sig_*.md`

Before deep review of many full catalogs, use a token-efficient manual flow:

- read only `catalogs/README.md` table first
- shortlist max 8 active candidates by `entity/family/subfamily` (+ `grain` when available)
- read only frontmatter + Purpose + Trigger for shortlisted candidates
