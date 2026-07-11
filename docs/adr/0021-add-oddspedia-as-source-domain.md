# ADR 0021: Add Oddspedia as an Isolated Source Domain

## Status

Accepted

## Context

DepthMark's existing warehouse is FotMob-only: `bronze.*` preserves FotMob
payloads and `silver.match` is the conformed FotMob fixture reference. The
OddsHarvest football scraper independently discovers Oddspedia fixtures and
extracts odds, but its events must be categorized by the three FotMob coverage
levels (`xG`, `ratings`, and `lower`).

Putting Oddspedia rows in existing FotMob Bronze tables would corrupt source
fidelity. Treating an unverified fuzzy match as a shared fixture would also
silently make incorrect analytical claims.

## Decision

DepthMark supports Oddspedia as an isolated source domain.

This decision supersedes ADR 0013's FotMob-only scope now that a concrete
second source and its isolated contracts exist.

- Raw Oddspedia artifacts live under `data/oddspedia/`; they remain separate
  from FotMob Historical and Live Bronze storage.
- Structured Oddspedia source facts live in the `oddspedia_bronze` ClickHouse
  database, not in `bronze.*`.
- `silver.match` remains the canonical FotMob fixture reference and is never
  rewritten by Oddspedia ingestion.
- `silver.oddspedia_match_resolution` records the auditable relationship from
  an Oddspedia event to at most one FotMob match. It may be matched,
  ambiguous, unmatched, or unresolved.
- A business coverage category is emitted only from a confirmed match or from
  a complete reference window that safely establishes `not_covered`.

## Consequences

Benefits:

- Existing FotMob contracts and operational commands remain stable.
- Raw source fidelity and provenance are retained.
- Match-resolution policy can evolve and be rerun without rescraping either
  source.

Costs:

- DepthMark now has source-specific Oddspedia scripts, schemas, and tests.
- The resolver and team-alias policy become a maintained data-quality surface.

Follow-up constraints:

- Do not add Oddspedia fields to FotMob Bronze schemas.
- Do not automatically select a low-confidence or ambiguous candidate.
- Keep the old OddsHarvest project operational until migration parity is
  verified.
