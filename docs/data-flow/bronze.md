# Bronze Layer — FotMob and Oddspedia

Bronze is the first layer in both source pipelines and the only
filesystem-backed data layer. It preserves source fidelity with minimal
transformation, while keeping FotMob and Oddspedia artifacts and raw tables
separate.

## Source boundaries

| Source | Filesystem artifacts | Raw ClickHouse facts | Next stage |
| --- | --- | --- | --- |
| FotMob | `data/fotmob/{historical,live}/` | `bronze.*` | FotMob Silver in `silver.*` |
| Oddspedia | `data/oddspedia/{historical,live}/` | `oddspedia_bronze.*` | Oddspedia Silver and the explicit resolution edge |

The Oddspedia workflow is documented in
[`oddspedia.md`](oddspedia.md). Its Bronze facts are not inserted into FotMob
`bronze.*` tables.

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

### Oddspedia historical payload storage

The Oddspedia odds scraper follows the same completed-date local archive
protocol. After all selected event outcomes for a historical date are terminal,
`data/oddspedia/historical/matches/{YYYYMM}/{YYYYMMDD}/{YYYYMMDD}_matches.tar`
contains `{match_id}.json.gz` members. Partial dates and current-date Live
artifacts remain as plain JSON so they can be resumed or refreshed. The
Oddspedia audit and Bronze loader read both archive members and any new plain
JSON files; a later priority expansion merges its newly scraped files into the
existing date archive.

### Oddspedia Bronze admission and publication

Oddspedia Bronze loading is a source-specific, date-scoped transaction rather
than a row-by-row append. `load_oddspedia_bronze.py` admits a date only when its discovery
manifest is accepted, the inventory checksum matches, scraping is terminal, and
every selected payload passes the rendered-event audit. It stages
`oddspedia_bronze.event`, `oddspedia_bronze.match_payload`, and
`oddspedia_bronze.market`, validates the staged date counts, then replaces the
target ClickHouse partition. The batch marker in
`oddspedia_bronze.load_status` is written as `staging` before replacement,
`published` after every table succeeds, or `failed` with the error context.
`resolve_oddspedia_events.py` consumes only a published date.

```bash
python3 scripts/oddspedia/load_oddspedia_bronze.py --date 20260301 --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --month 202603 --dry-run
```

The loader is intentionally fail-closed for legacy manifests without a
checksum; run discovery again before loading those dates. Month loads continue
through independent dates but exit non-zero if any date fails admission or
publication.

FotMob key classes:
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
`{S3_BUCKET}/bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz` when a bucket name is
available (otherwise `bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz`). Uploads require a
listing that proves every expected match is stored or marked unavailable;
`--allow-incomplete` provides an explicit recovery override. Existing remote
objects and local date directories are protected unless `--force` is supplied.

Downloads verify SHA-256 metadata when present, validate archive paths before
extraction, and restore through a temporary staging directory. Legacy archives
that contain only `{YYYYMMDD}/` remain downloadable, but cannot restore a daily
listing that was never stored in the legacy object. The downloader also
discovers the historical bucket-prefixed key layout
`{S3_BUCKET}/bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz` alongside the canonical
`bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz` layout; new uploads use the
bucket-prefixed layout when a bucket is configured.

Both directions support `--date`/`--single-date`,
`--start-date`/`--end-date`, `--month`, `--all`, and `--dry-run`. Multi-date
runs continue after independent failures and exit non-zero if any date fails.

### 3. ClickHouse Loading (`scripts/bronze/load_fotmob_bronze.py`)

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

Processing chain (ADR 0031). Every FotMob Bronze command is scoped by Source
Date: the Historical folder `matches/YYYYMM/YYYYMMDD/`, never a date read from
the payload. Steps 1–3 cover every table of a date before step 4 writes
anything, so a read, processing, or admission failure writes nothing for that
date.

Failures come in two classes, and either makes the run exit non-zero:

- **Date-Level Failure** (unreadable payload, processor error, rejected row,
  value failing admission, or a missing source for `--replace`): the date is
  recorded with its cause and the run continues with the next date. The run's
  result lists every failed date.
- **Run-Level Failure** (missing or drifted table, lost connection, failed
  insert, post-load contract failure, held Bronze write lock): the run stops.
  An insert failure can leave the date's earlier tables inserted; rerunning the
  date converges because Bronze tables are `ReplacingMergeTree`.

Every writing command holds the FotMob Bronze write lock
(`data/locks/fotmob_bronze.lock`, ADR 0032) for its whole run; a second writer
fails at once and names the holder. `--dry-run` takes no lock.

1. **Read.** `iter_match_payloads` reads every stored payload for the date: the
   `<date>_matches.tar` archive when it exists, otherwise loose
   `match_*.json.gz`, then `match_*.json`. An unreadable payload fails the date
   and names the file.
2. **Process.** `FotMobBronzeMatchProcessor.process_match` returns rows keyed by
   Bronze table, with keys equal to the DDL column names. Pydantic models and
   `SafeFieldExtractor` read the payload. An absent section yields no rows; an
   error while reading a section fails the date and names the match and
   section; a row the models reject fails the date and names the field.
3. **Admit.** `src/fotmob/bronze/admission.py` checks every value of every
   table for the date against the table's setup DDL under `clickhouse/bronze/`
   before anything is inserted. Admission never clips, rounds, or fills a value.
4. **Insert.** Each admitted table is inserted; ClickHouse fills
   `inserted_at DEFAULT now()`. A failed insert is written to `data/dlq/` and
   stops the run.
5. **Post-load contract.** `assert_bronze_layer_contracts` checks the touched
   tables for new invalid identity rows.

The loader also checks once per run that every Bronze table exists and matches
its DDL (Schema Drift), because admission shapes values for the DDL types.

