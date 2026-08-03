# Oddspedia Medallion Pipeline

Oddspedia is a full source domain, not an auxiliary tab inside the FotMob
pipeline. Its target architecture is an independent Bronze → Silver → Gold
path. The source contract, raw artifacts, transformations, and product outputs
remain separate from FotMob even when an explicit cross-source relationship is
useful.

```text
Oddspedia listing/page
  → Oddspedia Bronze
      data/oddspedia/{historical,live}/
      oddspedia_bronze.*
  → Oddspedia Silver
      cleaned event, odds, and source entities
      silver.oddspedia_*
  → Oddspedia Gold
      odds-derived scenarios, signals, and serving outputs

Oddspedia Silver ── audited match relationship ──> FotMob Silver (`silver.match`)
```

The cross-source relationship is an integration edge. It is not a shared raw
table, does not rewrite `silver.match`, and does not make Oddspedia Silver
depend on FotMob Gold.

## Layer ownership and implementation status

| Layer | Oddspedia responsibility | Current repository status |
| --- | --- | --- |
| Bronze | Preserve discovered links, page payloads, manifests, and market facts without source mixing. | Implemented through `oddspedia_bronze.*`. |
| Silver | Clean and conform Oddspedia events/odds, then persist auditable source identities and resolutions. | Resolution is implemented in `silver.oddspedia_match_resolution`; the source-specific conformed layer remains an expanding boundary. |
| Gold | Materialize Oddspedia-owned odds scenarios, signals, and product-serving outputs. | Architectural target; do not route Oddspedia analytics through FotMob Gold tables. |

The status column describes implementation progress, not a different medallion
model. New Oddspedia work should extend the Oddspedia path at the appropriate
layer and keep the source name visible in table, script, and catalog contracts.

## Event intake and Bronze

Oddspedia collection is independent of
`scripts/orchestration/pipeline.py`. The intake flow is:

```text
discover → prioritize → scrape → load Oddspedia Bronze
```

```bash
python3 scripts/oddspedia/events.py discover --date 20260301
python3 scripts/oddspedia/events.py prioritize --date 20260301 --depthmark-window-ready
python3 scripts/oddspedia/events.py scrape --date 20260301 --priority lower
python3 scripts/oddspedia/events.py run --date 20260301 --depthmark-window-ready
python3 scripts/oddspedia/setup_clickhouse.py --dry-run
python3 scripts/oddspedia/load_clickhouse.py --date 20260301 --dry-run
```

`events.py` supports `discover`, `prioritize`, `scrape`, `run`, and `status`.
`run` performs discovery, priority generation, then priority-selected scraping.
It requires `--depthmark-window-ready` because priority generation reads the
previous, current, and following `silver.match` dates. `football.py` remains a
deprecated compatibility wrapper.

The configured Historical root is `data/oddspedia/historical/`. Discovery
creates the source-faithful event-link artifact. Priority generation writes a
separate decision ledger to
`link_priorities/YYYYMM/YYYYMMDD/prioritized_match_links.json`. Scraping saves
one raw payload per selected event. Once all selected events for a historical
date have reached a terminal outcome, the date scraper applies the same local
compression protocol as FotMob: each `{match_id}.json` becomes a
`{match_id}.json.gz` member inside
`matches/YYYYMM/YYYYMMDD/YYYYMMDD_matches.tar`, then the uncompressed working
files are removed. The archive is verified before replacement. If a later
priority tier adds events, the next compression pass merges those new payloads
with the existing archive. Current-date Live artifacts remain uncompressed.

The Bronze loader and scrape-resume audit read both the date archive and any
new plain JSON files, so compression does not change retry or loading behavior.
The Bronze loader writes:

- `oddspedia_bronze.event` — discovered event metadata and raw event JSON.
- `oddspedia_bronze.match_payload` — raw per-event page payloads.
- `oddspedia_bronze.market` — market names and raw odds lines.

## Oddspedia Silver

Oddspedia Silver owns the SQL transformations that clean and conform its Bronze
facts. It may use the explicit FotMob Silver reference for match resolution,
but it does not insert Oddspedia data into FotMob tables.

The current resolver checks FotMob fixture candidates from the previous,
current, and following UTC calendar dates. It compares normalized home and away
teams, preserves meaningful qualifiers such as `U19` and `Women`, and uses that
three-day window as its only date guard. Kickoff time, league, and other
provider metadata are not matching evidence. A unique exact/alias or
high-similarity team-name pair is matched; competing candidates remain
`ambiguous`.

The persisted relationship is `silver.oddspedia_match_resolution`. It records
the auditable relationship from one Oddspedia Source Event to at most one
canonical FotMob fixture. An Oddspedia Silver table is not the same thing as
the shared FotMob `silver.match` table.

```bash
python3 scripts/oddspedia/resolve_matches.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_matches.py --month 202603 --dry-run
```

## Oddspedia Gold

Oddspedia Gold is the source-owned product layer for odds-derived analysis. It
will contain Oddspedia scenarios, signals, and serving outputs derived from
Oddspedia Silver. It must not be represented as a second input path into the
current FotMob `gold_scenarios.*`, `gold_signals.*`, or `gold.*` activation
tables.

When Oddspedia Gold execution is introduced, its DDL, SQL, catalogs, and CLI
must be documented together and use explicit Oddspedia ownership in their
names. Until then, the existing FotMob Gold commands document only the FotMob
Gold path.

## Link priority and resolution policy

The priority artifact is a compact decision ledger, not a copy of the source
inventory. Each record is keyed by `oddspedia_id` and has a uniform
`providers.oddspedia` / `providers.fotmob` pair with IDs, team names, kickoff,
competition, coverage, and URL fields. `resolution` contains the decision,
confidence, score, margin, and team-name rules; window and policy metadata live
at the artifact root.

Approximate matching canonicalizes non-identifying club designators and `II` /
`2` second-team notation, then supplements character similarity with token
reordering and distinctive-token containment. A unique long token can rescue
one side only when the opposite side is exact or a reviewed alias. It never
accepts a generic short token alone and still requires a unique,
high-confidence home/away pair. `ambiguous` and
`unresolved` links are excluded from automatic scraping.

Statuses are `matched`, `ambiguous`, `unmatched`, and `unresolved`. Coverage
categories are `xG`, `ratings`, `lower`, and `not_covered`. `not_covered`
requires an operator-confirmed complete three-day FotMob reference window;
otherwise an unmatched event remains `unresolved`.

When a new matcher version selects additional links, the scraper reconciles the
selected IDs with accepted per-event JSON payloads. Existing payloads are not
scraped again; only newly selected, incomplete, or explicitly retried IDs are
processed.

See [`source-artifact-storage.md`](source-artifact-storage.md) for the shared
Historical/Live artifact hierarchy and
[`../adr/0021-add-oddspedia-as-source-domain.md`](../adr/0021-add-oddspedia-as-source-domain.md)
and [`../adr/0023-parallel-source-medallion-pipelines.md`](../adr/0023-parallel-source-medallion-pipelines.md)
for the source-isolation decisions.
