# Data Flow Documentation

This folder is the **source of truth** for how data moves through DepthMark.
Update these documents when layer boundaries, scripts, SQL jobs, or
infrastructure change.

## Documents

| File | Purpose |
| --- | --- |
| `warehouse-pipeline-reference.html` | Interactive warehouse pipeline reference: medallion layer flows, architecture principles, consumption paths, and click-to-reveal script/command panels. Open locally in a browser; tabs support `#hash` deep links (e.g. `warehouse-pipeline-reference.html#gold`). |
| `bronze.md` | Bronze layer: FotMob scraping, raw JSON storage, ClickHouse loading, DLQ handling. |
| `silver.md` | Silver layer: SQL-driven cleaning, typing, and conformation of Bronze into analytical tables. |
| `gold.md` | Gold layer: scenario outputs, signal outputs, activation rebuilds, and the generic SQL runner. |
| `orchestration.md` | Pipeline orchestration plus the canonical post-load duplicate and Bronze-to-Silver reconciliation workflow. |
| `infrastructure.md` | Docker Compose, ClickHouse setup, MongoDB, environment configuration, and credential policy. |
| `mongodb.md` | Signal catalog sync: markdown frontmatter → MongoDB serving copy. |

Maintenance commands such as `scripts/maintenance/optimize_clickhouse.py` are
documented in `infrastructure.md` and the interactive warehouse reference.

## How To Use

1. Start with `warehouse-pipeline-reference.html` for a visual overview of the entire system.
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

- Green nodes: healthy data state (loaded, validated).
- Yellow nodes: in-progress or optional steps.
- Red nodes: failure paths (DLQ, errors).
- Dashed arrows: optional or conditional flows.
- Solid arrows: mandatory sequential flows.