Write modes (ADR 0032):

| Command | What it does | Identity |
| --- | --- | --- |
| `load-fotmob-bronze` (default) | Inserts each Source Date; reloading a date is idempotent | Application |
| `load-fotmob-bronze --replace` | Per date: admit, then remove the date's matches, then insert. A date that fails admission keeps its rows. Reports the stale Match Dates | Application |
| `load-fotmob-bronze --full-history --rebuild` | Truncate-and-reload without the empty window: loads every date into copies in `warehouse_stage` and swaps them in only if every date loaded. Any failure leaves Bronze unchanged | Maintenance |
| `remove-fotmob-bronze` | Deletes the matches of each Source Date from all 15 tables; `--full-history` truncates them. Prints the Silver and Gold commands for the stale Match Dates | Application; Maintenance for `--full-history` |

`--truncate` is deprecated: with `--full-history` it runs `--rebuild`, and it is
rejected with narrower scopes, where it used to erase every date to reload a
few. Removal and replace find a Source Date's matches from its stored payloads,
so a date whose files were deleted (ADR 0012) cannot be removed by Source Date.
Removal never cascades into Silver or Gold; rerun the printed commands after
reloading Bronze.

CLI arguments:
```bash
python3 scripts/bronze/load_fotmob_bronze.py --date 20251208
python3 scripts/bronze/load_fotmob_bronze.py --single-date 20251208
python3 scripts/bronze/load_fotmob_bronze.py --start-date 20251201 --end-date 20251207
python3 scripts/bronze/load_fotmob_bronze.py --month 202512
python3 scripts/bronze/load_fotmob_bronze.py --date 20251208 --dry-run
python3 scripts/bronze/load_fotmob_bronze.py --date 20251208 --replace
python3 scripts/bronze/load_fotmob_bronze.py --full-history --rebuild --dry-run
python3 scripts/bronze/load_fotmob_bronze.py --full-history --rebuild
python3 scripts/bronze/load_fotmob_bronze.py --stats
python3 scripts/bronze/remove_fotmob_bronze.py --date 20251208 --dry-run
python3 scripts/bronze/remove_fotmob_bronze.py --month 202512
python3 scripts/bronze/remove_fotmob_bronze.py --full-history
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

Bronze Admission (`src/fotmob/bronze/admission.py`) applies these rules per
column, from its DDL type:

| Situation | Result |
| --- | --- |
| Column absent from every row | Omitted if the DDL has a `DEFAULT`; `NULL` if `Nullable`; `[]` if `Array`; otherwise rejected |
| `NULL` value | Allowed in `Nullable` columns; `[]` in `Array` columns; otherwise rejected |
| Integer column | Whole numbers in range; `True`/`False` → 1/0; integral floats and digit strings convert; anything else, including out of range, is rejected |
| Float column | Numbers and numeric text; `NaN` is `NULL` |
| String column | Text; temporal values as ISO-8601; integers as digits; floats, booleans, and containers are rejected |
| `Date` / `DateTime` | Python temporal values or ISO-8601 text |
| Key the DDL does not declare | Rejected |
| Row identity (`BRONZE_REQUIRED_KEYS`) | Non-null, positive where numeric; exact duplicate rows collapse to one and are logged; rows that share an identity but differ are rejected |

A rejection names the table, column, rule, count, and up to three `match_id`
examples. Bronze preserves source fidelity: admission converts only where the
conversion is lossless and never standardizes keys.

The processor resolves three known source quirks before admission, each logged
at info level with the match and the values involved:

| Source quirk | Processor rule |
| --- | --- |
| Fractional ball possession (`66.7` / `33.3`) in an `Int32` column | Rounded half to even, so a pair still sums to 100 (`50.5` / `49.5` → `50` / `50`) |
| Two different events share one id: FotMob reuses an `eventId`, or two events without an id derive the same synthetic id | The first keeps its id; each later different event gets a deterministic id derived from the match, table, repeated id, and occurrence. Exact repeats keep the id and collapse |
| The same player listed twice in one lineup (`starters` or `substitutes`) | The first entry is kept and later entries are ignored |

## Failure Modes

| Failure | Recovery |
| --- | --- |
| API rate limit | Scraper retries with backoff |
| Unreadable or invalid payload file | Date-Level Failure naming the file: nothing is written for the date, the other dates load, and the run exits non-zero. Re-scrape or remove the file, then rerun the date |
| Processor section error or rejected source row | Date-Level Failure naming the match, section, and field; the other dates load. Fix the processor or model, then rerun the date |
| Value that does not fit the DDL | Date-Level Failure listing table, column, rule, and `match_id` examples; the other dates load. Fix the processor, or change the DDL with Table Recreation, then rerun the date |
| `--replace` or removal of a date whose source files were deleted | Date-Level Failure: its rows cannot be identified by Source Date. Use full-history removal or `--rebuild` instead |
| Missing or drifted Bronze table | Run-Level Failure before any date loads; run setup or Table Recreation |
| ClickHouse insert failure | DLQ file written; Run-Level Failure. Fix the cause and rerun the date |
| Another Bronze writer is running | Run-Level Failure naming the holder of `data/locks/fotmob_bronze.lock`; rerun when it finishes |
| `--rebuild` fails at any point | Bronze is unchanged; the staging copies are dropped. Fix the cause and rerun the rebuild |
| ClickHouse connection | Run-Level Failure; rerun `load_fotmob_bronze.py` |
| Token expiry | `refresh_turnstile.py` rotates credentials |
| Disk full | `health_check.py --disk-path data` detects threshold |
| S3 transfer failure | Re-run `sync_s3.py` for the affected dates; scraping and warehouse loading are unaffected |
