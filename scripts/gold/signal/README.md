# Gold Signal Runtime

This directory contains runtime assets for Gold signal execution.

## Structure

- `runners/`: executable signal jobs (`sig_*.py`)
- `catalogs/`: per-signal metadata and frontmatter contracts (`sig_*.md`)
- `contracts/`: signal engineering contracts
- `build_signal_activations.py`: builds row-level deterministic activations into `gold.signal_activations`

## Match-Level Activation Store

DepthMark also materializes match-grain signal activations into:

- `gold.signal_activations_match`

Assets:

- DDL: `clickhouse/gold/create_table_signal_activations.sql`
- Runner: `scripts/gold/signal/runners/sig_signal_activations_match.py`

The runner aggregates from `gold.signal_activations` into one row per:

- `match_id`
- `signal_id`

and stores deterministic `signal_match_instance_id` plus `activation_count`.

## Execution Order

When running `python scripts/gold/load_clickhouse_gold.py --part signals`:

1. Signal runner scripts write `gold_signals.sig_*` tables
2. `build_signal_activations.py` writes `gold.signal_activations`
3. `sig_signal_activations_match.py` writes `gold.signal_activations_match`
