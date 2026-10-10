# Data Flow Documentation

[`warehouse-pipeline-reference.html`](warehouse-pipeline-reference.html) is the
central **source of truth** for DepthMark concepts, source ownership, layer
boundaries, and system relationships. This folder contains its detailed data-flow
references. Update the Atlas and affected deep dives when definitions, source
maturity, scripts, SQL jobs, or infrastructure change. Specialized script and
subsystem contracts remain authoritative for their detailed interfaces.

## Documents

| File | Purpose |
| --- | --- |
| `warehouse-pipeline-reference.html` | Documentation Atlas: glossary, independent source paths, warehouse layers, scenarios/signals, operations, platforms, and contract/decision index. Open locally; sidebar routes preserve `#gold`, and heading links support `#gold/activation-rebuild`. The command reference (`#commands`) covers installed CLI commands, script equivalents, scope compatibility, prerequisites, and effects; `#quality` defines acceptance gates. Source filters, command search/copying, chapter navigation, maturity badges, artifact layouts, and troubleshooting guides work offline alongside the diagram panels. |
| `bronze.md` | Bronze layer for both sources: source-faithful storage, raw loading, and recovery boundaries. |
| `silver.md` | Silver layer for both sources: SQL-driven cleaning, typing, conformation, and source ownership. |
| `gold.md` | Gold layer for both sources: source-specific scenarios, signals, serving outputs, and execution boundaries. |
| `orchestration.md` | Pipeline orchestration plus the canonical post-load duplicate and Bronze-to-Silver reconciliation workflow. |
| `infrastructure.md` | Docker Compose, ClickHouse setup, MongoDB, environment configuration, and credential policy. |
| `mongodb.md` | Signal catalog sync: markdown frontmatter → MongoDB serving copy. |

Maintenance commands such as `scripts/maintenance/optimize_clickhouse.py` are
documented in `infrastructure.md` and the interactive warehouse reference.

## How To Use

1. Start with `warehouse-pipeline-reference.html` for concept definitions, the two parallel source pipelines, their integration edge, and the contract index.
2. Read the layer-specific `.md` files for detailed flow, scripts, tables, and
   edge cases.
3. Cross-reference `docs/DEVELOPMENT_ARCHITECTURE.md` for canonical commands
   and runbook guidance.

## Maintenance Rules

1. **Update these docs in the same change** when you add, rename, or remove a
   layer script, SQL job, ClickHouse table, or MongoDB collection.
2. **Keep diagrams accurate.** If the code and a diagram disagree, the code
   wins — update the diagram in the same change.
3. **Open `warehouse-pipeline-reference.html` locally** after editing to verify
   flow diagrams and click-to-command panels render correctly.
4. **No stale inventory counts.** Update table counts in `bronze.md`,
   `silver.md`, and `gold.md` when the inventory changes.

## Diagram Conventions

- Copper, slate, and amber label Bronze, Silver, and Gold respectively in the Atlas.
- Green callouts/status labels indicate successful or implemented state; red denotes failure paths.
- Planned status is explicitly labeled; color alone never defines implementation maturity.
- Dashed arrows: optional or conditional flows.
- Solid arrows: mandatory sequential flows.
