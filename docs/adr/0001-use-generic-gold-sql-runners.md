# ADR 0001: Use Generic Gold SQL Runners

## Status

Accepted

## Context

DepthMark Gold signal and scenario transformation logic lives in SQL files under
`clickhouse/gold/`. Python runner files currently act mostly as operational
wrappers around those SQL files: they locate SQL, execute it in ClickHouse, log
results, and optimize target tables.

The project has many Gold outputs, so maintaining one Python runner file per
signal or scenario creates boilerplate and makes contribution rules heavier than
the underlying execution model requires. At the same time, individual
signal/scenario execution remains useful for development, debugging, backfills,
and narrow validation.

## Decision

Gold signal and scenario SQL jobs should remain individually executable, but
through a generic CLI runner instead of new per-signal or per-scenario Python
runner files.

The generic runner should discover the requested SQL job, execute it with the
same ClickHouse and logging conventions as the Gold loader, and preserve narrow
selection by job kind and identifier. For example:

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak
python scripts/gold/run_sql_job.py --kind scenario --id scenario_team_shooting_goals
```

Bulk Gold loading should reuse the same generic execution path where practical.
New Gold work should add or update SQL and catalog/contract documentation rather
than adding new handwritten per-output Python wrappers.

## Consequences

This keeps SQL as the source of transformation logic while making Python
responsible for discovery, execution, validation, logging, and reporting.

It reduces per-signal and per-scenario boilerplate, makes runner behavior more
consistent, and keeps individual execution available through one command
surface.

The migration should be backward-compatible where practical. Existing runner
files can remain until the generic runner and loader path are proven, then be
removed or deprecated intentionally with matching documentation updates.

The generic runner must preserve operational safety expectations from
`docs/SCRIPTS_CONTRACT.md`, especially deterministic summaries, useful error
context, and non-mutating `--dry-run` behavior.
