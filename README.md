# DepthMark

DepthMark is a FotMob-only football data pipeline built around a clear medallion
architecture:

- Bronze: raw FotMob API responses on disk plus raw ClickHouse `bronze.*` tables
- Silver: cleaned and conformed ClickHouse `silver.*` tables
- Gold: scenario tables in ClickHouse `gold_scenarios.*`, signal tables in
  `gold_signals.*`, and shared activation metadata in `gold.*` for product and
  analytics use

```text
FotMob API
  -> data/fotmob/historical/  completed-date Bronze files
  -> data/fotmob/live/        current-date Live snapshots
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
  -> gold.*                shared Gold metadata and activation tables
```

Bronze is the only filesystem-backed data layer. Silver and Gold exist only in
ClickHouse.

S3 transfer is an independent operator workflow; scraping and the warehouse
pipeline never upload automatically. Preview or run a date-scoped transfer with:

```bash
python scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
python scripts/bronze/sync_s3.py download --date 20251208
```

## Documentation

Start with [`docs/README.md`](docs/README.md) for the documentation map.

| Topic | Location |
| --- | --- |
| Architecture, commands, and runbook | [`docs/DEVELOPMENT_ARCHITECTURE.md`](docs/DEVELOPMENT_ARCHITECTURE.md) |
| Script behavior and CLI contract | [`docs/SCRIPTS_CONTRACT.md`](docs/SCRIPTS_CONTRACT.md) |
| Data flow, layer diagrams, and infrastructure | [`docs/data-flow/`](docs/data-flow/) |
| Script inventory | [`scripts/README.md`](scripts/README.md) |

Subsystem contracts live next to the code they govern, such as
`scripts/gold/scenario/SCENARIOS_CONTRACT.md` and
`scripts/gold/signal/contracts/`.

## Project Layout

```text
DepthMark/
  clickhouse/             ClickHouse DDL/DML by layer (gold uses ddl/ + dml/)
  config/                 Python configuration modules
  data/fotmob/            Historical and Live raw Bronze aspects
  docker/                 Dockerfile, entrypoint; root docker-compose.yml is the main stack
  docs/                   project-wide architecture and contracts
  scripts/                operational entry points
  src/                    application services, scraper, storage, and utility code
```

DepthMark currently supports FotMob only.
