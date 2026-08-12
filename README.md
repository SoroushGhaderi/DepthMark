# DepthMark

DepthMark is a football data warehouse with two explicit source domains. FotMob
and Oddspedia each follow the same three-layer medallion shape while keeping
their source contracts and raw data isolated:

- Bronze: source-faithful artifacts and raw warehouse facts for each website
- Silver: source-specific cleaned, typed, and conformed analytical entities
- Gold: source-specific scenarios, signals, and product-ready outputs

Cross-source matching is a separate integration relationship between the two
Silver layers. It does not merge Bronze data or turn one source's Silver/Gold
tables into the other source's pipeline.

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
  -> data/oddspedia/{historical,live}/  daily listings, payloads, and manifests
  -> oddspedia_bronze.*          source-specific warehouse facts
  -> Oddspedia Silver          cleaned odds/events and source entities
  -> Oddspedia Gold            odds-derived scenarios, signals, and serving outputs

FotMob Silver  <---- audited cross-source match relationship ---->  Oddspedia Silver
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
  data/oddspedia/         Oddspedia Historical and Live source artifacts
  docker/                 Dockerfile, entrypoint; root docker-compose.yml is the main stack
  docs/                   project-wide architecture and contracts
  scripts/                operational entry points
  src/                    source domains plus warehouse, integrations, common, and operations modules
```

FotMob remains the canonical fixture-reference source for cross-source match
resolution. Oddspedia remains the canonical source for its event and odds
records; it does not modify FotMob Bronze or `silver.match`.

Both source domains use `historical/` for completed dates and `live/` for the
machine-local current date. See
[`docs/data-flow/source-artifact-storage.md`](docs/data-flow/source-artifact-storage.md)
for the artifact hierarchy and collection commands.

## Oddspedia Pipeline

Oddspedia is operated independently of the FotMob orchestration pipeline. Its
event intake discovers links, validates and prioritizes them against the
completed three-day `silver.match` reference window, then scrapes the selected
payloads. Load the resulting Historical artifacts into `oddspedia_bronze.*`
before resolving each event to the read-only FotMob reference.
Football matchup links are pinned with Oddspedia's internal `?m=<event_id>`
selector so repeated or reverse fixtures cannot resolve to the wrong event.

```bash
# One date (default priority tier is `lower`)
python3 scripts/oddspedia/discover_oddspedia_events.py --date 20260301
python3 scripts/oddspedia/prioritize_oddspedia_events.py --date 20260301 --silver-reference-window-ready
python3 scripts/oddspedia/scrape_oddspedia_matches.py --date 20260301 --priority-tier xG
python3 scripts/oddspedia/run_oddspedia_pipeline.py --date 20260301 --silver-reference-window-ready
python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format markdown --output docs/reports/oddspedia/20260301.md
python3 scripts/oddspedia/setup_oddspedia_warehouse.py --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --date 20260301 --dry-run

# A whole calendar month
python3 scripts/oddspedia/run_oddspedia_pipeline.py --month 202603 --silver-reference-window-ready
python3 scripts/oddspedia/load_oddspedia_bronze.py --month 202603 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --month 202603 --dry-run

# An inclusive date range (resume-safe; accepted payloads are not scraped again)
python3 scripts/oddspedia/run_oddspedia_pipeline.py --start-date 20260301 --end-date 20260307 --silver-reference-window-ready
python3 scripts/report_scraping.py --source oddspedia --start-date 20260301 --end-date 20260307
python3 scripts/oddspedia/load_oddspedia_bronze.py --start-date 20260301 --end-date 20260307 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --start-date 20260301 --end-date 20260307 --dry-run
```

Oddspedia artifact contracts are external to the raw JSON and live under
`schemas/oddspedia/`. Runtime validation checks new listings and payloads before
atomic writes but serializes the scraper's input unchanged. Manifest validation
preserves unknown compatible fields during read-modify-write. Existing
`data/oddspedia/**/*.json` files are not migrated or rewritten.

Canonical source workflow scripts follow
`<verb>_<source>[_<layer-or-entity>].py`. Oddspedia therefore uses
`discover_oddspedia_events.py`, `prioritize_oddspedia_events.py`,
`scrape_oddspedia_matches.py`, `run_oddspedia_pipeline.py`, and
the source-owned warehouse commands shown above. Scraping observation is a
project-wide responsibility: use `scripts/report_scraping.py` for FotMob,
Oddspedia, or a combined report. It reconciles source artifacts without
acquiring a date lock, writing run logs, or mutating scraper/warehouse state.
Earlier status/report filenames remain warning-emitting compatibility adapters;
do not use them in new automation.

Common reporting examples:

```bash
python3 scripts/report_scraping.py --date 20260301
python3 scripts/report_scraping.py --source fotmob --month 202608
python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format json
python3 scripts/report_scraping.py --source oddspedia --start-date 20260301 --end-date 20260307
python3 scripts/report_scraping.py --date 20260301 --fail-on-attention
```

Discovery is fail-closed: it accepts only complete target-date pagination or a
verified empty result, and accepted inventories carry a SHA-256 inventory
checksum. Limited Vuex fallbacks remain diagnostic rescrape candidates; legacy
inventories with missing or stale checksums are refreshed before they can be
used. Football scraping records the market inventory exposed by the page and
the number of extracted markets; a partial odds result is requeued whenever
those counts differ. Empty or transiently unloaded odds are retried up to three
football attempts, after which an empty result is saved with
`odds_unavailable: true`. Explicit no-odds notices follow the same retry policy.
Legacy payloads without coverage metadata are audited for migration, while
known limited-odds results with matching tracked coverage remain accepted.
Incomplete discovery receives two fresh-listing
retries before the date fails; `discovery_partial.json` is never used as a date
inventory. Use `--retry-failed`, `--retry-incomplete`, and
`--priority-tier` for explicit operation semantics. Priority generation
requires `--silver-reference-window-ready`, then machine-verifies the exact
FotMob fixture-ID sets in Bronze and Silver for the previous/current/following
dates. It writes a complete decision ledger under
`data/oddspedia/historical/link_priorities/`; `scrape` rejects a stale or
missing ledger. All mutating date commands serialize through
`data/oddspedia/locks/<sport>_<YYYYMMDD>.lock`; dry runs do not create locks.
Month commands exit non-zero when any date is missing, unaccepted, or failed.

Bronze loading stages `event`, `match_payload`, and `market`, replaces the
target ClickHouse partition only after validation, and writes
`oddspedia_bronze.load_status` as `published` only after every replacement
succeeds. `resolve_oddspedia_events.py` refuses to read a date without that
published marker. See
[`docs/data-flow/oddspedia.md`](docs/data-flow/oddspedia.md) for artifact paths,
tiers, tables, and status definitions.

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
