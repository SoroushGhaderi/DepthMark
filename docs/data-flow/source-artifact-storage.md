# Source Artifact Storage

FotMob and Oddspedia remain separate source domains, but equivalent local
source artifacts use the same aspect, artifact-type, and date ordering:

```text
data/{source}/
├── historical/                     completed dates only
│   ├── daily_listings/YYYYMM/YYYYMMDD/
│   ├── link_priorities/YYYYMM/YYYYMMDD/  Oddspedia only
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
`manifests/YYYYMM/YYYYMMDD/manifest.json`. After the completed DepthMark
reference window is confirmed, Oddspedia writes its derived decision ledger to
`historical/link_priorities/YYYYMM/YYYYMMDD/prioritized_match_links.json`.
After a historical odds date reaches terminal completion, its payload JSON
files are compressed into the FotMob-compatible
`matches/YYYYMM/YYYYMMDD/YYYYMMDD_matches.tar` archive with
`<event_id>.json.gz` members; Live artifacts remain uncompressed.

The JSON structures are documented externally under `schemas/oddspedia/`.
Those schemas do not introduce an envelope, `$schema` field, or version field
into raw files. New scraper writes validate source artifacts before atomic
replacement and preserve the caller's JSON structure. Existing scraped JSON
and manifests require no migration.

Operational date locks live separately under
`data/oddspedia/locks/<sport>_<YYYYMMDD>.lock`. They contain short-lived
process metadata for cross-process serialization and are not source artifacts,
must not be uploaded to S3, and are not read by Bronze loaders.

The current date is always a refreshable Live snapshot. A completed date is
Historical. Collection rejects future dates. FotMob exposes these choices with
`--today` and historical selectors; Oddspedia uses its default current-date
command for Live and an explicit completed `--date` or `--month` for
Historical collection.

```bash
# Live/current-date discovery snapshots
python3 scripts/bronze/scrape_fotmob.py --today
python3 scripts/oddspedia/discover_oddspedia_events.py

# Historical/completed-date priority-selected artifacts
python3 scripts/bronze/scrape_fotmob.py --single-date 20260710
python3 scripts/oddspedia/run_oddspedia_pipeline.py --date 20260710 --silver-reference-window-ready
python3 scripts/oddspedia/run_oddspedia_pipeline.py --start-date 20260701 --end-date 20260710 --silver-reference-window-ready
```

Inspect either source or reconcile both through the same read-only reporting
interface. Reporting reads these aspect/date partitions directly and does not
create locks, logs, manifests, or warehouse state.

```bash
python3 scripts/report_scraping.py --date 20260710
python3 scripts/report_scraping.py --source fotmob --month 202607 --format json
python3 scripts/report_scraping.py --source oddspedia --start-date 20260701 --end-date 20260710
```

## Migration

This change moves existing source artifacts into the canonical layout. The
collector no longer reads the former FotMob single-date directories or the
former Oddspedia `links` directory.

`ODDSPEDIA_DATA_DIR` now identifies the source root (`data/oddspedia`), not an
aspect directory. The former `.../historical` setting is accepted as a
compatibility alias for that root, but new configuration should use the root.
