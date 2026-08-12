# DepthMark Docs

Project-wide documentation lives in this folder. The root `README.md` stays a
short project overview; use this folder for setup, commands, and operations.

- `DEVELOPMENT_ARCHITECTURE.md`: two-source architecture, layer boundaries,
  command surface, runbook, operations, and documentation ownership.
- `data-flow/infrastructure.md`: Docker Compose setup, quick start, environment
  configuration, and TouchDesk integration.
- `SCRIPTS_CONTRACT.md`: standards for script behavior, style, CLI semantics,
  logging, safety, and command-surface changes.
- `data-flow/`: source of truth for system data flow, layer diagrams, and
  interactive wireframes. Start with `data-flow/warehouse-pipeline-reference.html` for a visual
  overview.
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
- `adr/0024-source-qualified-operational-script-names.md`: accepted naming
  grammar, package registry, and compatibility-adapter policy.
- `adr/0025-unify-scraping-status-and-reports.md`: one read-only reporting
  interface for FotMob and Oddspedia, with explicit source adapters.

Source-specific flows:

- `data-flow/source-artifact-storage.md`: shared local-storage convention for
  FotMob and Oddspedia source artifacts.
- `data-flow/oddspedia.md`: Oddspedia discovery, source Bronze, Silver, and Gold
  boundaries, links-layer prioritization, and the separate cross-source
  resolution edge.
- `data-flow/warehouse-pipeline-reference.html#oddspedia`: interactive
  warehouse view for the complete Oddspedia source pipeline and its explicit
  cross-source integration edge.

Keep active subsystem contracts next to the code they govern. Current examples:

- `scripts/README.md`
- `scripts/gold/scenario/SCENARIOS_CONTRACT.md`
- `scripts/gold/signal/contracts/`
