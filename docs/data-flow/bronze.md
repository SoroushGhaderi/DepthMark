# Bronze Layer

Bronze is the only filesystem-backed data layer. It preserves source fidelity
from the FotMob API with minimal transformation.

## Overview

```text
FotMob API
  → data/fotmob/historical/      completed-date JSON/GZIP/TAR and listings
  → data/fotmob/live/            refreshable, uncompressed current-date data
  → bronze.*                 15 ClickHouse tables
```

## Data Flow

### 1. Scraping (`scripts/bronze/scrape_fotmob.py`)

The scraper fetches match data from the FotMob API:

1. **Daily listing** — `DailyScraper` calls `/matches` for a given date, returns
   a list of match IDs.
2. **Match details** — `MatchScraper` calls `/matchDetails` for each match ID,
   returns the full JSON payload.
3. **Storage** — `FotMobBronzeStorage` writes raw JSON to
   `data/fotmob/historical/matches/{YYYYMM}/{YYYYMMDD}/match_{match_id}.json` and listings
   to `data/fotmob/historical/daily_listings/{YYYYMM}/{YYYYMMDD}/matches.json`.
4. **Compression** — after a date is complete, the orchestrator compresses its
   match JSON files into `matches/{YYYYMM}/{YYYYMMDD}/{YYYYMMDD}_matches.tar`. Partial
   dates remain uncompressed so they can be resumed safely.
5. **Turnstile refresh** — `scripts/refresh_turnstile.py` handles token/cookie
   rotation when needed.

Scraping compresses completed local dates but never uploads them. S3
availability has no effect on scrape success or pipeline success.

Key classes:
- `BaseScraper` — retry, rate limiting, health checks
- `MatchScraper(BaseScraper)` — match detail fetching
- `DailyScraper(BaseScraper)` — daily listing fetching
- `FotMobOrchestrator` — sequential match scraping to limit FotMob request risk

CLI arguments:
```bash
python3 scripts/bronze/scrape_fotmob.py 20251208           # single date
python3 scripts/bronze/scrape_fotmob.py --single-date 20251208  # single date (named)
python3 scripts/bronze/scrape_fotmob.py --month 202512     # full month
python3 scripts/bronze/scrape_fotmob.py 20251201 20251207  # date range
python3 scripts/bronze/scrape_fotmob.py 20251208 --force   # re-scrape
python3 scripts/bronze/scrape_fotmob.py --yesterday        # previous completed date
python3 scripts/bronze/scrape_fotmob.py --today            # refresh Live data
```

Historical selectors accept only completed machine-local dates. For the current
month, `--month` stops at yesterday. `--today` refreshes the listing and every
listed match under `data/fotmob/live/`, overwrites the latest snapshots
atomically, and skips compression. Live data does not feed other layers.

### 2. S3 Sync (`scripts/bronze/sync_s3.py`)

S3 upload and download are standalone, operator-invoked workflows:

```bash
python3 scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python3 scripts/bronze/sync_s3.py upload --month 202512
python3 scripts/bronze/sync_s3.py download --start-date 20251201 --end-date 20251207
python3 scripts/bronze/sync_s3.py download --all
```

Each new archive contains `matches/{YYYYMM}/{YYYYMMDD}` and
`daily_listings/{YYYYMM}/{YYYYMMDD}` and uses the compatible object key
`bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz`. Uploads require a listing that proves
every expected match is stored or marked unavailable; `--allow-incomplete`
provides an explicit recovery override. Existing remote objects and local date
directories are protected unless `--force` is supplied.

Downloads verify SHA-256 metadata when present, validate archive paths before
extraction, and restore through a temporary staging directory. Legacy archives
that contain only `{YYYYMMDD}/` remain downloadable, but cannot restore a daily
listing that was never stored in the legacy object.

Both directions support `--date`/`--single-date`,
`--start-date`/`--end-date`, `--month`, `--all`, and `--dry-run`. Multi-date
runs continue after independent failures and exit non-zero if any date fails.

