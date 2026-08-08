# ADR 0023: Model FotMob and Oddspedia as Parallel Medallion Pipelines

## Status

Accepted

## Context

DepthMark scrapes two different websites: FotMob and Oddspedia. Existing
documentation presents FotMob as the complete Bronze → Silver → Gold warehouse
and Oddspedia as an isolated Bronze workflow with one Silver resolution table.
That presentation makes the source boundary look like a special exception and
does not describe the intended Oddspedia Gold product path.

The sources have different payloads, identifiers, extraction behavior, and
analytical outputs. Their raw contracts must remain isolated. They still share
the same medallion responsibilities: preserve source facts in Bronze, conform
source-owned entities in Silver, and materialize product-ready outputs in Gold.

## Decision

FotMob and Oddspedia are modeled as two parallel, explicit source pipelines:

```text
FotMob API       → FotMob Bronze       → FotMob Silver       → FotMob Gold
Oddspedia pages  → Oddspedia Bronze    → Oddspedia Silver    → Oddspedia Gold
```

- Bronze remains source-faithful and filesystem-backed before raw ClickHouse
  loading. FotMob and Oddspedia use separate artifact roots and raw contracts.
- Silver cleans and conforms each source independently. The existing
  `silver.oddspedia_match_resolution` table is part of the Oddspedia Silver
  boundary and may read the canonical FotMob `silver.match` reference.
- Gold owns source-specific scenarios, signals, and serving outputs. FotMob
  Gold outputs must not be presented as Oddspedia Gold outputs, and Oddspedia
  analytics must not be routed through FotMob Gold SQL.
- Cross-source matching is an explicit read-only integration edge between
  source Silver layers. It does not merge Bronze facts, rewrite canonical
  source rows, or collapse the two medallion paths into a generic provider
  framework.
- Documentation must label source and layer together whenever a diagram or tab
  could otherwise be ambiguous, for example `FotMob Silver` and `Oddspedia
  Silver` rather than one global `Silver` stage.
- Oddspedia date intake and Bronze publication are fail-closed operational
  boundaries: accepted discovery inventories are checksummed, Bronze facts are
  staged and published as one batch, and `silver.oddspedia_match_resolution`
  reads only dates marked `published` in `oddspedia_bronze.load_status`.
- Date-scoped mutating Oddspedia operations use a sport/date lock, while
  dry-run and read-only status commands do not acquire that lock. Month
  commands return non-zero when any requested date fails its phase gate.

## Implementation status

FotMob currently has the complete documented Silver and Gold execution path.
Oddspedia Bronze ingestion and Silver match resolution are implemented; its
additional source-specific Silver entities and Gold outputs remain follow-up
implementation work. This status difference does not change the target
architecture or ownership boundary.

## Consequences

Benefits:

- Architecture diagrams match the two websites being scraped.
- Source-specific lineage remains auditable from raw artifact to product output.
- Oddspedia can grow its own analytics without contaminating FotMob contracts.
- Cross-source joins are visible as integration work instead of hidden inside a
  provider-specific layer.

Costs:

- Some physical table names and loaders must carry explicit source ownership as
  Oddspedia Silver and Gold are implemented.
- Shared operational helpers remain possible, but their contracts must not
  imply shared analytical logic.

## Follow-up constraints

- Update architecture, data-flow, runbook, and interactive HTML documentation
  together when a source layer or source-specific command is added.
- Do not add Oddspedia fields to FotMob Bronze or silently reuse FotMob Gold
  tables for Oddspedia analytics.
- Keep `silver.oddspedia_match_resolution` auditable and read-only with respect
  to canonical FotMob fixture records.
