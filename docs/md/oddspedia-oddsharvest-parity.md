# Oddspedia Scraper Parity: OddsHarvest → DepthMark

Status: **Phase 2** — step 1 done (uncommitted) on `fix/oddspedia-date-picker`;
step 2 tried and reverted (see "Step 2 result").
Date: 2026-11-11.

> **Base correction.** This audit was first written against the local `main`
> (`b736d391`, 2026-10-12), which is 126 commits behind `origin/main`
> (`5a6026d0`, 2026-11-06). `origin/main` refactored the Oddspedia code
> (`odds_contract.py`, `paths.py`, `src/oddspedia/commands/`, one worker
> loop, source-named ClickHouse databases). All work branches start from
> `origin/main`. File:line references below come from the old base and may
> have moved; each step re-checks its rows on `origin/main` before it
> changes code. Re-checked so far:
>
> - The date picker selector is still the removed one on `origin/main`
>   (confirmed live on 2026-11-11: it matches nothing on
>   `oddspedia.com/football`).
> - The integer winner code is **already handled** on `origin/main`:
>   `_football_score_from_meta` maps `1`/`2`/`0` to `home`/`away`/`draw`.
>   That part of step 1 is dropped.

## Summary

DepthMark's Oddspedia scraper (`src/oddspedia/scraping/`) is an older fork of
the OddsHarvest collector (`src/oddspedia_scraper/`). The two share the same
shape: discovery → manifest → match detail extraction → audit → compression.
OddsHarvest has moved on with about 20 decisions (ADRs 0009–0027) that
DepthMark does not have.

The most urgent gap: **DepthMark still finds the listing date picker with the
selector Oddspedia removed** (`.flex.align-items-center.p-0`). OddsHarvest
lost every payload on 20261109 for this exact reason (commit `0c8094c`). So
DepthMark's Oddspedia discovery is very likely broken right now. Step 1 of the
plan fixes this first.

DepthMark also has its own good work that OddsHarvest lacks. The port must
keep it:

- Link Priority against FotMob `silver.match` (ADR 0022) and priority tiers.
- URL pinning per event (`pin_oddspedia_event_url`), team slugs, and
  JSON-LD source-URL repair in `_merge_league_names`.
- A retry loop and an input fallback in the date picker.
- The football market contract (`_football_apply_market_contract`) and the
  European handicap coverage check.
- Fail-closed Bronze admission and scoped publication (`load_status`).

## Reference Points

| | OddsHarvest | DepthMark |
| --- | --- | --- |
| Root | `C:\Users\Ghaderi.Soroush\Desktop\OddsHarvest` | `C:\Users\Ghaderi.Soroush\Desktop\fotmob\DepthMark` |
| Branch / commit | `feat/tennis-silver-layer` @ `81d1f2b` | `main` @ `b736d391` |
| Sport | Tennis | Football |
| Scraper code | `src/oddspedia_scraper/` | `src/oddspedia/scraping/` |
| Run loop | `main.py` | `src/oddspedia/scraping/cli.py` |
| Payload schema | `schemas/bronze/match_document.schema.json` (v2) | `schemas/oddspedia/match_payload.schema.json` (flat) |
| Rules | `docs/adr/README.md` (0001–0027) | `docs/adr/0021`, `0022` + `AGENTS.md` |

How different the shared modules are (`git diff --numstat`, lines added /
removed going from OddsHarvest to DepthMark):

| Module | + | − |
| --- | ---: | ---: |
| `match_collector.py` | 256 | 289 |
| `match_scraper.py` | 2190 | 1739 |
| `driver.py` | 221 | 263 |
| `storage.py` | 186 | 398 |
| `manifest.py` | 262 | 801 |
| `audit.py` | 353 | 582 |

OddsHarvest modules with no DepthMark copy: `api_odds.py`, `event_policy.py`,
`payload_document.py`, `network.py`, `source_canary.py`, `odds_coverage.py`,
`run_report.py`, `locks.py` (DepthMark has its own `operation_lock.py`).

