# ADR 0009: Retire Legacy Gold Per-Output Runners

## Status

Accepted

## Context

ADR 0001 established `scripts/gold/run_gold_sql_jobs.py` as the generic execution
surface for Gold signal and scenario SQL jobs. The repository still carried
hundreds of generated per-output Python wrappers under
`scripts/gold/signal/runners/` and `scripts/gold/scenario/`, plus catalog
references that pointed operators back to those wrappers.

Keeping those wrappers would preserve short-term command compatibility, but it
would also keep a large generated review surface, duplicate ClickHouse execution
logic, and leave new contributors with two apparent ways to run the same Gold
output. The wrappers also lacked the broader dry-run and batch-selection
behavior expected from the generic runner.

DepthMark now needs the generic runner to support multiple selection styles:

- no `--kind`: all Gold scenario and signal SQL jobs;
- `--kind scenario`: all scenario SQL jobs;
- `--kind signal`: all signal SQL jobs;
- `--id`: one exact scenario or signal job;
- `--entity` or `--family`: filtered signal batches.

## Decision

DepthMark will remove the legacy per-output Gold Python runner files without a
compatibility shim. `scripts/gold/run_gold_sql_jobs.py` is the only supported command
surface for executing individual or selected Gold SQL jobs outside the layer
loader.

The generic runner treats omitted selectors as `all`:

```bash
python3 scripts/gold/run_gold_sql_jobs.py --full-history --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --id sig_player_shooting_goals_shot_conversion_peak --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity player --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --full-history --kind signal --family shooting_goals --dry-run
```

Signal `--entity` and `--family` filters are separate selectors and must not be
combined in one command. Scenario jobs do not support those filters until
scenario metadata has an equivalent stable grouping contract.

ADR 0018 later made one execution scope mandatory. Omitted job selectors still
mean all jobs, but omitted scope selectors are rejected.

This decision does not re-enable scenario execution inside
`scripts/gold/load_clickhouse_gold.py`. That loader decision remains governed by
ADR 0004.

## Consequences

Gold execution has one CLI surface for per-id, per-kind, and signal batch runs.
Catalogs and runbooks must point to `scripts/gold/run_gold_sql_jobs.py` rather than
per-output wrapper files. Signal family selection is modeled as its own
batch selector, not as an additional narrowing flag alongside entity.

Removing the wrappers is a breaking command-surface cleanup for anyone invoking
the old generated files directly. The project accepts that break because the
documented command surface already names the generic runner, and keeping shims
would preserve duplicate operational behavior.

New Gold work must add SQL, DDL/contracts, catalog metadata, and docs as needed,
but must not add new handwritten or generated per-output Python runners.
