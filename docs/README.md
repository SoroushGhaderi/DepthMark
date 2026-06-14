# DepthMark Docs

Project-wide documentation lives in this folder so the repository root can stay
focused on onboarding.

- `DEVELOPMENT_ARCHITECTURE.md`: architecture, layer boundaries, command surface,
  runbook, operations, and documentation ownership.
- `SCRIPTS_CONTRACT.md`: standards for script behavior, style, CLI semantics,
  logging, safety, and command-surface changes.
- `data-flow/`: source of truth for system data flow, layer diagrams, and
  interactive wireframes. Start with `data-flow/index.html` for a visual
  overview.
- `PRODUCTION_READINESS_REVIEW.md`: full DE review report with evidence-based
  findings, remediation plan, and work tracking checklist.

Keep active subsystem contracts next to the code they govern. Current examples:

- `scripts/README.md`
- `scripts/gold/scenario/SCENARIOS_CONTRACT.md`
- `scripts/gold/signal/contracts/`
