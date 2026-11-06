# ADR 0034: Name Every Operational Surface After Its Source

## Status

Accepted on 2026-11-06. Extends [ADR 0024](0024-source-qualified-operational-script-names.md)
from filenames to folders, containers, and ClickHouse databases, and supersedes
its compatibility-adapter policy. Amends
[ADR 0003](0003-split-gold-clickhouse-namespaces.md) and
[ADR 0029](0029-split-clickhouse-identities-and-isolate-staging.md) by renaming
the databases they name.

## Context

ADR 0024 made filenames source-qualified, but the surfaces around them still
named only a layer:

- FotMob scripts lived in layer folders (`scripts/bronze`, `scripts/silver`,
  `scripts/gold`, `scripts/orchestration`), while Oddspedia had
  `scripts/oddspedia`.
- One `depthmark-scraper` container ran both scrapers, so `docker ps`, logs, and
  the crontab could not show which source a job belonged to.
- FotMob owned the unprefixed databases `bronze`, `silver`, `gold`,
  `gold_scenarios`, and `gold_signals`, while Oddspedia owned `oddspedia_bronze`.
  Oddspedia's resolution edge lived in FotMob's database as
  `silver.oddspedia_match_resolution`.

A reader had to know the history to tell which source a path, container, or
table belonged to.

## Decision

Every operational surface names the source that owns it.

| Surface | FotMob | Oddspedia | Shared |
| --- | --- | --- | --- |
| Script folder | `scripts/fotmob/` | `scripts/oddspedia/` | `scripts/orchestration`, `maintenance`, `quality`, `mongodb`, root utilities |
| Script file | `<verb>_fotmob[_<layer>].py` | `<verb>_oddspedia[_<entity>].py` | source-neutral verbs |
| Container | `depthmark-fotmob-scraper` | `depthmark-oddspedia-scraper` | `depthmark-clickhouse`, `depthmark-mongodb` |
| Databases | `fotmob_bronze`, `fotmob_silver`, `fotmob_gold`, `fotmob_gold_scenarios`, `fotmob_gold_signals` | `oddspedia_bronze`, `oddspedia_silver` | `warehouse_stage` |

- Both scraper containers run one `depthmark-scraper:local` image and carry a
  `com.depthmark.source` label. Each scheduled job runs in its own source's
  container; shared setup steps run in the FotMob container.
- The resolution edge is Oddspedia-owned: it moves to
  `oddspedia_silver.match_resolution`, with its DDL under
  `clickhouse/oddspedia_silver/ddl/`. It still reads `fotmob_silver.match` as the
  canonical fixture reference, read-only.
- The Gold database settings become `CLICKHOUSE_DB_FOTMOB_GOLD`,
  `CLICKHOUSE_DB_FOTMOB_GOLD_SCENARIOS`, and `CLICKHOUSE_DB_FOTMOB_GOLD_SIGNALS`,
  matching the other `fotmob_*` names.
- SQL folders under `clickhouse/` keep their layer names; the database names
  inside them carry the source.
- DepthMark is treated as a new deployment: renamed scripts, package command
  aliases, and databases have no compatibility adapters or migration. Every
  caller uses the canonical name, and a future rename updates all callers in
  the same change.

## Consequences

- A path, container name, or qualified table name alone identifies its source.
- External readers such as TouchDesk read the `fotmob_*` and
  `oddspedia_silver` names.
- A warehouse created under the old names is not migrated; recreate it with
  `scripts/bootstrap.sh` and reload it.
- New source workflows add a `scripts/<source>/` folder, a
  `depthmark-<source>-scraper` container, and `<source>_*` databases.
