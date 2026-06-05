# Gold Signal Runtime

This directory contains runtime assets for Gold signal execution.

## Structure

- `runners/`: executable signal jobs (`sig_*.py`)
- `catalogs/`: per-signal metadata and frontmatter contracts (`sig_*.md`)
- `contracts/`: signal engineering contracts
- Activation builders now live under `scripts/gold/activations/`

## Match-Level Activation Store

DepthMark also materializes match-grain signal activations into:

- `gold.signal_activations_match`

Assets:

- DDL: `clickhouse/gold/create_table_signal_activations.sql`
- Runner: `scripts/gold/activations/build_signal_activations_match.py`

The runner aggregates from `gold.signal_activations` into one row per:

- `match_id`

and stores:

- `activated_signal_instance_ids` (array of raw `signal_instance_id` values)
- `activated_signal_ids` (array of unique active `signal_id` values)
- `activated_signal_entities` (array of entity types such as match/team/player)
- `activated_signal_tags` (array of unique taxonomy tags from activated signals)
- `activated_signal_names` (array of unique signal name suffixes)
- `total_signal_rows` (raw activation row count in the match)
- `unique_signal_count` (count of distinct active signal IDs)

## Execution Order

When running `python scripts/gold/load_clickhouse_gold.py --part signals`:

1. Signal runner scripts write `gold_signals.sig_*` tables
2. `scripts/gold/activations/build_signal_activations.py` writes `gold.signal_activations`
3. `scripts/gold/activations/build_signal_activations_match.py` writes `gold.signal_activations_match`