## Stage-By-Stage Comparison

Status key: **Same**, **Different**, **Missing** (in DepthMark).
"Football?" says whether the OddsHarvest rule applies to football.

### 1. Event discovery

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Date picker selector | `.period-navigation__current-period-button` (`match_collector.py:408` `_navigate_to_date`, commit `0c8094c`) | `.flex.align-items-center.p-0` in `_read_displayed_date` (`match_collector.py:339`), the trigger in `_navigate_to_date` (`:369`), the arrow fallback and the correction loop | **Different — broken** | Yes, same page | Use the new class. Keep DepthMark's retry loop and input fallback. Check that the arrow filter no longer excludes the wrong element. |
| Wait for listing render | `_wait_for_listing_ready` polls the Vue `matchList` (`match_collector.py:794`) | Fixed `time.sleep(5)` + `sleep(3)` in `collect_match_links` | **Missing** | Yes | Port the wait. It prevents a false `no-trigger` while Cloudflare shows its shell page. |
| Trusted discovery contract (ADR 0009) | `DiscoveryResult` has `listing_ready`, `target_date_verified`, `source_confidence`, `empty_valid`; `complete` needs all of them | `DiscoveryResult` has `empty_confirmed` only; `complete` = matches or empty + no anomalies + pages | **Different** | Yes | Port the fields. Keep `empty_confirmed` as the input to `empty_valid`. |
| Events outside the target day | `events_outside_target_day` / `event_collection_date` in the collection timezone | Missing | **Missing** | Yes | Port. Football has many late-night UTC kickoffs, so this matters more than for tennis. |
| Page limit | `MAX_LISTING_PAGES` from config, `pagination_limit_reached` anomaly | Hard-coded `41` in `_fetch_all_matches` | **Different** | Yes | Port the config value and the anomaly. |
| Discovery retry back-off | `_discovery_backoff_until`, `_skip_for_discovery_backoff` (`main.py:842`) | `DISCOVERY_MAX_ATTEMPTS = 3` (`cli.py:118`) | **Different** | Yes | Keep DepthMark's 3 attempts. Add the back-off so a scheduled run does not retry a bad date at once. |
| Closed date discovered once more before compression | `_needs_final_reconciliation` (`main.py:887`) | Missing | **Missing** | Less important (DepthMark scrapes D-2) | Port. It is cheap and catches late listing changes. |

### 2. Tennis Scrape Decision → Football Scrape Decision

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Which statuses are skipped | `event_policy.classify_event` (`event_policy.py:100`): skip canceled and walkover only (ADR 0005) | `FOOTBALL_SKIP_STATUSES = {POSTPONED, CANCELLED, CANCELED, ABANDONED, SUSPENDED}` (`cli.py:113`, `_skip_reason` `:123`) | **Different** | Rule shape yes, status list no | Add a `event_policy.py` with a football status list. **Decision needed** (see Open Decisions 1). |
| Dead code | — | `_ALLOWED_FINAL_STATUSES`, `_BLOCKED_STATUSES`, `_is_full_time_match` (`match_collector.py:152-161`) have no callers | — | — | Remove, or use them inside the new `event_policy.py`. |
| Link Priority filter | None | `prioritize_date`, `--priority-tier` | DepthMark only | Yes | Keep as is. It runs after the scrape decision. |

