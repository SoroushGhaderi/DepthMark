# ADR 0014: Use Single Enriched Signal Activation Serving Table

## Status

Accepted

## Context

DepthMark previously materialized two shared Gold activation tables:

- `gold.signal_activations`, a thin row-level metadata index over activated
  `gold_signals.sig_*` rows.
- `gold.signal_activations_match`, a match-level aggregate containing arrays of
  activated signal IDs, names, entities, and tags.

That design kept activation identity stable, but it forced downstream consumers
such as Touchdesk to discover the related `gold_signals.sig_*` table for each
activation before they could read the actual football metrics and explanatory
stats. The match aggregate helped answer "which signals fired in this match?",
but it did not provide the source row details needed for analysis or serving.

The main alternatives were:

1. keep the thin activation index and teach downstream services to join back to
   hundreds of typed signal tables;
2. keep `gold.signal_activations_match` and add another detail endpoint/table;
3. materialize one enriched activation serving fact that includes identity,
   catalog metadata, common fixture/team/player context, match-level summary
   fields, and the source signal row payload.

The third option intentionally duplicates some data, but it gives consumers a
single stable table to query while preserving typed `gold_signals.sig_*` tables
for analytical development and debugging.

## Decision

DepthMark will use one shared activation serving table:

```text
gold.signal_activations
```

There will be no separate `gold.signal_activations_match` table and no
`gold.match_reference` view created by the activation DDL.

Each activation row represents one triggered row from a `gold_signals.sig_*`
source table and includes:

- `signal_instance_id`;
- `signal_id_version`;
- parsed signal taxonomy fields from `signal_id`;
- common match, team, opponent, player, and score context when present;
- match-level activation summary fields previously held in
  `gold.signal_activations_match`;
- `source_table`;
- `source_row_json`, a JSON copy of the source `gold_signals.sig_*` row;
- `source_row_columns`, the source payload column names.

Each `gold_signals.sig_*` table will also define `signal_instance_id` in its
`CREATE TABLE` statement with a deterministic `DEFAULT` expression based on the
catalog `row_identity`. Signal INSERT SQL does not need to write this column
explicitly.

This schema change is a drop/recreate migration for derived signal output
tables. The grouped signal DDL files use `DROP TABLE IF EXISTS` before each
`CREATE TABLE`; they must not use `ALTER TABLE` for the `signal_instance_id`
column. Operators should recreate the Gold signal tables and repopulate them
through the Gold signal jobs.

Activation rebuilds remain full-table rebuilds as accepted in ADR 0011. The
builder may stage rows before replacing `gold.signal_activations`, but it must
not introduce date-scoped or partition-scoped activation rebuilds without a
future ADR defining safe replacement semantics.

## Consequences

Benefits:

- Downstream services can query one table for activated signal identity,
  fixture context, match-level activation summary, and signal-specific details.
- `signal_instance_id` is available both in the serving table and in the typed
  source signal tables.
- The activation builder can preserve stable CLI behavior while adding richer
  serving output.
- The typed `gold_signals.sig_*` tables remain the source for signal-specific
  analytical schemas.

Costs:

- `source_row_json` duplicates source signal data and is less type-friendly than
  the source `gold_signals.sig_*` tables.
- Match-level summary arrays are repeated on every activation row for the same
  match.
- Existing `gold_signals.sig_*` data is dropped during setup and must be
  repopulated by rerunning Gold signal jobs.

Follow-up constraints:

- Consumer-facing analytics should use typed columns in `gold.signal_activations`
  when a field is common and use `source_row_json` for signal-specific details.
- If a signal-specific metric becomes broadly queried across services, promote
  it to a typed common column through a separate schema change instead of
  repeatedly parsing JSON in downstream projects.
- Changing `row_identity` remains an activation identity migration concern under
  ADR 0006.
