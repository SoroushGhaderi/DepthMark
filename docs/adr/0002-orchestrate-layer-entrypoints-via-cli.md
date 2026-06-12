# ADR 0002: Orchestrate Layer Entrypoints Via CLI

## Status

Accepted

## Context

DepthMark exposes operational layer entry points under `scripts/bronze/`,
`scripts/silver/`, `scripts/gold/`, and `scripts/orchestration/`. These scripts
are the documented command surface for local runs, Docker runs, backfills, and
dry-run validation.

The pipeline orchestrator previously imported short module names such as
`scrape_fotmob`, `load_clickhouse`, `process_silver`, and `process_gold`. That
coupled orchestration to import-path side effects and stale module names instead
of the documented entry points. It also made command-surface drift easy: a script
could be renamed or moved while the orchestrator still appeared valid until
runtime.

Refactoring every layer into stable importable services would be cleaner in the
long term, but it is a broader migration because the scripts currently own CLI
parsing, environment setup, logging, alerting, and runtime summaries.

## Decision

The pipeline orchestrator should invoke the canonical layer scripts through
subprocess calls to their documented CLI entry points.

Layer scripts remain the operational boundary for now. The orchestrator is
responsible for sequencing, passing supported CLI arguments, collecting exit
codes, and reporting a pipeline summary. Layer scripts remain responsible for
their own parsing, runtime setup, logging, validation, alerts, and dry-run
semantics.

If DepthMark later extracts stable application services under `src/`, those
services should sit behind the same CLI entry points first. The orchestrator can
then be changed intentionally once the service boundary is proven.

## Consequences

This keeps the pipeline aligned with the documented command surface and avoids
hidden dependency on import-path quirks.

It preserves script behavior and minimizes migration risk while the Gold runner
surface is still being consolidated.

Subprocess execution has some overhead and keeps structured step details at the
process boundary, but that is acceptable for operational batch jobs where
clarity and CLI compatibility matter more than in-process composition.

Command-surface changes must update the orchestrator, `README.md`,
`docs/DEVELOPMENT_ARCHITECTURE.md`, `scripts/README.md`, and `AGENTS.md` in the
same change.
