# ADR 0020: Keep ClickHouse Optimization Out of Setup

## Status

Accepted

## Context

DepthMark setup scripts create the Bronze, Silver, and Gold ClickHouse schemas.
They are part of normal bootstrap and may be run repeatedly during local setup,
schema refreshes, and production deployment preparation.

The Bronze layer previously included `clickhouse/bronze/99_optimize_tables.sql`,
which ran full-table `OPTIMIZE TABLE ... FINAL DEDUPLICATE` statements. The
shared setup helper discovered that file and ran it as part of ordinary setup.
That made setup perform expensive table maintenance and silently cleared the
physical row-version evidence that ADR 0019 intentionally exposes as a
non-failing operational diagnostic.

ClickHouse `ReplacingMergeTree` background merges remain the routine storage
cleanup mechanism. Strict correctness checks use logical `FINAL` reads, while
raw physical versions are useful signals for repeated loads, merge backlog, and
operator follow-up.

## Decision

ClickHouse layer setup is schema-only. Setup discovery excludes SQL files whose
names contain `optimize`, and DepthMark does not keep layer-level
`99_optimize_tables.sql` files in the normal SQL tree.

Full-table optimization is not a setup concern. If DepthMark later needs manual
warehouse compaction, it should be introduced as an explicit maintenance
workflow with dry-run planning and operator-selected layer/table scope.

Scoped replacement workflows may still optimize temporary calculation or
replacement tables when that optimization is part of preparing a validated
replacement artifact. Those operations are separate from routine layer setup
and do not define a general full-table maintenance policy.

## Consequences

Normal setup no longer rewrites populated warehouse tables or deduplicates them
as a side effect.

ADR 0019's physical row-version diagnostics become more meaningful because
setup no longer clears storage-health evidence. Operators should interpret
extra physical versions as a maintenance signal, not as a strict correctness
failure.

Introducing future manual compaction requires a deliberate operator command and
documentation update rather than adding optimization SQL back into setup.
