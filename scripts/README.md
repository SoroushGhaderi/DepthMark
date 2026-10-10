# Scripts Layout

This file is a compact inventory of script locations and supported entry points.
For the project-wide command surface and runbook, use `../docs/DEVELOPMENT_ARCHITECTURE.md`.
For script behavior rules, naming/style handwriting, function design, and update policy, use `../docs/SCRIPTS_CONTRACT.md`.

Scripts are the supported operational entry points. They may delegate reusable
workflow coordination to source-owned or warehouse modules under `src/`, but
they must preserve their CLI behavior, dry-run semantics, and exit-code contract.

Canonical source workflow filenames follow
`<verb>_<source>[_<layer-or-entity>].py`. The same grammar is used by the
package CLI with hyphens. Symmetry applies to naming, not to phase count:
Oddspedia keeps its real discovery and prioritization phases, while FotMob does
not gain artificial equivalents. The source-neutral `report_scraping.py` is an
intentional utility exception: one report interface selects explicit source
adapters through `--source`.

## Supported Entry Points

Use these paths for new automation and daily runs:

- `scripts/bronze/scrape_fotmob.py`
- `scripts/bronze/sync_s3.py`
- `scripts/bronze/load_fotmob_bronze.py`
- `scripts/bronze/drop_clickhouse.py`
- `scripts/bronze/setup_clickhouse.py`
- `scripts/silver/load_fotmob_silver.py`
- `scripts/silver/drop_clickhouse.py`
- `scripts/silver/setup_clickhouse.py`
- `scripts/gold/load_fotmob_gold.py`
- `scripts/gold/run_gold_sql_jobs.py`
- `scripts/gold/drop_clickhouse_scenarios.py`
- `scripts/gold/setup_clickhouse_gold.py`
- `scripts/orchestration/run_fotmob_pipeline.py`
- `scripts/orchestration/setup_fotmob_warehouse.py`
- `scripts/report_scraping.py`
- `scripts/maintenance/optimize_clickhouse.py`
- `scripts/maintenance/recreate_clickhouse_tables.py`
- `scripts/oddspedia/discover_oddspedia_events.py`
- `scripts/oddspedia/prioritize_oddspedia_events.py`
- `scripts/oddspedia/scrape_oddspedia_matches.py`
- `scripts/oddspedia/run_oddspedia_pipeline.py`
- `scripts/oddspedia/setup_oddspedia_warehouse.py`
- `scripts/oddspedia/load_oddspedia_bronze.py`
- `scripts/oddspedia/resolve_oddspedia_events.py`

Existing generic or earlier phase filenames remain executable compatibility
adapters and emit a replacement warning. This includes the former FotMob
load/setup/pipeline paths and the former Oddspedia phase, umbrella,
ClickHouse-named, and resolution paths. Do not use compatibility paths in new
automation.

The installed package command exposes the same canonical surface, for example:

```bash
depthmark scrape-fotmob --today
depthmark load-fotmob-bronze --date 20251208 --dry-run
depthmark run-fotmob-pipeline --date 20251208
depthmark run-oddspedia-pipeline --date 20260301 --silver-reference-window-ready
depthmark report-scraping --date 20260301
```

### Compatibility Migration

The adapters below remain executable, but new callers must use the canonical
path on the right.