### 3. Match detail extraction and odds

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Where odds come from (ADR 0011 → 0013) | `api_odds.extract_api_odds` (`api_odds.py:698`): `getOddsAvailableMarkets` + `getMatchOdds` by event id, "All bookmakers" geo, DOM only as fallback | DOM only: market cards are clicked and expanded (`_extract_football_odds` `match_scraper.py:2525`, `_JS_EXTRACT_ODDS` `:1037`) | **Missing** | Yes, the API is not tennis-only | Port `api_odds.py`. Football group ids come from the page store `default_market_groups`; the tennis fallback ids `(2, 4, 3, 8)` (`api_odds.py:44`) must change. Three-way lines (1X2) need checking: `_two_way_line` is tennis-shaped. Needs a live probe. |
| One bookmaker per market (ADR 0015) | Keep the bookmaker that prices the most lines | Whatever the page shows for the visitor's country | **Missing** | Yes | Port with the API. |
| Raw odds reads (ADR 0022) | `odds.raw` + `odds.derivation`, rebuildable offline (`rebuild_markets_from_raw`) | Missing | **Missing** | Yes | Port with the API. |
| Request spacing and refusals | 1.0–1.5 s spacing, stop on 403/429/5xx, back off 30 s | No API requests | **Missing** | Yes | Port with the API. |
| Page pinned to the event (ADR 0012) | `?m=<event id>`; a store for another event fails the match | `pin_oddspedia_event_url` + `MatchIdentityMismatchError` + `market_salvaged` | **Same idea** | Yes | Keep DepthMark's version. Add the store-level event id check from `api_odds.EventIdentityMismatchError`. |
| Odds coverage check (ADR 0008) | `odds_coverage.py`, applies to every odds source | `_football_odds_coverage_error`, `_validate_european_handicap_coverage` | **Different** | Yes | Keep the football checks. Run them on API odds too. |
| Winner as integer | `_winner_side` maps `1`/`2` to `home`/`away` (`payload_document.py:166`, commit `0c8094c`) | `d.winner = e.winner \|\| e.result \|\| ''` (`match_scraper.py:923`) stores the raw value | **Different** | Yes; football also has a draw | Map `1`/`2` and the draw code. **Check live** what Oddspedia sends for a draw. |
| Court surface (ADR 0027) | `event.surface` | — | Not applicable | **No** | Do not port. |
| Point by point, sets, ranks | Tennis sections | Tennis leftovers in DepthMark: `_extract_point_by_point` runs only when `sport == "tennis"` (`match_scraper.py:3379`); `_parse_set_scores` (`:3125`) and `_extract_overall_stats` (`:3380`) still run for football | — | **No** | Do not port. Check in step 7 whether the two that still run add anything to football payloads; drop them from the v2 document if not. |

### 4. Payload document and JSON schema

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| On-disk layout (ADR 0017) | v2 document: `schema_version`, `event`, `players`, `result`, `odds`, `stats`, `point_by_point`, `scrape`, `extra`; `to_document` / `to_record` are exact inverses (`payload_document.py:449`, `:531`) | Flat record: `sport`, `id`, `source_event_id`, `home`, `away`, `tournament`, `date`, `url`, `status`, `score`, `odds_*`, `odds`, `stats`, `stats_source`, `scraped_at`; `additionalProperties: true` | **Different** | Yes, with football sections | New football v2 document. See the proposed shape below. |
| Unknown fields | Kept under `extra`, never dropped | Kept because the schema allows any field | Similar | Yes | Keep the `extra` rule. |
| Old payloads | Rejected; the match is scraped again | — | — | **No** | DepthMark has history that cannot be scraped again. Storage and the loader must read **both** shapes. |
| Schema file | `schemas/bronze/match_document.schema.json`, generated by `export_bronze_schemas.py` | `schemas/oddspedia/match_payload.schema.json`, hand-written; tested by `test_football_match_schema.py` | **Different** | Yes | Add a v2 schema file next to the old one. Keep the old one as the v1 contract. |

Proposed football v2 shape (to confirm in step 7):

```json
{
  "schema_version": 2,
  "event": {"id", "source_event_id", "sport": "football", "start_time", "tournament", "round", "country", "url"},
  "teams": {"home": {"name", "slug"}, "away": {"name", "slug"}},
  "result": {"status", "winner": "home|away|draw|null", "score": {"home", "away"}, "unavailable"},
  "odds": {"source", "geo", "unavailable", "unavailable_reason", "total_markets", "markets", "raw", "derivation"},
  "stats": {"<metric>": {"home", "away"}},
  "scrape": {"scraped_at", "odds_captured_after_start_seconds", "odds_coverage", "odds_attempt", "odds_max_attempts", "odds_empty_attempts", "stats_source"},
  "extra": {}
}
```

