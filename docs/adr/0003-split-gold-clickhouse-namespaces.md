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

Signals are high-volume and numerous. They already use `gold_signals.*` tables.
Shared activation metadata lives in `gold.*`, including
`gold.signal_activations`, `gold.signal_activations_match`, and
`gold.match_reference`.

Scenarios use `gold_scenarios.*` targets. Scenario bulk execution is disabled
while the Gold runner surface is being consolidated and scenario execution is
validated through the generic SQL runner.

Keeping every Gold table in one database would be simpler, but it makes output
ownership less clear and makes large signal/table inventories harder to reason
about operationally. Splitting every small metadata table into its own database
would add naming overhead without a strong boundary.

## Decision

DepthMark will keep three Gold ClickHouse namespaces:

- `gold_scenarios.*` for scenario output tables;
- `gold_signals.*` for signal output tables;
- `gold.*` for shared Gold metadata, activation, and reference tables.

Scenario SQL and DDL target `gold_scenarios.*`. Signal SQL and DDL should
continue to target `gold_signals.*`. Shared activation builders should continue
to write to `gold.*`.

The helper functions in `src.utils.gold_databases` remain the canonical way for
Python code to resolve these database names.

## Consequences

This keeps downstream-facing product outputs separated from shared metadata and
prevents the large signal table inventory from crowding scenario and activation
tables.

It makes grants, destructive drops, backfills, and future retention policies
easier to scope by output family.

Scenario bulk loading should remain disabled until scenario execution is
validated through the generic Gold SQL runner and intentionally re-enabled. New
scenario work should target `gold_scenarios.scenario_*`.

Any command, contract, or documentation that names Gold tables must use the
specific namespace rather than saying `gold.*` as a catch-all.
