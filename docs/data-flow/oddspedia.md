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
`scripts/orchestration/run_fotmob_pipeline.py`. The intake flow is:

```text
discover → prioritize → scrape → load Oddspedia Bronze
```

```bash
python3 scripts/oddspedia/discover_oddspedia_events.py --date 20260301
python3 scripts/oddspedia/prioritize_oddspedia_events.py --date 20260301 --silver-reference-window-ready
python3 scripts/oddspedia/scrape_oddspedia_matches.py --date 20260301 --priority-tier lower
python3 scripts/oddspedia/run_oddspedia_pipeline.py --date 20260301 --silver-reference-window-ready
python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format markdown --output docs/reports/oddspedia/20260301.md
python3 scripts/oddspedia/setup_oddspedia_warehouse.py --dry-run
python3 scripts/oddspedia/load_oddspedia_bronze.py --date 20260301 --dry-run

# Continue a bounded slice without changing or re-scraping accepted payloads
python3 scripts/oddspedia/run_oddspedia_pipeline.py --start-date 20260301 --end-date 20260307 --silver-reference-window-ready
python3 scripts/oddspedia/load_oddspedia_bronze.py --start-date 20260301 --end-date 20260307 --dry-run
```

Event intake, read-only reporting, Bronze loading, and resolution accept the
same inclusive `--start-date/--end-date` scope. Existing `--date` and `--month`
selectors remain stable. A current-month event-intake scope stops at the
machine-local current date; explicit future dates and ranges still fail.

Discovery is fail-closed. A date is accepted only when listing pagination and
target-date checks complete; a verified empty listing is represented as
`no_events` in the manifest. Vuex or other limited fallbacks are diagnostic
snapshots and remain rescrape candidates. Accepted inventories include a
checksum in the manifest. Discovery automatically marks legacy inventories
with missing or stale checksums for refresh; Bronze remains fail-closed until
that refreshed evidence exists. Every incomplete discovery receives two fresh
listing retries before the date is marked failed; `discovery_partial.json` is
never used as the date's event-link inventory.

All mutating Oddspedia date operations use the cross-process lock at
`data/oddspedia/locks/<sport>_<YYYYMMDD>.lock`. Discovery, priority generation,
scraping, Bronze loading, and resolution refuse to overlap for the same date.
Month commands continue through all dates but exit non-zero if any date is
missing, unaccepted, or otherwise failed.

Raw JSON structure is an immutable source contract. External Draft 2020-12
schemas under `schemas/oddspedia/` describe `match_links.json`, match payloads,
and `manifest.json`; the schema is not embedded into those artifacts. New
listing and payload writes use an explicit contract at the atomic persistence
seam and write the scraper's object unchanged after validation. Manifests
validate known state types and retain unknown compatible top-level fields.
`total` remains the full discovered-inventory count, while
`priority_run.selected_count` describes the selected scrape scope.

The canonical event-intake scripts are `discover_oddspedia_events.py`,
`prioritize_oddspedia_events.py`, `scrape_oddspedia_matches.py`, and
`run_oddspedia_pipeline.py`. `scripts/report_scraping.py --source oddspedia`
is the read-only reporting interface. It combines inventory, priority,
manifest, payload-audit, and run-log evidence into summary, Markdown, or JSON;
it does not acquire the date lock, create a status run log, or write pipeline
state. The former Oddspedia status/report paths are compatibility adapters to
this one interface.
`run_oddspedia_pipeline.py` performs discovery, priority generation, then
priority-selected scraping. It requires `--silver-reference-window-ready`
because priority generation reads the previous, current, and following
`silver.match` dates. `football.py` and the former umbrella `events.py` remain
deprecated compatibility wrappers. The canonical selectors are
`--retry-failed`, `--retry-incomplete`, and `--priority-tier`; their former
spellings remain accepted as aliases.

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
Before a payload is accepted, its rendered event ID (when available), home and
away teams, and calendar date are compared with the discovery row. This guard
is necessary because Oddspedia matchup URLs can advance to a later reverse
fixture while retaining the same URL. Discovered football links therefore add
the listing event ID as `?m=<event_id>`, and the scraper adds it defensively for
older link artifacts before navigation. If the rendered page contains the same
two teams but a stale event ID/date or reversed order, the scraper rejects the
payload and marks it for retry; odds, scores, and statistics are never written
for a different rendered event. A page showing different teams also remains a
failed scrape and is requeued. The Bronze loader also excludes legacy
`market_salvaged` payloads produced before this guard was introduced.

