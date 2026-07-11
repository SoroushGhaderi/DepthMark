# Oddspedia Source Flow

Oddspedia is an isolated Historical source domain. Its raw discovery links,
page payloads, manifests, and logs never enter FotMob's `data/fotmob/` paths,
and its workflow is not run by `scripts/orchestration/pipeline.py`.

```text
Oddspedia listing/page
  -> data/oddspedia/historical/     source artifacts
  -> oddspedia_bronze.*             event, payload, and market facts
  -> silver.match                   canonical FotMob fixture reference (read only)
  -> silver.oddspedia_match_resolution
```

## Commands

```bash
python3 scripts/oddspedia/football.py discover --date 20260301
python3 scripts/oddspedia/football.py scrape --date 20260301
python3 scripts/oddspedia/football.py run --date 20260301
python3 scripts/oddspedia/setup_clickhouse.py
python3 scripts/oddspedia/load_clickhouse.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_matches.py --date 20260301 --dry-run
```

`football.py` supports `discover`, `scrape`, `run`, and `status`; `run` performs
discovery followed by scraping. Use `--month YYYYMM` with `football.py`, the
Bronze loader, or the resolver for a calendar-month scope. The scraper supports
`--workers N`, `--retry failed`, and `--retry incomplete` for controlled
recovery runs.

## Storage and tables

The configured Historical root is `data/oddspedia/historical/`. Discovery
creates the event-link artifact consumed by the loader; scraping saves one JSON
payload per discovered event. `scripts/oddspedia/load_clickhouse.py` loads
these source-faithful artifacts into:

- `oddspedia_bronze.event` — discovered event metadata and raw event JSON.
- `oddspedia_bronze.match_payload` — raw per-event page payloads.
- `oddspedia_bronze.market` — market names and their raw lines.

`scripts/oddspedia/setup_clickhouse.py` creates those tables and
`silver.oddspedia_match_resolution`. Its `--dry-run` mode lists the DDL files
without executing them.

The resolver checks FotMob fixture candidates from the previous, current, and
following UTC calendar dates. It compares normalized home and away teams,
preserves meaningful qualifiers such as `U19` and `Women`, and uses kickoff
time and league only as corroborating evidence.

Match statuses are `matched`, `ambiguous`, `unmatched`, and `unresolved`.
Coverage categories are `xG`, `ratings`, `lower`, and `not_covered`.
`not_covered` requires an operator-confirmed complete three-day FotMob
reference window; otherwise the event remains `unresolved`. Supply
`--reference-window-complete` only for that operator-confirmed condition.
