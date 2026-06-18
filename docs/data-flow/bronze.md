# Bronze Layer

Bronze is the only filesystem-backed data layer. It preserves source fidelity
from the FotMob API with minimal transformation.

## Overview

```text
FotMob API
  → data/fotmob/matches/         raw match JSON/GZIP/TAR files
  → data/fotmob/daily_listings/  daily match listings
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
   `data/fotmob/matches/{YYYYMMDD}/match_{match_id}.json` and listings to
   `data/fotmob/daily_listings/{YYYYMMDD}/matches.json`.
4. **Turnstile refresh** — `scripts/refresh_turnstile.py` handles token/cookie
   rotation when needed.

Scraping does not compress or upload its output. S3 availability has no effect
on scrape success or pipeline success.

Key classes:
- `BaseScraper` — retry, rate limiting, health checks
- `MatchScraper(BaseScraper)` — match detail fetching
- `DailyScraper(BaseScraper)` — daily listing fetching
- `FotMobOrchestrator` — parallel scraping with `ThreadPoolExecutor`

CLI arguments:
```bash
python scripts/bronze/scrape_fotmob.py 20251208           # single date
python scripts/bronze/scrape_fotmob.py --single-date 20251208  # single date (named)
python scripts/bronze/scrape_fotmob.py --month 202512     # full month
python scripts/bronze/scrape_fotmob.py 20251201 20251207  # date range
python scripts/bronze/scrape_fotmob.py 20251208 --force   # re-scrape
```

### 2. S3 Sync (`scripts/bronze/sync_s3.py`)

S3 upload and download are standalone, operator-invoked workflows:

```bash
python scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python scripts/bronze/sync_s3.py upload --month 202512
python scripts/bronze/sync_s3.py download --start-date 20251201 --end-date 20251207
python scripts/bronze/sync_s3.py download --all
```

Each new archive contains `matches/{YYYYMMDD}` and
`daily_listings/{YYYYMMDD}` and uses the compatible object key
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
4. Failed inserts go to DLQ (`data/dlq/`) via `src/storage/dlq.py`.

CLI arguments:
```bash
python scripts/bronze/load_clickhouse.py --date 20251208
python scripts/bronze/load_clickhouse.py --single-date 20251208
python scripts/bronze/load_clickhouse.py --start-date 20251201 --end-date 20251207
python scripts/bronze/load_clickhouse.py --month 202512
python scripts/bronze/load_clickhouse.py --date 20251208 --truncate
python scripts/bronze/load_clickhouse.py --stats
```

### 4. Table Optimization

Bronze tables use `ReplacingMergeTree(inserted_at)` for idempotent reruns.
Optimization SQL runs via:
```bash
python scripts/bronze/setup_clickhouse.py
```
Which executes `clickhouse/bronze/99_optimize_tables.sql`.

## DLQ (Dead Letter Queue)

When ClickHouse insertion fails:
1. Failed rows are written to `data/dlq/` as JSONL files.
2. Operator inspects the DLQ records.
3. Root cause is fixed.
4. Bronze loader is re-run for the affected date.

See `CONTEXT.md` for the DLQ Replay glossary entry.

## Contracts

- `assert_bronze_dataframe_contract()` in `src/utils/layer_contracts.py`
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
