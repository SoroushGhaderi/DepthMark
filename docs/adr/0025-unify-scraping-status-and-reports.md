# ADR 0025: Unify Scraping Status and Reports

## Status

Accepted on 2026-08-12

## Context

Oddspedia exposed separate `status_oddspedia.py` and
`report_oddspedia.py` commands backed by two implementations. The status path
read a manifest through the mutating scraper CLI and configured a persisted run
log before printing progress. The report path was read-only and much deeper,
but covered only Oddspedia. FotMob had equivalent listing and storage evidence
without a supported reporting command.

This split created three operator problems:

- “status” and “report” disagreed about evidence and output shape;
- observing Oddspedia could create a run log, making monitoring non-read-only;
- comparing sources required source-specific commands and knowledge.

The source contracts must remain isolated. Consolidating observation must not
become a generic provider framework or merge FotMob and Oddspedia artifacts.

## Decision

`scripts/report_scraping.py` and package command `depthmark report-scraping`
are the only canonical scraping-report interface.

The interface is a deep, source-neutral operational module with two explicit
adapters:

```text
scripts/report_scraping.py
        │
        ▼
src/operations/scraping_reporting.py
        ├── src/fotmob/scraping/reporting.py
        └── src/oddspedia/scraping/reporting.py
```

There is no provider registration, shared raw model, or cross-source mutation.
Each adapter owns its source-specific reads and evidence. The operational
module owns scope resolution, the common report contract, aggregation,
rendering, and attention policy.

The command contract is:

- `--source {all,fotmob,oddspedia}`, default `all`;
- mutually exclusive `--date YYYYMMDD` and `--month YYYYMM`, default today;
- a current-month report stops at the current date;
- `--format {summary,markdown,json}`, default `summary`;
- optional `--output PATH`; and
- optional `--fail-on-attention` for CI or cron.

Every source-date report provides common fields for discovered, completed,
failed, skipped, remaining, progress, artifact count, storage size, and
Bronze-admission readiness. Source-specific evidence remains available:

- FotMob reconciles `matches.json`, individual payloads, compressed payloads,
  terminally unavailable match IDs, and date archives.
- Oddspedia reports discovery inventory, priority scope, scrape manifest,
  payload audit, operational attempts, and downstream readiness.

Reporting is observational. It does not acquire locks, configure persisted run
logs, update manifests/metrics, write source artifacts, or change warehouse
state. Supplying `--output` authorizes only the requested report file and its
parent directories.

Generating a valid report exits `0` even if work remains; the operational state
is data, not a command failure. `--fail-on-attention` converts not-started,
incomplete, attention, or error states to exit `1` for automation.

The former Oddspedia status/report scripts and package commands remain thin,
warning-emitting adapters. They delegate to the unified command with
Oddspedia plus their former default presentation (`summary` or `markdown`).
The legacy `events.py status` path also delegates before scraper logging is
configured.

## Consequences

Benefits:

- operators learn one command for both sources and all output formats;
- FotMob gains practical listing-to-storage reconciliation;
- summary, Markdown, and JSON cannot drift because they render one bundle;
- monitoring is side-effect-free unless an output file is explicitly asked
  for; and
- source adapters can evolve independently behind a stable common seam.

Costs:

- legacy Oddspedia report output now uses the unified report structure;
- compatibility adapters remain visible during migration; and
- a combined month report may scan many local artifacts and run logs.

## Rejected Alternatives

- Separate `status_fotmob.py`, `report_fotmob.py`, `status_oddspedia.py`, and
  `report_oddspedia.py` commands were rejected because they duplicate scope,
  rendering, automation policy, and documentation.
- Keeping “status” as a lightweight manifest-only implementation was rejected
  because it gave a different answer and created logs while observing state.
- A generic provider plugin framework was rejected because DepthMark has two
  explicit source domains with intentionally different raw contracts.
- Making any incomplete scrape return non-zero by default was rejected because
  operators need to inspect in-progress dates without treating report
  generation itself as failed.

## Follow-up Constraints

- New report formats and aggregate metrics are added to the unified interface,
  not source-specific scripts.
- Source-specific parsing remains in the explicit source adapter.
- A report command must remain read-only under regression tests.
- Command docs, package registry tests, the scripts contract, and the HTML
  architecture references change together with this interface.
