# ADR 0004: Keep Gold Scenario Bulk Disabled Until Validated

## Status

Superseded by re-enablement (scenario bulk loading is now enabled)

## Context

DepthMark has two Gold execution surfaces:

1. narrow SQL job execution through `scripts/gold/run_gold_sql_jobs.py`;
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
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance --dry-run
python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind scenario --id scenario_hollow_dominance
```

ADR 0009 later expands the generic runner so `--kind scenario` can run all
scenario SQL jobs on demand. That does not re-enable scenario execution inside
the default Gold layer loader.

Bulk scenario execution may be re-enabled only after a change validates:

- `clickhouse/gold/ddl/00_create_database.sql` creates `gold_scenarios`;
- `clickhouse/gold/ddl/01_create_scenario_tables.sql` creates every target table;
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
run yet. Operators must run selected scenario jobs through `run_gold_sql_jobs.py` or
use an intentionally validated follow-up change to restore bulk execution in
the Gold layer loader.

Documentation and runbooks should describe scenario bulk as disabled rather
than partially implemented. Future work that re-enables it must update this ADR,
`README.md`, `docs/DEVELOPMENT_ARCHITECTURE.md`, `AGENTS.md`, and the Gold
loader help text in the same change.

---

## Re-enablement Notes

Scenario bulk loading was re-enabled after validating:

1. 48 scenario SQL files (24 team, 24 player) discover correctly via
   `discover_gold_sql_jobs("scenario")`;
2. All scenario SQL files resolve to `gold_scenarios.scenario_*` targets;
3. Date-scoped dry-run execution through
   `load_clickhouse_gold.py --date 20251208 --dry-run` confirms
   48 scenario jobs + 344 signal jobs are planned correctly;
4. Scenario failures follow the same pattern as signals: fail the run, skip
   activation builders, exit code 1.

The `--part` flag now accepts `scenarios` as an explicit selector:

```bash
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part scenarios --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part all --dry-run
```