Accepted football odds lines also have a non-empty label. Parameterized markets
retain their observed threshold or handicap; non-parameterized markets use the
explicit label `Main Line`. Known markets with `schema_status: unmatched`, or
parameterized lines whose value cannot be recovered, are incomplete and are
requeued rather than treated as valid Bronze input. Football scraping records
the total market-card inventory exposed after expansion alongside the number
of extracted markets. Any non-empty result with fewer extracted markets than
the exposed total is retried rather than marked complete; the decision is
based on the observed denominator, not a fixed market count. Empty or
transiently unloaded odds are retried for up to three football attempts. If all
three attempts are empty, the payload is saved with `odds_unavailable: true`
and is accepted as terminal odds-unavailable data. Oddspedia's explicit
`odds are not yet available from bookies` notice is stronger evidence: it is
saved immediately with `odds_unavailable_reason: source_notice` and is not
retried or re-scraped. Legacy payloads without coverage metadata are requeued
for migration when their market count is ambiguous.

When a non-empty football payload is incomplete, the retry state carries the
partial markets and the inventory names that are missing. The next page load
expands and selects only those missing markets, then merges them with the
already extracted markets. If Oddspedia does not expose market names, the
scraper falls back to the normal full retry because it cannot safely identify a
smaller target.

The code splits along the same lines. `src/oddspedia/scraping/odds_contract.py`
holds the pure rules above (market families, outcome mapping, handicap
coverage, merge and dedupe, coverage errors) and is tested on recorded
fixtures without a browser. `match_scraper.py` only drives the page and hands
raw markets to it. `cli.py` scrapes every match through one `scrape_one()` flow
(attempts, partial-odds retry, manifest updates, circuit breaker) run by an
executor: `--workers 1` is the sequential case on the caller's browser, and more
workers each get their own Chrome profile and a disjoint batch. Matches a worker
leaves without an outcome (crash, circuit-breaker abort, no driver) are
persisted as retryable failures. The scraper is football-only: set scores,
live odds, statistics and point-by-point fields stay empty in the payload
contract.

The Bronze loader writes:

- `oddspedia_bronze.event` — discovered event metadata and raw event JSON.
- `oddspedia_bronze.match_payload` — raw per-event page payloads.
- `oddspedia_bronze.market` — market names and raw odds lines.
- `oddspedia_bronze.load_status` — the date-level batch commit marker and row
  counts. Bronze loading stages all three tables, validates staged date counts,
  replaces the containing ClickHouse partition, and records `published` only
  after every table replacement succeeds.

The Bronze loader requires an accepted discovery manifest, matching inventory
checksum, terminal scrape state, and accepted per-event payload audits.
`resolve_oddspedia_events.py` additionally requires the latest `load_status` row for the
date to be `published`, so a partially replaced ClickHouse batch cannot be read
as complete Silver input.

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
python3 scripts/oddspedia/resolve_oddspedia_events.py --date 20260301 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --month 202603 --dry-run
python3 scripts/oddspedia/resolve_oddspedia_events.py --start-date 20260301 --end-date 20260307 --dry-run
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

The `--silver-reference-window-ready` option is an operator gate, not the
evidence itself. Priority generation and resolution machine-verify that
FotMob Bronze and Silver contain identical fixture-ID sets for every
previous/current/following date; priority artifacts retain that verification.

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

The standalone scraper automatically generates the priority artifact when it
is missing or stale, using the same three-day Silver reference window as the
explicit priority command. When a new matcher version selects additional links,
the scraper reconciles the selected IDs with accepted per-event JSON payloads.
Existing payloads are not scraped again; only newly selected, incomplete, or
explicitly retried IDs are processed.

Discovery also refreshes an otherwise valid date inventory when the manifest
records an incomplete discovery, saved match output, or missing/stale checksum.
This lets the standard `discover_oddspedia_events.py --date ...` command recover
rescrape candidates without requiring an extra retry flag.

See [`source-artifact-storage.md`](source-artifact-storage.md) for the shared
Historical/Live artifact hierarchy and
[`../adr/0021-add-oddspedia-as-source-domain.md`](../adr/0021-add-oddspedia-as-source-domain.md)
and [`../adr/0023-parallel-source-medallion-pipelines.md`](../adr/0023-parallel-source-medallion-pipelines.md)
for the source-isolation decisions.