| Compatibility path | Canonical path |
| --- | --- |
| `scripts/bronze/load_clickhouse.py` | `scripts/bronze/load_fotmob_bronze.py` |
| `scripts/silver/load_clickhouse.py` | `scripts/silver/load_fotmob_silver.py` |
| `scripts/gold/load_clickhouse_gold.py` | `scripts/gold/load_fotmob_gold.py` |
| `scripts/orchestration/pipeline.py` | `scripts/orchestration/run_fotmob_pipeline.py` |
| `scripts/orchestration/setup_clickhouse.py` | `scripts/orchestration/setup_fotmob_warehouse.py` |
| `scripts/oddspedia/discover_events.py` | `scripts/oddspedia/discover_oddspedia_events.py` |
| `scripts/oddspedia/prioritize_events.py` | `scripts/oddspedia/prioritize_oddspedia_events.py` |
| `scripts/oddspedia/scrape_matches.py` | `scripts/oddspedia/scrape_oddspedia_matches.py` |
| `scripts/oddspedia/run_pipeline.py` | `scripts/oddspedia/run_oddspedia_pipeline.py` |
| `scripts/oddspedia/status_oddspedia.py` | `scripts/report_scraping.py --source oddspedia --format summary` |
| `scripts/oddspedia/report_oddspedia.py` | `scripts/report_scraping.py --source oddspedia --format markdown` |
| `scripts/oddspedia/status.py` | `scripts/report_scraping.py --source oddspedia --format summary` |
| `scripts/oddspedia/report.py` | `scripts/report_scraping.py --source oddspedia --format markdown` |
| `scripts/oddspedia/setup_warehouse.py` | `scripts/oddspedia/setup_oddspedia_warehouse.py` |
| `scripts/oddspedia/load_bronze.py` | `scripts/oddspedia/load_oddspedia_bronze.py` |
| `scripts/oddspedia/resolve_events.py` | `scripts/oddspedia/resolve_oddspedia_events.py` |

The older Oddspedia umbrella paths (`events.py` and `football.py`) and
ClickHouse-named paths (`setup_clickhouse.py`, `load_clickhouse.py`, and
`resolve_matches.py`) are also adapters. Choose the corresponding canonical
phase from the table above.

Package aliases such as `depthmark scrape`, `depthmark load`,
`depthmark pipeline`, `depthmark setup-clickhouse`, and the earlier
`depthmark oddspedia-*` spellings remain available with warnings. Their
canonical replacements use the command examples above and the complete
registry in `src/cli.py`.

### Scraping Reports

One command owns status and reporting for both scraping services:

```bash
python3 scripts/report_scraping.py --date 20260301
python3 scripts/report_scraping.py --source fotmob --month 202608
python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format markdown
python3 scripts/report_scraping.py --date 20260301 --format json --output reports/scraping.json
python3 scripts/report_scraping.py --date 20260301 --fail-on-attention
```

`--source` accepts `all` (the default), `fotmob`, or `oddspedia`. Date and
month are mutually exclusive; no scope means today, and a current month stops
at today. `summary`, `markdown`, and `json` are renderings of the same common
contract. Successful observation exits `0` even when work remains;
`--fail-on-attention` is the opt-in CI/cron gate. Unless `--output` is supplied,
the command performs no writes and never creates a scraper run log or date
lock.

### Single-Date Mode

All layer scripts accept `--single-date YYYYMMDD` as a named alternative to
existing date arguments. This provides a consistent interface across the
pipeline:

```bash
python3 scripts/orchestration/run_fotmob_pipeline.py --single-date 20251208
python3 scripts/orchestration/run_fotmob_pipeline.py --date 20251208
python3 scripts/bronze/scrape_fotmob.py --single-date 20251208
python3 scripts/bronze/scrape_fotmob.py --today
python3 scripts/bronze/scrape_fotmob.py --yesterday
python3 scripts/bronze/sync_s3.py upload --single-date 20251208
python3 scripts/bronze/sync_s3.py download --single-date 20251208
python3 scripts/bronze/load_fotmob_bronze.py --single-date 20251208
python3 scripts/silver/load_fotmob_silver.py --single-date 20251208
python3 scripts/gold/load_fotmob_gold.py --single-date 20251208
```

FotMob scraping has two filesystem aspects beneath the configured Bronze root:
Historical (`data/fotmob/historical/`) and Live (`data/fotmob/live/`). Explicit
dates, ranges, `--month`, and `--yesterday` write Historical data. `--today`
always refreshes Live listings and match payloads and never compresses them.
Historical selectors reject today and future dates; a current-month scope ends
at yesterday.