What reads the payload today (so what a schema change can break):

| Reader | Fields it reads | Effect of v2 |
| --- | --- | --- |
| `src/oddspedia/bronze/loader.py:434-470` | `id`, `identity_validation`, `scraped_at`, `odds[].market`, `odds[].lines` | Must read through a `to_record`-style adapter. |
| `src/oddspedia/scraping/audit.py` (`_payload_reasons`, `_football_coverage_reasons`, `_football_odds_schema_reasons`) | Flat fields | Must read through the adapter. |
| `src/oddspedia/scraping/reporting.py`, `scripts/report_scraping.py` | Counts and `schema_version` of reports | Check. |
| `clickhouse/**` SQL | Nothing reads `oddspedia_bronze.*` beyond DDL | No effect. |
| `src/oddspedia/silver/match_resolution.py` | Event inventory, not payloads | No effect. |

So the Bronze DDL can stay the same at first: `raw_payload_json` holds
whichever document was stored. A `schema_version` column can come later
through `scripts/maintenance/recreate_clickhouse_tables.py` (ADR 0026).

### 5. Finality

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| When a match is done (ADR 0003 → 0016 → 0018 → 0020) | Payload evidence: final only on an end state or 48 h after start; postponed is provisional; a final payload is never scraped again (`event_policy.is_final_payload` `:173`) | An accepted JSON is done (`_select_matches_to_scrape` `cli.py:231`) | **Missing** | Yes; end states `FT`, `AET`, `PEN` | Port with football end states. |
| `--refresh-live` | Refreshes provisional payloads only | No flag | **Missing** | Less important | The `oddspedia-daily` job scrapes two days ago, so dates are almost always Historical. Port it last, if at all. |
| Live → Historical promotion | `_promote_final_live_payloads` (`main.py:1223`) | Missing | **Missing** | Less important | Same as above. |

### 6. Storage

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Historical / Live split (ADR 0006) | Yes, under `data/bronze/` | Yes, under `data/oddspedia/historical|live` | **Same idea** | Yes | Keep DepthMark paths. |
| "Today" (ADR 0021) | One `ODDSPEDIA_TIMEZONE` (default UTC) for Python and Chrome | `get_storage_aspect` uses machine-local `date.today()` (`config.py:83`); the collector uses UTC `datetime.now(timezone.utc)` | **Different — inconsistent** | Yes | Port one collection timezone. Today the two clocks can disagree near midnight. |
| Archive name | `YYYYMMDD.tar`, old name still readable | `YYYYMMDD_matches.tar` (`storage.py:53`) | **Different** | Optional | Low value. Port only together with an S3 sync. |
| Archive member format | Plain JSON members | gzip JSON members, the FotMob protocol | Different | — | Keep DepthMark's format. |
| Compression gate | Every non-ignored event done, nothing failed, incomplete, pending or in progress | Same rule (`_compress_completed_date` `cli.py:828`) | **Same** | Yes | Keep. Add "every payload final" once finality exists. |
| fsync on write | `_fsync_file`, `_fsync_directory`, also for the archive | File fsync in `save_json` (`utils.py:267`) and the manifest (`manifest.py:384`); no directory fsync, none in `storage.py` | **Partly same** | Yes | Port the directory and archive fsync. |

### 7. Manifest and audit

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Corrupt manifest (ADR 0019) | Stop with exit 1; only `--rebuild-manifest` moves it aside | `load_manifest` raises `ManifestCorruptError` (`manifest.py:348`); `cli.py` does not catch it, so the run ends through the general error path | **Partly same** | Yes | Catch it in `cli.py` with a clear message and exit 1, and add `--rebuild-manifest`. |
| Audit of out-of-inventory files | `_out_of_inventory_ids` | Missing | **Missing** | Yes | Port. |
| Manifest audit | `_audit_manifest` | Missing | **Missing** | Yes | Port. |
| Shared acceptance policy | One audit decides for manifest, compression and Bronze | Same idea | **Same** | Yes | Keep. |

