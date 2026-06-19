# ADR 0017: Split FotMob Bronze Live and Historical Storage

## Status

Accepted

## Context

DepthMark previously stored every FotMob scrape under the same Bronze filesystem
root. That model treated the current calendar date like a completed historical
date: cached listings and match payloads could prevent refreshes, and a
currently complete listing could be compressed before the football day was
actually final.

Live and completed-date scraping have different correctness requirements.
Today's fixtures and match states can change throughout the day, while
historical payloads should be stable, resumable, and compressed after a complete
scrape. Allowing both journeys to share storage makes those guarantees difficult
to state and enforce.

## Decision

Split the FotMob Bronze filesystem into two explicit aspects:

```text
data/fotmob/
├── historical/
│   ├── matches/
│   └── daily_listings/
└── live/
    ├── matches/
    └── daily_listings/
```

`FOTMOB_BRONZE_PATH` continues to identify the common `data/fotmob` root.
Callers derive the Historical and Live aspect paths beneath that root. This
preserves the existing environment-variable contract and relocates both aspects
together when an operator configures a different Bronze root.

Historical scraping includes only dates strictly before the machine's current
local date. It retains the existing caching, resumption, and completed-date
compression behavior. Existing `data/fotmob/matches/` and
`data/fotmob/daily_listings/` content must be moved into the historical aspect
as a repository data migration. The migration creates the Historical aspect and
uses same-filesystem directory renames rather than copying payloads. It performs
collision checks first and aborts if either destination already contains data;
it never merges or overwrites automatically.

The dedicated `--today` selector starts the Live journey. It determines today
from the system clock, refreshes the daily listing, re-scrapes every currently
listed match, atomically replaces the latest per-match payloads, and never
compresses Live files. `--today --force` is invalid because Live scraping always
refreshes.

The dedicated `--yesterday` selector starts a normal Historical scrape for the
machine-local previous date and supports the normal Historical options,
including `--force`.

Historical date rules are:

- `--month` for the current month includes only completed dates through
  yesterday; it never includes today or future dates.
- On the first day of a month, `--month` for the current month is a successful
  no-op with an explicit message.
- Past months include their complete calendar range.
- Future months fail validation.
- Explicit single-date, range, and forward `--days` scopes fail when they
  contain today or a future date and direct the operator to `--today` when
  appropriate.

Live files never become canonical Historical files automatically. After a date
rolls over, a Historical scrape must independently fetch that date from FotMob.
Old Live date directories remain untouched until a separate cleanup policy is
designed. Live storage is not currently an input to Bronze loading, S3 sync, or
other medallion-layer flows.

## Consequences

- Live refresh behavior cannot accidentally reuse or compress Historical
  artifacts.
- Historical loaders, S3 sync, health checks, documentation, and configuration
  must resolve the Historical aspect explicitly.
- Existing local Bronze data requires a one-time filesystem migration before
  the new canonical paths are used.
- Live storage can grow across date rollovers until an explicit retention or
  cleanup policy is accepted.
- Promoting Live payloads into Historical storage is intentionally unsupported;
  this spends additional FotMob requests in exchange for final-data integrity.
- `--last-days` is not added; operators retain explicit ranges and the existing
  forward `--days` selector.