Oddspedia uses the same local aspect convention beneath `data/oddspedia/`.
Its default current-date command writes refreshable Live artifacts; explicit
completed dates and completed portions of a month write Historical artifacts.
Both sources use `{historical|live}/{artifact-type}/YYYYMMDD/`; see
[`../docs/data-flow/source-artifact-storage.md`](../docs/data-flow/source-artifact-storage.md)
for exact files and the legacy-layout migration note.

### Warehouse Scope Modes

Silver and Gold commands require an explicit output scope:

```bash
python3 scripts/silver/load_fotmob_silver.py --date 20251208 --dry-run
python3 scripts/silver/load_fotmob_silver.py --month 202512 --dry-run
python3 scripts/silver/load_fotmob_silver.py --full-history --dry-run
python3 scripts/gold/load_fotmob_gold.py --date 20251208 --dry-run
python3 scripts/gold/load_fotmob_gold.py --month 202512 --dry-run
python3 scripts/gold/load_fotmob_gold.py --full-history --dry-run
```

The generic Gold SQL runner and activation builder use the same selectors.
`scripts/bronze/load_fotmob_bronze.py --full-history` discovers all dates in
Historical storage and never reads Live storage. Pipeline `--full-history`
skips scraping and runs the remaining selected warehouse stages.

### Oddspedia Source Pipeline

Oddspedia commands are source-specific and do not run through
`scripts/orchestration/run_fotmob_pipeline.py`. The event-intake command supports
discovery, links-layer priority generation, and priority-selected scraping, or
`run` for all three phases. Load its Historical artifacts into
`oddspedia_bronze.*`, then build Oddspedia Silver outputs, including the
read-only relationship to the FotMob `silver.match` reference. Oddspedia Gold
will use its own source-qualified execution surface; the FotMob Gold commands
below are not a substitute.

```bash
python3 scripts/oddspedia/discover_oddspedia_events.py --date 20260301
python3 scripts/oddspedia/prioritize_oddspedia_events.py --date 20260301 --silver-reference-window-ready
python3 scripts/oddspedia/scrape_oddspedia_matches.py --date 20260301 --priority-tier lower
python3 scripts/oddspedia/run_oddspedia_pipeline.py --month 202603 --silver-reference-window-ready
python3 scripts/oddspedia/run_oddspedia_pipeline.py --start-date 20260301 --end-date 20260307 --silver-reference-window-ready
python3 scripts/report_scraping.py --source oddspedia --date 20260301
python3 scripts/report_scraping.py --source oddspedia --start-date 20260301 --end-date 20260307
python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format markdown --output docs/reports/oddspedia/20260301.md
python3 scripts/oddspedia/setup_oddspedia_warehouse.py --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --date 20260301 --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --month 202603 --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --start-date 20260301 --end-date 20260307 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --month 202603 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --start-date 20260301 --end-date 20260307 --dry-run
```

`--start-date/--end-date` is an inclusive scope on event-intake, reporting,
Bronze loading, and resolution. Both values are required together. Existing
`--date` and `--month` behavior remains supported; a current Oddspedia month
ends at the machine-local current date instead of rejecting the whole month.

Priority generation requires `--silver-reference-window-ready`; the command
then machine-verifies the three-day DepthMark Bronze/Silver fixture-ID
reconciliation before proceeding. It writes an auditable priority artifact
under `data/oddspedia/historical/link_priorities/`; standalone scraping
automatically creates or refreshes a missing or stale artifact. Discovery is
fail-closed, and a genuine empty date is represented as `no_events` in the
manifest. Accepted inventories carry a checksum; legacy or stale checksums
are refreshed before they can be admitted. A limited Vuex fallback is retained
as a rescrape candidate. All mutating date operations serialize through a lock
under `data/oddspedia/locks/`; dry runs do not create locks, and month commands
report non-zero when any date fails.

The external JSON contracts are `schemas/oddspedia/match_links.schema.json`,
`match_payload.schema.json`, and `scrape_manifest.schema.json`. They document
the existing top-level structures without adding envelopes or schema fields to
raw artifacts. Scraper persistence validates then writes the caller's mapping
or list unchanged. Manifest read-modify-write validates known state fields and
retains unknown compatible top-level fields.

