# ADR 0008: Author Signal Catalogs In Markdown

## Status

Accepted

## Context

DepthMark stores signal metadata in markdown files under
`scripts/gold/signal/catalogs/*.md`. Each file contains YAML frontmatter with
the signal identifier, status, taxonomy, grain, row identity, and asset paths,
followed by human-readable explanation and output schema documentation.

The MongoDB `signals` collection is populated by
`scripts/mongodb/sync_signal_catalogs.py`. The sync script stores flattened
query fields, the full frontmatter object, markdown body, source path, and
embedded SQL/runner contents with hashes.

Without a documented ownership rule, signal metadata could be edited in two
places: markdown files in Git and MongoDB documents at runtime. That would make
catalog reviews, historical diffs, local dry-runs, and reproducible rebuilds
harder to trust.

There was also namespace drift in catalog metadata. ADR 0003 split Gold outputs
into `gold_scenarios.*`, `gold_signals.*`, and shared metadata in `gold.*`, but
signal catalog `asset_paths.table` values still pointed at `gold.<signal_id>`.

## Decision

DepthMark signal catalog metadata is authored in markdown frontmatter under
`scripts/gold/signal/catalogs/*.md`.

The markdown frontmatter is the source of truth for:

- `signal_id`;
- `status`;
- `entity`, `family`, and `subfamily`;
- `grain`;
- `row_identity`;
- `asset_paths`.

MongoDB is a synchronized serving/query store for that authored metadata. Signal
catalog edits must originate in markdown and be synced into MongoDB through
`scripts/mongodb/sync_signal_catalogs.py`. Runtime edits directly in MongoDB
are not canonical and may be overwritten by the next sync.

Signal catalog `asset_paths.table` must use the actual signal output namespace:

```text
gold_signals.<signal_id>
```

Shared activation metadata remains in `gold.*`, including
`gold.signal_activations` and `gold.signal_activations_match`.

The sync script validates the table namespace during dry-run and normal sync so
stale catalog metadata fails before reaching MongoDB.

## Consequences

Catalog review remains Git-native. Frontmatter diffs show changes to signal
taxonomy, row identity, status, and linked assets before those changes are
published to MongoDB.

MongoDB can be rebuilt from markdown catalogs and should be treated as
derivative state for serving and querying, not as the authoring surface.

Changing `row_identity` remains an activation identity migration concern under
ADR 0006.

The catalog namespace now matches ADR 0003: signal output tables live in
`gold_signals.*`, while shared activation metadata lives in `gold.*`.

Frontmatter validation runs only at sync time (`sync_signal_catalogs.py
--dry-run`) and activation time (`build_signal_activations.py`). There is no
pre-commit hook or CI check that validates catalogs before merge. A malformed
catalog can reach `main` and fail at deploy time. This is accepted risk — the
sync script catches structural errors, and the current workflow runs dry-run
before deploying. Adding pre-commit hooks or CI validation is an implementation
detail, not an architectural boundary change.

The `split_frontmatter` function is duplicated between
`sync_signal_catalogs.py:60-76` and `build_signal_activations.py:124-140`
(identical logic, different type hint styles). This is a maintenance cost of
the markdown-first approach and a candidate for extraction into a shared utility
module.
