# Oddspedia Source Flow

Oddspedia is an isolated Historical source domain. Its raw discovery links,
page payloads, manifests, and logs never enter FotMob's `data/fotmob/` paths.

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
python3 scripts/oddspedia/setup_clickhouse.py
python3 scripts/oddspedia/load_clickhouse.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_matches.py --date 20260301 --dry-run
```

The resolver checks FotMob fixture candidates from the previous, current, and
following UTC calendar dates. It compares normalized home and away teams,
preserves meaningful qualifiers such as `U19` and `Women`, and uses kickoff
time and league only as corroborating evidence.

Match statuses are `matched`, `ambiguous`, `unmatched`, and `unresolved`.
Coverage categories are `xG`, `ratings`, `lower`, and `not_covered`.
`not_covered` requires an operator-confirmed complete three-day FotMob
reference window; otherwise the event remains `unresolved`.
