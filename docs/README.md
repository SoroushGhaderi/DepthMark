# DepthMark Docs

Project-wide documentation lives in this folder. The root `README.md` stays a
short project overview; use this folder for setup, commands, and operations.

Start with [Warehouse Knowledge Reference](data-flow/warehouse-pipeline-reference.html),
the central source of truth for project concepts, source ownership, layers, and
system relationships. Its glossary and contract index connect definitions to
the detailed interfaces that govern execution.

- `DEVELOPMENT_ARCHITECTURE.md`: two-source architecture, layer boundaries,
  command surface, runbook, operations, and documentation ownership.
- `data-flow/infrastructure.md`: Docker Compose setup, quick start, environment
  configuration, and TouchDesk integration.
- `SCRIPTS_CONTRACT.md`: standards for script behavior, style, CLI semantics,
  logging, safety, and command-surface changes.
- `data-flow/warehouse-pipeline-reference.html`: the warehouse source of truth.
  One self-contained file with 15 pages (concepts, sources, layers, products,
  operations, contracts), diagrams, command cards, and search. Page and section
  anchors such as `#gold` or `#cmd-fotmob-gold` are stable link targets.
- `data-flow/`: detailed source/layer flows supporting the central reference.
- `data-flow/orchestration.md#post-load-data-quality`: canonical duplicate and
  Bronze-to-Silver reconciliation workflow, scopes, and exit behavior.
- `PRODUCTION_READINESS_REVIEW.md`: full DE review report with evidence-based
  findings, remediation plan, and work tracking checklist.
- `reviews/architecture-review-depthmark-20260811.html`: script naming review
  for the FotMob and Oddspedia command surfaces; it also records the unified
  scraping-report refinement.
- `reviews/architecture-review-oddspedia-artifacts-20260812.html`: completed
  review and remediation record for Oddspedia JSON contracts, manifests, and
  multi-date continuation.
- `reviews/architecture-review-depthmark-20261002.html`: whole-repository
  review with prioritized P0–P3 findings and a remediation log.
- `adr/0024-source-qualified-operational-script-names.md`: accepted naming
  grammar, package registry, and compatibility-adapter policy.
- `adr/0025-unify-scraping-status-and-reports.md`: one read-only reporting
  interface for FotMob and Oddspedia, with explicit source adapters.
- `adr/0026-make-warehouse-setup-non-destructive.md`: create-only setup,
  fail-closed schema drift, and explicit Table Recreation.
- `adr/0027-use-an-external-scheduler.md`: no in-repo scheduler; host
  scheduler contract, run order, and overlap rule.
- `adr/0028-record-scoped-publication-status.md`: per-partition publication
  status for scoped Silver/Gold batches and the reader rule.
- `adr/0029-split-clickhouse-identities-and-isolate-staging.md`: application
  and maintenance ClickHouse identities and the `warehouse_stage` database.
- `adr/0030-automate-server-bootstrap.md`: one-command server initialization
  and upgrade with generated secrets and the installed schedule.

Source-specific flows:

- `data-flow/source-artifact-storage.md`: shared local-storage convention for
  FotMob and Oddspedia source artifacts.
- `data-flow/oddspedia.md`: Oddspedia discovery, source Bronze, Silver, and Gold
  boundaries, links-layer prioritization, and the separate cross-source
  resolution edge.
- `data-flow/warehouse-pipeline-reference.html#oddspedia`: the Oddspedia source
  pipeline and its explicit cross-source integration edge.

Keep active subsystem contracts next to the code they govern. Current examples:

- `scripts/README.md`
- `scripts/gold/scenario/SCENARIOS_CONTRACT.md`
- `scripts/gold/signal/contracts/`