`report_scraping.py --source oddspedia` separates the full discovered inventory
from the selected priority scope, summarizes payload-audit observations and
operational metrics, and estimates Bronze admission readiness. The compatibility
status/report scripts delegate to it and are not independent implementations.

`load_oddspedia_bronze.py` admits only an accepted discovery inventory with a
matching checksum, terminal scrape state, and accepted payload audits. It
stages the `event`, `match_payload`, and `market` facts, replaces the target
partition after validation, and records `staging`, `published`, or `failed` in
`oddspedia_bronze.load_status`. `resolve_oddspedia_events.py` reads only
published dates, so an incomplete or partially replaced Bronze batch cannot
enter Oddspedia Silver.

The event scripts use
`--retry-failed`, `--retry-incomplete`, and `--priority-tier` as canonical
operation selectors. The resolver uses the same
`--silver-reference-window-ready` assertion for persisted resolution outcomes;
`--depthmark-window-ready`, `--reference-window-complete`, `--priority`,
`--images`, `--json-logs`, and the value-based `--retry` option remain
compatibility aliases.

### Dry-Run Support

- `scripts/bronze/sync_s3.py upload --date 20251208 --dry-run`
- `scripts/bronze/sync_s3.py download --date 20251208 --dry-run`
- `scripts/bronze/load_fotmob_bronze.py --date 20251208 --dry-run`
- `scripts/bronze/load_fotmob_bronze.py --date 20251208 --truncate --dry-run`
- `scripts/silver/load_fotmob_silver.py --date 20251208 --dry-run`
- `scripts/gold/load_fotmob_gold.py --date 20251208 --dry-run`
- `scripts/gold/load_fotmob_gold.py --date 20251208 --part signals --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity player --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --full-history --kind signal --family shooting_goals --dry-run`
- `scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance --dry-run`

### Bronze S3 Sync

`scripts/bronze/sync_s3.py` is the only supported S3 transfer entry point.
Scraping and `scripts/orchestration/run_fotmob_pipeline.py` never invoke it.
Both `upload` and `download` require an explicit `--date`,
`--start-date/--end-date`, `--month`, or `--all` scope. Existing destinations
are protected unless `--force` is supplied; uploads reject incomplete dates
unless `--allow-incomplete` is explicitly supplied.

## Operational Utility Scripts

- `scripts/ensure_directories.py`
- `scripts/health_check.py`
- `scripts/refresh_turnstile.py`
- `scripts/maintenance/optimize_clickhouse.py`
- `scripts/maintenance/recreate_clickhouse_tables.py`
- `scripts/mongodb/init_indexes.py`
- `scripts/mongodb/sync_signal_catalogs.py`

`scripts/maintenance/optimize_clickhouse.py` is explicit ClickHouse storage
maintenance. It is dry-run by default and only mutates tables with `--execute`:

```bash
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze --table general --execute
python3 scripts/maintenance/optimize_clickhouse.py --layer gold --database gold_signals
```

`scripts/maintenance/recreate_clickhouse_tables.py` is the explicit Table
Recreation command. Setup never drops or alters tables and fails on schema
drift. This command drops the selected tables and recreates them empty from
setup DDL. It is dry-run by default and only mutates tables with `--execute`;
reload the affected scope with the normal layer loader afterward:

```bash
python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted
python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted --execute
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
and shared helpers in `src/fotmob/gold/dml_runner.py`. Do not add handwritten
per-signal runner files. Use `--id` for one exact signal; use `--entity` or
`--family` as separate signal batch selectors such as `--entity player` or
`--family shooting_goals`.
Every execution also requires `--date`, `--month`, or `--full-history`.
After successful signal SQL execution, the loader runs `scripts/gold/activations/build_signal_activations.py`
to populate deterministic per-match activation IDs in `gold.signal_activations`.
The builder stages rows in ephemeral `warehouse_stage.signal_activations_stage`, then runs
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