### 3. ClickHouse Loading (`scripts/bronze/load_clickhouse.py`)

Raw JSON is parsed and loaded into 15 Bronze ClickHouse tables:

| Table | Source | Content |
| --- | --- | --- |
| `bronze.general` | `general` | Match metadata, league, season |
| `bronze.timeline` | `timeline` | Event timeline |
| `bronze.venue` | `venue` | Stadium information |
| `bronze.player` | `player` | Player profiles |
| `bronze.shotmap` | `shotmap` | Shot locations and details |
| `bronze.goal` | `goal` | Goal events |
| `bronze.cards` | `cards` | Card events |
| `bronze.red_card` | `redCard` | Red card details |
| `bronze.period` | `period` | Period-level stats |
| `bronze.momentum` | `momentum` | Momentum tracking |
| `bronze.starters` | `starters` | Starting lineups |
| `bronze.substitutes` | `substitutes` | Substitutions |
| `bronze.coaches` | `coaches` | Manager information |
| `bronze.team_form` | `teamForm` | Team form data |
| `bronze.match_reference` | derived | Match reference lookup |

Processing chain:
1. `FotMobBronzeMatchProcessor` extracts 14 entity DataFrames from raw JSON.
2. Uses Pydantic models + `SafeFieldExtractor` for safe nested access.
3. `ClickHouseClient` performs upsert inserts with allowlisted tables.
4. Failed inserts go to DLQ (`data/dlq/`) via `src/fotmob/bronze/dead_letter.py`.

CLI arguments:
```bash
python3 scripts/bronze/load_clickhouse.py --date 20251208
python3 scripts/bronze/load_clickhouse.py --single-date 20251208
python3 scripts/bronze/load_clickhouse.py --start-date 20251201 --end-date 20251207
python3 scripts/bronze/load_clickhouse.py --month 202512
python3 scripts/bronze/load_clickhouse.py --date 20251208 --dry-run
python3 scripts/bronze/load_clickhouse.py --date 20251208 --truncate --dry-run
python3 scripts/bronze/load_clickhouse.py --date 20251208 --truncate
python3 scripts/bronze/load_clickhouse.py --stats
```

### 4. Table Storage Hygiene

Bronze tables use `ReplacingMergeTree(inserted_at)` for idempotent reruns.
Routine setup does not run full-table optimization or deduplication. ClickHouse
background merges handle normal storage cleanup, while warehouse quality checks
report extra physical row versions as non-failing diagnostics:

```bash
python3 scripts/quality/check_data_quality.py --layers bronze --strict
```

Treat physical row-version buildup as an operator maintenance signal, not as a
Bronze correctness failure by itself.

Plan explicit Bronze optimization before executing it:

```bash
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze --table general --execute
```

Omitting `--execute` is a dry run. Do not add optimization SQL back into Bronze
setup.

## DLQ (Dead Letter Queue)

When ClickHouse insertion fails:
1. Failed rows are written to `data/dlq/` as JSONL files.
2. Operator inspects the DLQ records.
3. Root cause is fixed.
4. Bronze loader is re-run for the affected date.

See `CONTEXT.md` for the DLQ Replay glossary entry.

## Contracts

- `assert_bronze_dataframe_contract()` in `src/warehouse/contracts.py`
  validates DataFrame shapes before ClickHouse insertion.
- Bronze preserves source fidelity — no type casting or key standardization.

## Failure Modes

| Failure | Recovery |
| --- | --- |
| API rate limit | Scraper retries with backoff |
| Invalid JSON | DLQ file written, load continues for other matches |
| ClickHouse connection | Non-zero exit, re-run `load_clickhouse.py` |
| Token expiry | `refresh_turnstile.py` rotates credentials |
| Disk full | `health_check.py --disk-path data` detects threshold |
| S3 transfer failure | Re-run `sync_s3.py` for the affected dates; scraping and warehouse loading are unaffected |
