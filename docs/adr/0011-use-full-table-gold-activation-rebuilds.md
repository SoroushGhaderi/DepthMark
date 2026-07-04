# ADR 0011: Use Full-Table Gold Activation Rebuilds

## Status

Superseded by ADR 0018 for scoped runs. Full-table activation rebuilds remain
the explicit `--full-history` behavior.

## Context

DepthMark materializes Gold signal activation metadata in
`gold.signal_activations`. ADR 0014 later enriched this table and retired the
separate `gold.signal_activations_match` aggregate. Activation rows are derived
from active signal catalog frontmatter and the current contents of
`gold_signals.sig_*` output tables.

The current activation builders rebuild both metadata tables after successful
signal execution:

- `scripts/gold/activations/build_signal_activations.py` rebuilds
  `gold.signal_activations` with one activation row per active signal output
  row.

ADR 0006 already keeps activation IDs deterministic across normal reruns and
ordinary signal SQL or catalog changes when `signal_id` and `row_identity`
values are unchanged. That makes full rebuilds operationally safe for identity
stability.

The alternative is an incremental, date-scoped, or partition-scoped activation
rebuild. That would reduce work for narrow backfills, but it would require every
upstream signal output table to expose a trustworthy replacement contract for
the same scope. Without that contract, a scoped activation rebuild can preserve
stale activations, miss removals from changed signal logic, or produce
match-level summaries that no longer reflect all active signal rows.

## Decision

DepthMark will keep Gold activation rebuilds as full-table rebuilds.

The supported rebuild flow is:

1. run Gold signal SQL jobs into `gold_signals.sig_*`;
2. rebuild all rows in `gold.signal_activations` from all active signal catalogs
   and available signal output tables;
3. run Gold contracts after the activation builder completes.

Activation builders may continue to use `TRUNCATE TABLE` for the activation
metadata tables before inserting rebuilt rows. They must remain idempotent for a
fixed set of active catalogs and signal output rows.

DepthMark will not add incremental, date-scoped, or partition-scoped activation
rebuilds until a later ADR defines partition-safe replacement semantics for the
upstream signal output tables and the derived match-level activation aggregate.

## Consequences

Gold activation metadata remains easy to reason about: it is always a complete
derived serving index over the active signal outputs at rebuild time.

Reruns may do more work than strictly necessary for a small date or partition
backfill, but they avoid partial-rebuild correctness traps while the signal
table replacement contract is still implicit.

Operational recovery is straightforward. If activation metadata is suspected to
be stale or inconsistent, operators should rerun the Gold loader or the two
activation builders rather than attempting a scoped activation patch.

Future scoped rebuild work must define how changed or removed signal rows are
deleted from `gold.signal_activations` and must include verification that a
scoped run matches a full-table rebuild for the same source data.
