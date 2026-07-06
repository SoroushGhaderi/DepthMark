# ADR 0019: Separate Logical Duplicates from Physical Row Versions

## Status

Accepted

## Context

DepthMark warehouse tables use `ReplacingMergeTree`, which may retain several
physical versions of one sorting key until ClickHouse background merges run.
Silver DML already reads Bronze with `FINAL`, and scoped replacement is defined
in ADR 0018 in terms of convergent logical output.

A strict duplicate check over raw stored rows would therefore depend on merge
timing: two read-only runs could disagree even though downstream consumers see
the same logical data. Conversely, checking only `FINAL` would hide repeated
loads and merge backlog that remain operationally useful.

## Decision

The unified warehouse quality workflow reports two separate measures:

1. Logical duplicate identities are calculated from each table's `FINAL` view.
   They represent data-correctness failures and fail `--strict`.
2. Physical row versions are calculated from raw stored rows without `FINAL`.
   Extra versions are reported as non-failing diagnostics for repeated loads,
   merge backlog, and storage hygiene.

Bronze-to-Silver reconciliation continues to compare distinct eligible
identity sets. Gold remains duplicate-checked but is not reconciled upstream.

## Consequences

Strict quality results are deterministic with respect to background merge
timing and align with the logical rows consumed by Silver transformations.
Operators retain visibility into physical version accumulation without
misclassifying normal `ReplacingMergeTree` behavior as analytical corruption.

The workflow executes an additional read-only aggregation per validated table,
and operators must distinguish logical failures from physical diagnostics in
logs and monitoring.