### 8. Resilience

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| What Chrome loads (ADR 0025) | `ODDSPEDIA_LIGHT_PAGES` (default on): exact hosts and paths; **CSS is not blocked** (`driver.py:48`) | By file extension, **including `*.css`**, unless `--load-resources` (`driver.py:294`) | **Different** | Yes | Port the light-page list. Blocking CSS can break the visibility checks that football market clicks depend on. |
| Cloudflare checks (ADR 0014) | `_CloudflareGuard` (`main.py:492`): cool down 180 s then 300 s; 4 checks in 30 min stop the run with exit 2; the first check per browser session is not counted | `wait_for_cloudflare` + one warm-up visit; no counting, no cool-down | **Missing** | Yes | Port. |
| Network outages (ADR 0026) | `_NetworkGuard` + `network.py`: wait up to 15 min, retry without spending an attempt, never mark failed | Missing; a network error counts as a failure | **Missing** | Yes | Port. |
| Circuit breaker (ADR 0004) | 5 real failures → 2 min pause; 3 pauses → abort; real exceptions only | Same numbers (`cli.py:110-112`, `_CircuitBreaker` `:158`) | **Same** | Yes | Keep. After the network guard lands, network errors stop counting. |
| `mark_done` gate (ADR 0003) | Payload evidence | Payload evidence (audit) | **Same** | Yes | Keep. |
| Host-wide `pkill` (ADR 0001) | None | None | **Same** | — | — |

### 9. Run state and exit codes

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Exit codes (ADR 0010) | `0` complete, `1` fatal, `2` incomplete, `130` interrupted (`_run_outcome` `main.py:947`) | `sys.exit(1)` for every failure; `KeyboardInterrupt` → `1` (`cli.py:2076-2080`) | **Different** | Yes | Port. Check `scripts/orchestration/run_scheduled_job.py` treats `2` correctly. |
| Durable run summary | `run_summary` file per run + `run_report.py` alerts | Metrics + `scripts/report_scraping.py` | **Different** | Yes | Add the run summary. Feed it into `report_scraping.py` (the only report entry point, ADR 0025). |
| Per-date lock | `locks.file_lock` (works on Windows and Linux) | `operation_lock.py` with `fcntl` (Linux only) | **Different** | Yes | Keep DepthMark's lock. Optional: make it cross-platform so tests run on Windows. |
| Source canary | `source_canary.py`: compares listing and document shapes with a saved baseline | Missing | **Missing** | Yes | Port. It would have caught the date picker change early. |

### 10. S3 and warehouse

| Topic | OddsHarvest | DepthMark | Status | Football? | Proposed change |
| --- | --- | --- | --- | --- | --- |
| Bronze S3 copy (ADR 0024) | `sync-bronze-s3` per closed date | FotMob only (`scripts/bronze/sync_s3.py`, `BronzeS3Service`) | **Missing for Oddspedia** | Yes | Separate task, after the scraper work. |
| Bronze admission | Historical + accepted discovery + clean audit + every payload final | Fail-closed admission (commit `4bc3244a`) without finality | **Mostly same** | Yes | Add "every payload final" after step 8. |

## Migration Plan

Each step is one branch and one change. Each step must pass the safety check
below before the next one starts.

**Safety check after every step:**

1. Run `pytest tests/unit/oddspedia` in the DepthMark Docker image.
2. Scrape one completed date with
   `python scripts/oddspedia/scrape_oddspedia_matches.py --date <D>`.
3. Compare with the baseline from step 0: discovered events, saved payloads,
   odds coverage, failed matches. If any gets worse, revert the step.

