# ADR 0007: SQL Owns Analytical Transformations

## Status

Accepted

> **Implementation note (2026-07-13):** This decision applies to both explicit
> source domains. FotMob remains the canonical Silver and Gold analytical path;
> Oddspedia has isolated Bronze facts and an audited Silver resolution, with no
> generic provider framework.

## Context

DepthMark uses FotMob as the canonical medallion path. FotMob Bronze stores raw
payloads and raw ClickHouse tables, Silver conforms reusable analytical
entities, and Gold materializes scenario, signal, and shared metadata outputs.
Oddspedia remains an isolated source domain rather than a second implementation
of the FotMob analytical pipeline.

The repository already keeps most Silver and Gold transformation logic in
ClickHouse SQL under `clickhouse/`. Python scripts provide the operational
surface: CLI parsing, environment loading, SQL discovery, execution, dry-run
planning, validation, logging, reporting, catalog synchronization, and
orchestration.

Without an explicit boundary, new work could add dataframe transformations or
business rules in Python while similar rules live in SQL elsewhere. That would
make lineage harder to inspect, make reruns less predictable, and split review
expectations across two implementation styles.

Moving every small preparation step into SQL would also be too rigid. Bronze
still needs Python to fetch FotMob payloads, preserve source fidelity, normalize
raw ingestion shape where needed, and load raw data safely. Python also remains
the right place for operational validation and metadata plumbing that surrounds
the warehouse transforms.

## Decision

SQL owns reusable analytical transformations for Silver and Gold.

Any reusable analytical derivation, metric calculation, aggregation, scenario
rule, signal rule, or business-facing table population for Silver or Gold must
live in versioned ClickHouse SQL unless a later ADR grants a narrow exception.

Python owns orchestration and validation around those transformations. Python is
allowed to:

- fetch source data and preserve each source's Bronze fidelity;
- normalize Bronze ingestion shape where needed to load raw payloads safely;
- discover SQL files and resolve target databases or table names;
- execute SQL, including dry-run planning and deterministic summaries;
- validate arguments, contracts, catalogs, schemas, and row-count expectations;
- build operational metadata that depends on catalog contracts, such as signal
  activation rows and match-level activation aggregates;
- synchronize markdown-authored catalogs into MongoDB serving/query stores;
- log, alert, report, and sequence scripts through the canonical CLI surface.

Python must not become a parallel home for Silver or Gold football logic,
scenario criteria, signal trigger criteria, reusable metrics, or downstream
business table derivations. If a proposed change needs Python for one of those
concerns, the change should either move the logic into SQL or create a follow-up
ADR explaining why the exception is necessary.

## Consequences

Reviewers have a clear default rule: inspect SQL for Silver and Gold analytical
meaning, and inspect Python for execution, validation, and operational behavior.

Lineage stays easier to follow because business-facing warehouse outputs are
derived from SQL files under `clickhouse/` rather than from hidden dataframe or
script-side transformations.

Python can still enforce safety and contracts around SQL execution, including
dry-run behavior, catalog validation, deterministic activation materialization,
and command summaries required by `docs/SCRIPTS_CONTRACT.md`.

Some changes may require more SQL work than a quick Python helper would. That is
intentional for reusable Silver and Gold outputs because deterministic,
rerunnable warehouse logic is more important than short-term implementation
convenience.

The boundary does not require rewriting existing Bronze ingestion code or
operational scripts. Future exceptions should be explicit, narrow, and
documented when they cross into reusable analytical transformation ownership.
