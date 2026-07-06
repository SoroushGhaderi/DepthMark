# ADR 0018: Use Scope-Aware Warehouse Replacement

## Status

Accepted

Supersedes ADR 0011 for Gold activation rebuild scope.

## Context

Before this decision, Silver truncated each target table before rebuilding it
from the complete Bronze snapshot. Gold scenario and signal jobs appended their
current results and relied on `ReplacingMergeTree` convergence to collapse
repeated business keys. That did not reliably remove rows that stopped
qualifying after a source correction. Gold activation metadata was rebuilt
through a full-table stage and swap under ADR 0011.

DepthMark now needs explicit date, month, and full-history execution scopes.
Date- and month-scoped runs must preserve rows outside their selected output
scope while remaining idempotent and removing corrected rows that no longer
qualify. Some transformations may read history before the output boundary, so
input context and replaced output scope cannot be treated as the same range.

Keeping ADR 0011's full-table activation rebuild during a scoped Gold run would
make a narrow run mutate unrelated dates. Skipping activation rebuilding would
leave the serving table stale after scoped signal replacement.

## Decision

Silver tables, Gold scenario tables, Gold signal tables, and
`gold.signal_activations` will follow the explicit warehouse execution scope.

- A date or month run replaces only rows with match-date lineage inside the
  selected output scope.
- A full-history run explicitly replaces all derived history.
- Jobs may read additional historical context when required, but that context
  does not widen the output rows being replaced.
- Scoped activation rebuilding is part of scoped Gold signal processing; it is
  not skipped and does not trigger an unrelated full-table rebuild.
- Replacement must remove rows that disappeared or stopped qualifying and must
  not use `inserted_at` as output lineage.
- Because derived tables are partitioned by calendar month, a date run rebuilds
  the containing monthly partition in staging: rows outside the selected date
  are copied from the current target and rows for the selected date are
  recomputed. The validated partition is installed with `REPLACE PARTITION`
  rather than a visible delete-then-insert sequence.
- A month run stages and replaces the selected monthly partition directly.
- A selected Silver or Gold batch uses two phases. First, every selected table
  is staged and validated without changing its target. Only after all staging
  jobs succeed does the commit phase install the prepared partitions or
  full-history tables.
- A staging failure leaves every existing target unchanged. ClickHouse does not
  provide a transaction spanning all target tables, so a commit-phase failure
  may leave a partially committed batch. The loader stops, reports the exact
  committed and pending tables, retains enough staging state for diagnosis,
  and a rerun of the same scope converges safely.
- Activation rebuilding and Gold contract checks run only after all selected
  signal-table commits succeed.
- Dry-run reports replacement and context ranges without mutating ClickHouse.

The implementation may choose different safe replacement mechanics by table
category. This ADR defines the scope and correctness contract, not one universal
delete-and-insert algorithm.

## Consequences

ADR 0011's operationally simple full-table activation rebuild remains valid
only for explicit full-history execution. Scoped runs require stronger
match-date contracts and more deliberate recovery behavior across upstream
signal outputs and activation metadata.

Rerunning a fixed scope can converge to the same logical result and can remove
stale derived rows without disturbing unrelated dates. The cost is additional
planning, staging, validation, and tests around partition boundaries and
partial failures.
