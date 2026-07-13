# ADR 0003: Split Gold ClickHouse Namespaces

## Status

Accepted

## Context

DepthMark Gold contains two kinds of product output and one kind of shared
metadata:

1. scenario result tables, one table per scenario;
2. signal result tables, one table per signal;
3. shared Gold metadata and activation tables, such as signal activation IDs and
   match-level activation aggregates.

Keeping every Gold table in one database would be simpler, but it makes output
ownership less clear and makes large signal/table inventories harder to reason
about operationally. Splitting every small metadata table into its own database
would add naming overhead without a strong boundary.

**Current state:** At the time of original ADR acceptance, signal DDL files
correctly targeted `gold_signals.*`, but all 344 signal INSERT SQL files used
`gold.sig_*`. The generic runner at `scripts/gold/sql_jobs.py:152-154` performed
runtime string rewriting to redirect `gold.sig_*` to `gold_signals.*` at
execution time. Scenario SQL files were already consistent — all 48 used
`gold_scenarios.*` directly, with no rewriting needed.

This created a source-code-to-runtime divergence: SQL files in the repository
said `gold.sig_*` but data landed in `gold_signals.*`. Running a signal SQL file
directly against ClickHouse (bypassing the runner) would write to the wrong
database. The rewriting convention was also fragile — a blind `str.replace()`
across the entire SQL text.

## Decision

DepthMark will keep three Gold ClickHouse namespaces:

- `gold_scenarios.*` for scenario output tables;
- `gold_signals.*` for signal output tables;
- `gold.*` for shared Gold metadata, activation, and reference tables.

All SQL files — DDL and INSERT — must target the correct namespace directly.
Signal INSERT SQL files must be migrated from `gold.sig_*` to `gold_signals.*`,
matching the pattern already used by scenario SQL files. The runtime namespace
rewriting in `scripts/gold/sql_jobs.py` becomes dead code after migration and
must be removed.

The helper functions in `src/warehouse/databases.py` remain the canonical way for
Python code to resolve these database names.

## Consequences

This keeps downstream-facing product outputs separated from shared metadata and
prevents the large signal table inventory from crowding scenario and activation
tables.

It makes grants, destructive drops, backfills, and future retention policies
easier to scope by output family.

After migration, SQL files are self-describing about their target database.
Developers can read any SQL file and know exactly where data lands without
understanding runner internals.

The migration updates 344 signal INSERT SQL files (replacing `INSERT INTO
gold.sig_` with `INSERT INTO gold_signals.sig_`) and removes the rewriting
logic from `sql_jobs.py` lines 152-154. Scenario rewriting on lines 149-150 is
already dead code (scenario SQL files use `gold_scenarios.*` directly) and should
be removed in the same change.

Any command, contract, or documentation that names Gold tables must use the
specific namespace rather than saying `gold.*` as a catch-all.

Scenario bulk loading should remain disabled until scenario execution is
validated through the generic Gold SQL runner and intentionally re-enabled. New
scenario work should target `gold_scenarios.scenario_*`.