| Step | Change | Branch | Risk | Why this order |
| ---: | --- | --- | --- | --- |
| 0 | Baseline. Build the Docker image, run the Oddspedia tests, run one live scrape of a completed date. Record the numbers. Expect discovery to fail on the date picker. | — | None | Every later step is compared with this. |
| 1 | **Fix the date picker** with `.period-navigation__current-period-button` and port `_wait_for_listing_ready`. (The winner code was already handled.) | `fix/oddspedia-date-picker` | Low | Restores scraping. Smallest useful change. |
| 2 | **Light pages.** Replace the extension list (with CSS) by the OddsHarvest host list behind `ODDSPEDIA_LIGHT_PAGES`. | `fix/oddspedia-light-pages` | Low–medium | Faster and safer pages before the bigger changes. |
| 3 | **One collection timezone** (`ODDSPEDIA_TIMEZONE`, default UTC) for storage, collector and Chrome. Port `events_outside_target_day`. | `fix/oddspedia-collection-timezone` | Low | Fixes the clock mismatch. |
| 4 | **Trusted discovery contract** fields, page limit from config, discovery back-off, final reconciliation before compression. | `feat/oddspedia-trusted-discovery` | Medium | Stops partial inventories from being accepted. |
| 5 | **Resilience:** Cloudflare guard, network guard, exit codes `0/1/2/130`, run summary, source canary. | `feat/oddspedia-run-resilience` | Medium | Makes long runs survive, and tells the scheduler when a run is incomplete. |
| 6 | **Odds from the API** by event id, one bookmaker per market, raw reads, DOM as fallback. Football group ids and three-way lines. | `feat/oddspedia-api-odds` | **High** | Biggest change. Do a live probe first; coverage must be ≥ the DOM baseline on the same date. |
| 7 | **Football v2 Match Document** + `schemas/oddspedia/match_document.schema.json` + one adapter so storage, audit and loader read v1 and v2. | `feat/oddspedia-match-document-v2` | Medium–high | After step 6 so the `odds.raw` / `derivation` sections are known. |
| 8 | **Finality and the Football Scrape Decision** in `event_policy.py`: football end states, final payload never scraped again, Bronze admission requires final. | `feat/oddspedia-payload-finality` | Medium | Needs the v2 document. |
| 9 | Optional: `--refresh-live`, Live → Historical promotion, `YYYYMMDD.tar` name, Oddspedia S3 sync. | separate | Low | Little value while the daily job scrapes D-2. |

### Step 1 result (2026-11-11)

Live discovery of 20261109 (two days back, the `oddspedia-daily` date),
using DepthMark's own `get_driver` with a visible window and
`collect_match_links`:

| | `origin/main` (before) | `fix/oddspedia-date-picker` (after) |
| --- | --- | --- |
| Result | `date_navigation_failed` | complete, no anomalies |
| Events | 0 | 149 (3 of 3 pages) |
| Date set by | input set, but the date could not be read back; arrows: `no-date-btn` | calendar input, first attempt, read back from the new button |
| Time | — | 14.8 s |

Unit tests (Windows, scratch venv): 141 passed on the branch versus 136 on
`origin/main`. The same 9 failures and 11 errors occur on both. They come
from the environment: `fcntl` is Linux only, and the script-help and fixture
tests need the Linux image. Ruff check, Ruff format and
`check_logging_style.py` pass.

Headless Chrome stayed on Cloudflare's "Just a moment..." page on this
machine, with and without the fix. That happens before discovery code runs.

Seen in the live listing, for later steps:

- The listing for 20261109 also holds events that start on 20261108 UTC
  (step 3, collection timezone).
- 69 of 149 events still show `2HALF` two days after the date. Listing status
  is not reliable evidence that a match finished (step 8, finality from
  payload evidence).

### Step 2 result (2026-11-11): reverted

I tried OddsHarvest's light-page list (`LIGHT_PAGE_BLOCKED_URLS`, exact
hosts, no CSS or extension rules) behind `ODDSPEDIA_LIGHT_PAGES`, then
scraped the same live matches from 20261109 with DepthMark's `scrape_match`.
Each policy got a fresh visible Chrome and a 3-7 s pause between matches.

