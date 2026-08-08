# ADR 0022: Prioritize Oddspedia Links Against DepthMark Silver

## Status

Accepted

## Context

Oddspedia discovery currently produces a source-faithful `match_links.json`
inventory and the scraper fetches every discovered event page. DepthMark
already has the canonical FotMob fixtures in `silver.match`, including the
coverage level that determines the downstream analytical value of a fixture.

Oddspedia must run after the corresponding DepthMark workflow. Selecting
Oddspedia pages before comparing them to the completed DepthMark reference
window wastes collection capacity and makes the selection impossible to audit.
Mutating `match_links.json` with derived decisions would also mix provider
facts with DepthMark-owned metadata.

## Decision

Oddspedia Event Intake gains a links-layer priority stage between discovery and
page scraping.

- The canonical command entry points are the phase-specific scripts:
  `discover_events.py`, `prioritize_events.py`, `scrape_matches.py`,
  `run_pipeline.py`, and `status.py`. The former `events.py` umbrella and
  `football.py` remain deprecated compatibility wrappers.
- `prioritize_events.py --date YYYYMMDD --silver-reference-window-ready` reads the
  accepted `match_links.json` inventory and the corresponding
  `silver.match` window for the previous, current, and next calendar dates.
  It fails closed without the explicit readiness assertion and emits no new
  decision artifact from a partial reference window.
- Priority generation reuses the existing `OddspediaMatchResolver` policy,
  aliases, scoring thresholds, and rule version. The later Silver resolver
  reuses the same logic to verify and persist the relationship after the raw
  page payload is loaded.
- The previous/current/next-day window is the only date constraint. Within
  that window, resolution ranks normalized home and away team names only;
  kickoff, league, and other provider metadata never affect the decision.
- Approximate team matching canonicalizes non-identifying club designators and
  equivalent `II` / `2` second-team notation, then uses auditable character
  similarity, token reordering, reviewed aliases, distinctive-name containment,
  and a unique-token rescue. The rescue is accepted only when the opposite
  side is exact or a reviewed alias; every match still requires a unique
  high-confidence home/away pair.
- Each prioritized date has one deterministic, replaceable snapshot at
  `data/oddspedia/historical/link_priorities/YYYYMM/YYYYMMDD/prioritized_match_links.json`.
  Its metadata includes the prioritized date, source-inventory checksum,
  checked reference dates, matcher/policy version, and generation timestamp.
- The priority artifact contains every discovered link as a compact decision
  ledger. Each record is keyed by `oddspedia_id`; `providers.oddspedia` and
  `providers.fotmob` use the identical contract (`id`, team names,
  `scheduled_at_utc`, `competition`, `coverage_level`, and `url`) for direct
  comparison. The `resolution` object contains the DepthMark-owned outcome,
  score, margin, team-name rules, and priority. Window and policy metadata
  remain at the artifact root. The raw
  source record remains untouched in `match_links.json` and is rehydrated by
  ID for scraping.
- `resolution` produces the existing statuses: `matched`, `ambiguous`,
  `unmatched`, or `unresolved`. A uniquely matched link receives its FotMob
  coverage tier (`xG`, `ratings`, or `lower`). `ambiguous` and `unresolved`
  are never automatic scrape candidates.
- `scrape_matches.py` and `run_pipeline.py` select from the priority artifact
  using `--priority-tier {xG,ratings,lower,unmatched}`. A standalone scrape
  automatically creates or refreshes the artifact before selecting links. The
  selection is inclusive:
  `ratings` includes `xG`, `lower` includes every uniquely matched tier, and
  `unmatched` includes every eligible tier plus unmatched links. The default
  is `lower`.
- `run_pipeline.py` performs `discover -> prioritize -> scrape`. A priority-selected
  scrape refreshes a missing or stale priority artifact whose source-inventory
  checksum or matcher rule version no longer matches `match_links.json` and
  the active resolver policy.
- When a new matcher version expands a priority selection, the scraper treats
  accepted per-event payload JSON as the completion record. It skips existing
  payloads and scrapes only newly selected, incomplete, or explicitly retried
  event IDs.
- The date manifest stores a `priority_run` summary: artifact path and
  checksum, prioritized date, matcher/policy version, selected tier, selected
  count, and counts by validation status and priority tier. Per-link decisions
  remain only in the priority artifact.

The priority artifact has this logical shape (additional diagnostic fields are
allowed, but these boundaries are required):

```json
{
  "schema_version": "v6",
  "prioritized_date": "YYYYMMDD",
  "source_inventory": {"path": ".../match_links.json", "sha256": "..."},
  "reference_window": {"dates": ["YYYYMMDD", "YYYYMMDD", "YYYYMMDD"]},
  "matcher": {"rule_version": "v5"},
  "links": [
    {
      "oddspedia_id": "...",
      "providers": {
        "oddspedia": {"id": "...", "home_team": "...", "away_team": "...", "scheduled_at_utc": "...", "competition": "...", "coverage_level": null, "url": "..."},
        "fotmob": {"id": "...", "home_team": "...", "away_team": "...", "scheduled_at_utc": "...", "competition": "...", "coverage_level": "xG", "url": null}
      },
      "resolution": {
        "status": "matched",
        "coverage_category": "xG",
        "priority": "xG",
        "confidence": "exact",
        "score": 100.0,
        "margin": 100.0,
        "rules": {"home": "exact", "away": "exact"}
      }
    }
  ]
}
```

## Operational invariants

- Priority and scraping may consume only an accepted discovery inventory with
  a matching checksum. A missing or stale checksum refreshes discovery; it is
  never treated as implicit evidence that the old inventory is still valid.
- A complete date may be either a fully paginated inventory or a verified empty
  result represented as `no_events`. Limited fallback snapshots remain
  diagnostic and retryable rather than accepted source inventories.
- Priority generation and later resolution machine-verify exact fixture-ID set
  equality between FotMob Bronze and Silver for every date in the
  previous/current/following window. The operator flag is required, but it is
  not a substitute for that verification.
- Date-scoped mutating commands serialize through the Oddspedia sport/date
  lock. Month operations report failure if any requested date is not accepted.
- Oddspedia Bronze stages `event`, `match_payload`, and `market` together and
  writes `oddspedia_bronze.load_status=published` only after the complete batch
  is replaced. Resolution refuses `staging` or `failed` dates.

## Consequences

Benefits:

- Oddspedia collection capacity is directed first to fixtures DepthMark can
  analyze most deeply.
- Every excluded or selected event remains explainable from one date-scoped
  decision artifact and the linked manifest summary.
- The same matcher governs pre-scrape selection and post-load Silver
  resolution, preventing divergent canonical fixture assignments.
- Provider source facts remain separate from DepthMark-derived decisions.

Costs:

- Oddspedia ingestion now depends operationally on a completed three-day
  DepthMark Silver reference window.
- Priority artifacts and their manifest checks require staleness validation on
  every priority-selected scrape.
- Existing callers should migrate from the deprecated wrappers to the
  phase-specific scripts during the compatibility period.
- A policy change invalidates older priority artifacts; a priority-selected
  scrape regenerates them before selecting links.

Follow-up constraints:

- Do not infer a completed reference window from `silver.match` row counts;
  dates with no fixtures are valid. Use `--silver-reference-window-ready` until a
  durable completion ledger is separately designed.
- Do not turn `ambiguous` or `unresolved` into an `unmatched` priority tier.
- Preserve `match_links.json` as source-fidelity input; priority data belongs
  only under `data/oddspedia/historical/link_priorities/`.
