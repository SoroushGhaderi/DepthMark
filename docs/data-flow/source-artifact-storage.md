# Source Artifact Storage

FotMob and Oddspedia remain separate source domains, but equivalent local
source artifacts use the same aspect, artifact-type, and date ordering:

```text
data/{source}/
├── historical/                     completed dates only
│   ├── daily_listings/YYYYMM/YYYYMMDD/
│   ├── matches/YYYYMM/YYYYMMDD/
│   └── manifests/YYYYMM/YYYYMMDD/   Oddspedia only
└── live/                            machine-local current date only
    ├── daily_listings/YYYYMM/YYYYMMDD/
    ├── matches/YYYYMM/YYYYMMDD/
    └── manifests/YYYYMM/YYYYMMDD/   Oddspedia only
```

FotMob writes `daily_listings/YYYYMM/YYYYMMDD/matches.json` and
`matches/YYYYMM/YYYYMMDD/match_<fixture_id>.json`. Oddspedia writes its
discovered listings to `daily_listings/YYYYMM/YYYYMMDD/match_links.json`,
diagnostic discovery snapshots to
`daily_listings/YYYYMM/YYYYMMDD/discovery_partial.json`, raw payloads to
`matches/YYYYMM/YYYYMMDD/<event_id>.json`, and scrape state to
`manifests/YYYYMM/YYYYMMDD/manifest.json`.

The current date is always a refreshable Live snapshot. A completed date is
Historical. Collection rejects future dates. FotMob exposes these choices with
`--today` and historical selectors; Oddspedia uses its default current-date
command for Live and an explicit completed `--date` or `--month` for
Historical collection.

```bash
# Live/current-date snapshots
python3 scripts/bronze/scrape_fotmob.py --today
python3 scripts/oddspedia/football.py run

# Historical/completed-date artifacts
python3 scripts/bronze/scrape_fotmob.py --single-date 20260710
python3 scripts/oddspedia/football.py run --date 20260710
```

## Migration

This change moves existing source artifacts into the canonical layout. The
collector no longer reads the former FotMob single-date directories or the
former Oddspedia `links` directory.

`ODDSPEDIA_DATA_DIR` now identifies the source root (`data/oddspedia`), not an
aspect directory. The former `.../historical` setting is accepted as a
compatibility alias for that root, but new configuration should use the root.