| Match | Old extension list | Light list | Load everything |
| --- | --- | --- | --- |
| FC Bentonit v Ararati Araks (`10329741`) | OK: 6 markets, 12 lines | **Fails**: `FootballOddsCoverageError`, collapsed cards Double Chance and Odd or Even did not render | **Fails**: same |
| Club Blooming v Oriente Petrolero (`10322086`) | OK: 4 markets, 32 lines | OK: 4 markets, 10 lines | OK: 4 markets, 10 lines |

An earlier light-list run on `10329741` failed the same way (3 of 3 with
images loading, 2 of 2 passing with the old list). DepthMark's football
card clicks were tuned with the old list, and they depend on it. So I
reverted the step, following the safety rule. The diff is kept as a patch
outside the repository.

Facts found on the way:

- Football match pages load **no external CSS** (134 inline `<style>` tags).
  The `*.css` pattern blocks nothing, so the OddsHarvest worry about CSS
  does not apply here.
- The page loads trackers the old list misses: Adobe (`data`, `smetrics`,
  `assets.adobedtm.com`, `demdex.net`), Clarity, OneSignal, Connextra,
  everestjs, Sentry RUM (`rum.oddspedia.com`) and the Sportradar widget.
- **The market inventory is not stable.** A page offers more markets after
  "Show all markets" (17 on `10322086` in a normal browser), but DepthMark's
  `_expand_football_market_list` got 4, 6 or 17 markets on the same match
  across runs, under every policy. Line counts also change between runs
  (10 or 32 on `10322086`). This hurts data completeness more than the
  loading policy does. It belongs with step 6 (odds from the API by event
  id), which reads every market without clicking.

Revised step 2 options:

1. Keep the old extension list and add only the missing tracker hosts.
   Smallest change; still needs the same live A/B.
2. Skip step 2 and move to step 6 sooner: API odds do not depend on what
   Chrome renders, so the loading policy matters much less after it.
   **(Recommended.)**

Every step also updates, in the same change: `docs/adr/` (new ADRs that cite
the OddsHarvest ones), `CONTEXT.md` when a term changes, `schemas/oddspedia/`,
and the command docs.

## Not Ported (Tennis Only)

- Court surface (ADR 0027) and the `surface` column.
- Players and ranks, sets, games, set scores, point by point.
- Tennis market names, the tennis selector clicks and the tennis default group
  ids `(2, 4, 3, 8)`.
- The tennis wording of ADR 0005 (walkover).

## Open Decisions

1. **Football Scrape Decision.** OddsHarvest scrapes every status except
   canceled and walkover, and lets payload evidence decide. DepthMark skips
   `POSTPONED`, `CANCELLED`, `CANCELED`, `ABANDONED`, `SUSPENDED`. Options:
   1. Skip only canceled; treat postponed, abandoned and suspended as
      provisional and scrape them. **(Recommended: same rule as
      OddsHarvest, and abandoned matches often still have odds.)**
   2. Keep DepthMark's current skip list.
2. **Old flat payloads.** Options:
   1. Keep them as they are and read both shapes. **(Recommended: no history
      is touched.)**
   2. Convert them to v2 offline with a one-off script.
3. **Odds source.** Moving to the API with one bookmaker per market changes
   which prices Bronze stores. No SQL reads `oddspedia_bronze.market` yet, so
   the downstream risk is low. Confirm this is wanted before step 6.

## Limits Of This Audit

- I compared code only. I did not run either scraper live.
- I could not run DepthMark tests on this Windows machine. The project
  `.venv` has no `pytest`, and `operation_lock.py` imports `fcntl`, which is
  Linux only. Step 0 runs them in the Docker image.
- There is no local Oddspedia data under `data/oddspedia/`, so I could not
  check real payloads. The winner code and draw handling need a live check.
