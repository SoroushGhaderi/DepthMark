# ADR 0004: Keep Gold Scenario Bulk Disabled Until Validated

## Status

Accepted

## Context

DepthMark has two Gold execution surfaces:

1. narrow SQL job execution through `scripts/gold/run_sql_job.py`;
2. bulk Gold orchestration through `scripts/gold/load_clickhouse_gold.py`.

Scenario SQL has been migrated to the `gold_scenarios.*` namespace and can be
resolved by the generic SQL job runner. The bulk Gold loader currently runs
signal jobs and signal activation builders, but intentionally returns no
scenario jobs from its selected job groups.

Re-enabling scenario bulk loading immediately would be convenient, but it would
turn a namespace migration into a wider operational change. Scenario SQL has a
large output surface, and bulk execution should be proven against ClickHouse
DDL, source-table availability, failure reporting, and rerun behavior before it
becomes part of the default Gold run again.

## Decision

DepthMark will keep scenario bulk execution disabled in
`scripts/gold/load_clickhouse_gold.py` until the generic scenario SQL path has
been validated intentionally.

Scenario development, debugging, and one-off validation should use the generic
runner:

```bash
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance --dry-run
python scripts/gold/run_sql_job.py --kind scenario --id scenario_hollow_dominance
```

Bulk scenario execution may be re-enabled only after a change validates:

- `clickhouse/gold/00_create_database.sql` creates `gold_scenarios`;
- `clickhouse/gold/01_create_scenario_tables.sql` creates every target table;
- every discovered scenario SQL file resolves to a `gold_scenarios.scenario_*`
  target;
- at least one representative team scenario and one representative player
  scenario execute successfully against ClickHouse;
- failure summaries and exit codes remain compatible with
  `docs/SCRIPTS_CONTRACT.md`.

## Consequences

The default Gold loader remains safer during the namespace migration and signal
runner consolidation work.

The tradeoff is that scenario backfills are not part of the default Gold bulk
run yet. Operators must run individual scenarios through `run_sql_job.py` or use
an intentionally validated follow-up change to restore bulk execution.

Documentation and runbooks should describe scenario bulk as disabled rather
than partially implemented. Future work that re-enables it must update this ADR,
`README.md`, `docs/DEVELOPMENT_ARCHITECTURE.md`, `AGENTS.md`, and the Gold
loader help text in the same change.
