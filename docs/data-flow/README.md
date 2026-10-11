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
| `warehouse-pipeline-reference.html` | Source of truth. One self-contained file with 19 pages: task runbooks, concepts, FotMob, Oddspedia, Bronze, Silver, Gold, scenarios, signals, MongoDB catalogs, commands, orchestration, quality, infrastructure, and contracts, with diagrams and search. Edit it directly; there is no build step. |
| `bronze.md` | Bronze layer for both sources: source-faithful storage, raw loading, and recovery boundaries. |
| `silver.md` | Silver layer for both sources: SQL-driven cleaning, typing, conformation, and source ownership. |
| `gold.md` | Gold layer for both sources: source-specific scenarios, signals, serving outputs, and execution boundaries. |
| `orchestration.md` | Pipeline orchestration plus the canonical post-load duplicate and Bronze-to-Silver reconciliation workflow. |
| `infrastructure.md` | Docker Compose, ClickHouse setup, MongoDB, environment configuration, and credential policy. |
| `mongodb.md` | Signal catalog sync: markdown frontmatter → MongoDB serving copy. |

Maintenance commands such as `scripts/maintenance/optimize_clickhouse.py` and
`scripts/maintenance/recreate_clickhouse_tables.py` are documented in
`infrastructure.md` and the warehouse reference's command matrix.

## How To Use

1. Start with `warehouse-pipeline-reference.html` for the pipeline map, then open the page for the question you have.
2. Read the layer-specific `.md` files for detailed flow, scripts, tables, and
   edge cases.
3. Cross-reference `docs/DEVELOPMENT_ARCHITECTURE.md` for canonical commands
   and runbook guidance.

## Maintenance Rules

1. **Update these docs in the same change** when you add, rename, or remove a
   layer script, SQL job, ClickHouse table, or MongoDB collection.
2. **Keep diagrams accurate.** If the code and a diagram disagree, the code
   wins — update the diagram in the same change.
3. **Check the reference after editing.** `warehouse-pipeline-reference.html` is a
   single hand-maintained file with its CSS and JavaScript inline. Every
   `href="#x"` needs an element with `id="x"`, and each page is an
   `<article class="page" id="slug">` shown with CSS `:target`, so it also works
   inside sandboxed previews. Open it after editing to check the diagrams,
   anchors, and phone-width layout.
4. **No stale inventory counts.** Update table counts in `bronze.md`,
   `silver.md`, and `gold.md` when the inventory changes.

## Diagram Conventions

- Copper, slate, and amber label Bronze, Silver, and Gold respectively in the reference.
- Status badges use text as well as color: Implemented, Partial, Planned, and Destructive. Color alone never defines maturity.
- Flows are numbered steps. An optional or skipped path is named in the text, not drawn as a dashed arrow.
