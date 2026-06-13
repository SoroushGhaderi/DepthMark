# ADR 0010: Introduce Src Application Services Behind Script Entrypoints

## Status

Accepted

## Context

DepthMark's supported operational command surface lives under `scripts/`.
ADR 0002 keeps the pipeline orchestrator aligned with that command surface by
calling layer entry points through CLI subprocesses. The scripts therefore
remain the user-facing and automation-facing boundary for local runs, Docker
runs, backfills, dry-runs, alerts, and exit-code semantics.

At the same time, several scripts already contain reusable workflow behavior:
SQL job discovery and execution, ClickHouse client setup, contract checks,
activation builders, reporting, and layer summaries. Some of that behavior is
also shared through `src/` helpers. Leaving all workflow coordination inside
scripts makes narrow CLI compatibility clear, but it also makes behavior harder
to test without invoking full scripts and encourages duplication across layer
entry points.

Moving the command surface itself into importable services would conflict with
the current runbooks and with ADR 0002. Moving analytical transformations into
Python services would also conflict with ADR 0007, which says Silver and Gold
analytical logic belongs in ClickHouse SQL.

## Decision

DepthMark introduces stable, layer-specific application services under
`src/services/` behind the existing script entry points.

Scripts continue to own:

- CLI parsing and argument validation;
- `.env` loading and import-path bootstrap needed for direct script execution;
- user-facing command compatibility, help text, exit codes, and dry-run flags;
- final translation of service results into process exit status;
- ClickHouse client creation and teardown;
- `send_layer_completion_alert()` calls using service result dataclasses.

Application services under `src/services/` own reusable workflow coordination:

- discovering and planning SQL jobs;
- executing SQL and metadata jobs through existing storage helpers;
- running activation builder subprocesses;
- running contract checks and validation;
- building deterministic runtime summaries as result dataclasses.

Application services must not own reusable Silver or Gold football logic,
scenario criteria, signal trigger criteria, metrics, or downstream analytical
table derivations. Those remain in versioned ClickHouse SQL unless a later ADR
grants a narrow exception.

Shared execution infrastructure (job discovery, resolution, execution) lives in
`src/services/gold/sql_jobs.py`, extracted from the former
`scripts/gold/sql_jobs.py`. This module is imported by both `GoldService` and the
standalone `run_sql_job.py` entry point.

## Consequences

Scripts remain the documented operational boundary, so existing automation and
runbooks continue to call the same commands.

Service APIs give tests a stable in-process target for workflow behavior without
requiring the pipeline orchestrator to import layer scripts or bypass the CLI
boundary accepted in ADR 0002.

Refactors must keep script behavior backward compatible by default. Any
intentional command-surface change still requires coordinated updates to
`README.md`, `AGENTS.md`, `docs/DEVELOPMENT_ARCHITECTURE.md`,
`docs/SCRIPTS_CONTRACT.md`, and `scripts/README.md`.

The boundary adds a second internal shape to maintain: thin scripts plus
application services. That cost is acceptable because it reduces duplication and
test friction while preserving SQL ownership for analytical transformations.

### Implemented services

| Service | File | Absorbs |
|---------|------|---------|
| `GoldService` | `src/services/gold/fotmob_gold_service.py` | `FotMobGoldProcessor`, `FotMobGoldStorage`, `_selected_job_groups`, `_run_sql_jobs`, `_run_selected_jobs`, `_run_signal_activation_builder` |
| `SilverService` | `src/services/silver/fotmob_silver_service.py` | `_load_sql_dirs`, `_load_jobs`, `_run_load_sql`, `_run_load_jobs` |
| `sql_jobs` | `src/services/gold/sql_jobs.py` | Moved from `scripts/gold/sql_jobs.py` |

Service result dataclasses (`GoldRunResult`, `SilverRunResult`) replace ad-hoc
tuple returns and give scripts structured data for alerting and exit-code
mapping.
