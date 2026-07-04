# Gold Signal Runtime

This directory contains runtime assets for Gold signal execution.

## Structure

- `catalogs/`: per-signal metadata and frontmatter contracts (`sig_*.md`)
- `contracts/`: signal engineering contracts
- Activation builders live under `scripts/gold/activations/`

Signal SQL jobs are discovered and executed through `scripts/gold/run_gold_sql_jobs.py`
and shared helpers in `src/services/gold/gold_dml_runner.py`.

## Signal Activation Serving Store

DepthMark materializes activated signal rows into one serving table:

- `gold.signal_activations`

Each activation row represents one triggered source row from
`gold_signals.sig_*` and uses the current activation identity scheme:

- `signal_instance_id = SHA256("v1|signal_id|<row_identity values>")`
- `signal_id_version = 'v1'`

The `v1` value versions the activation identity scheme only. It is not a signal
definition version and should not change for ordinary SQL, threshold, or catalog
text edits when `signal_id` and `row_identity` values remain stable.

Each `gold_signals.sig_*` table also defines `signal_instance_id` with the same
deterministic identity expression. Signal INSERT SQL does not need to write the
column explicitly; ClickHouse fills it from the table DEFAULT expression.
The grouped signal DDL files drop and recreate derived signal tables for this
contract. Do not add in-place `ALTER TABLE` migration statements for
`signal_instance_id`; rerun setup and then repopulate signals.

Assets:

- Serving DDL: `clickhouse/gold/ddl/create_table_signal_activations.sql`
- Stage DDL: `clickhouse/gold/ddl/activations/create_table_signal_activations_stage.sql`
- Final insert SQL: `clickhouse/gold/dml/activations/signal_activation_final_insert.sql`
- Runner: `scripts/gold/activations/build_signal_activations.py`

The activation builder rebuilds `gold.signal_activations` from all active signal
catalogs and source signal tables. During the rebuild it briefly materializes
ephemeral `gold.signal_activations_stage`, then drops that table after the
serving table is populated. The serving table includes:

- stable identity and signal catalog metadata
- common fixture, league, venue, team, and player context when present
- `source_row_json`, a JSON copy of the source `gold_signals.sig_*` row
- `source_row_columns`, the ordered source payload column names
- match-level summary fields repeated on each activation row

Match-level summary fields include:

- `activated_signal_instance_ids` (array of raw `signal_instance_id` values)
- `activated_signal_ids` (array of unique active `signal_id` values)
- `activated_signal_entities` (array of entity types such as match/team/player)
- `activated_signal_tags` (array of unique taxonomy tags from activated signals)
- `activated_signal_names` (array of unique signal name suffixes)
- `total_signal_rows` (raw activation row count in the match)
- `unique_signal_count` (count of distinct active signal IDs)

## Execution Order

When running
`python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals`:

1. Signal SQL jobs write `gold_signals.sig_*` tables
2. The activation builder uses the same scope and replaces the corresponding
   rows in `gold.signal_activations`
