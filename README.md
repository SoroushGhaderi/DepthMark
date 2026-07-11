# DepthMark

DepthMark is a football data warehouse with isolated FotMob and Oddspedia
source domains, built around a clear medallion architecture:

- Bronze: source-faithful FotMob and Oddspedia artifacts on disk, with isolated
  raw ClickHouse databases (`bronze.*` and `oddspedia_bronze.*`)
- Silver: cleaned and conformed ClickHouse `silver.*` tables
- Gold: scenario tables in ClickHouse `gold_scenarios.*`, signal tables in
  `gold_signals.*`, and shared activation metadata in `gold.*` for product and
  analytics use

```text
FotMob API
  -> data/fotmob/historical/  completed-date Bronze files
  -> data/fotmob/live/        current-date Live snapshots
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
  -> gold.*                shared Gold metadata and activation tables

Oddspedia
  -> data/oddspedia/historical/  source links, payloads, and manifests
  -> oddspedia_bronze.*          source-specific warehouse facts
  -> silver.oddspedia_match_resolution  audited link to `silver.match`
```

Bronze is the only filesystem-backed data layer. Silver and Gold exist only in
ClickHouse.

S3 transfer is an independent operator workflow; scraping and the warehouse
pipeline never upload automatically. Preview or run a date-scoped transfer with:

```bash
python3 scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python3 scripts/bronze/sync_s3.py download --date 20251208
```

## Documentation

Start with [`docs/README.md`](docs/README.md) for the documentation map.

| Topic | Location |
| --- | --- |
| Architecture, commands, and runbook | [`docs/DEVELOPMENT_ARCHITECTURE.md`](docs/DEVELOPMENT_ARCHITECTURE.md) |
| Script behavior and CLI contract | [`docs/SCRIPTS_CONTRACT.md`](docs/SCRIPTS_CONTRACT.md) |
| Data flow, layer diagrams, and infrastructure | [`docs/data-flow/`](docs/data-flow/) |
| Warehouse duplicate checks and reconciliation | [`docs/data-flow/orchestration.md`](docs/data-flow/orchestration.md#post-load-data-quality) |
| Script inventory | [`scripts/README.md`](scripts/README.md) |

Subsystem contracts live next to the code they govern, such as
`scripts/gold/scenario/SCENARIOS_CONTRACT.md` and
`scripts/gold/signal/contracts/`.

## Project Layout

```text
DepthMark/
  clickhouse/             ClickHouse DDL/DML by layer (gold uses ddl/ + dml/)
  config/                 Python configuration modules
  data/fotmob/            FotMob Historical and Live raw Bronze aspects
  data/oddspedia/         Oddspedia Historical source artifacts
  docker/                 Dockerfile, entrypoint; root docker-compose.yml is the main stack
  docs/                   project-wide architecture and contracts
  scripts/                operational entry points
  src/                    application services, scraper, storage, and utility code
```

FotMob remains the canonical fixture-reference source. Oddspedia remains the
canonical source for its event and odds records; it does not modify FotMob
Bronze or `silver.match`.

## Oddspedia Workflow

Oddspedia is operated independently of the FotMob orchestration pipeline. Its
browser scraper first discovers event links, then scrapes their saved payloads.
Load the resulting Historical artifacts into `oddspedia_bronze.*` before
resolving each event to the read-only FotMob reference in `silver.match`.

```bash
# One date (use `run` to discover then scrape in one command)
python3 scripts/oddspedia/football.py run --date 20260301
python3 scripts/oddspedia/setup_clickhouse.py --dry-run
python3 scripts/oddspedia/load_clickhouse.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_matches.py --date 20260301 --dry-run

# A whole calendar month
python3 scripts/oddspedia/football.py run --month 202603
python3 scripts/oddspedia/load_clickhouse.py --month 202603 --dry-run
python3 scripts/oddspedia/resolve_matches.py --month 202603 --dry-run
```

The resolver considers the previous, current, and following UTC dates. Only
pass `--reference-window-complete` when the corresponding FotMob reference
window is complete; that assertion allows unmatched events to be classified as
`not_covered`. See [`docs/data-flow/oddspedia.md`](docs/data-flow/oddspedia.md)
for artifact paths, tables, and status definitions.

## Warehouse Data Quality

The canonical read-only quality command checks declared row identities for
logical duplicates across Bronze, Silver, and Gold, reports unmerged physical
row versions separately, then reconciles identity sets only from Bronze to
Silver:

```bash
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/quality/check_data_quality.py --month 202512 --strict
python3 scripts/quality/check_data_quality.py --full-history --strict
```

Gold is duplicate-checked but is intentionally not reconciled with upstream
layers: scenario, signal, and activation outputs apply business rules, filters,
and grains for which row parity is not meaningful. The existing
`check_bronze_to_silver_reconciliation.py` command remains a compatibility
entry point for Bronze/Silver checks.
