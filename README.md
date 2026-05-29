# DepthMark

DepthMark is a FotMob-only football data pipeline built around a clear medallion
architecture:

- Bronze: raw FotMob API responses on disk plus raw ClickHouse `bronze.*` tables
- Silver: cleaned and conformed ClickHouse `silver.*` tables
- Gold: scenario tables in ClickHouse `gold_scenarios.*` and signal tables in `gold_signals.*` for product and analytics use

```text
FotMob API
  -> data/fotmob/          raw Bronze files
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
```

Bronze is the only filesystem-backed data layer. Silver and Gold exist only in
ClickHouse.

## Prerequisites

- Docker and Docker Compose
- Python 3.11 when running scripts outside Docker
- A valid `FOTMOB_X_MAS_TOKEN`
- ClickHouse credentials in `.env`
- MongoDB credentials in `.env` for the signal content catalog

## Quick Start

```bash
git clone <repository-url>
cd depthmark
cp .env.example .env
# edit .env and set FOTMOB_X_MAS_TOKEN, ClickHouse, and MongoDB values

docker-compose -f docker/docker-compose.yml up -d
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/setup_clickhouse.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208
```

To start only ClickHouse:

```bash
docker-compose -f docker/docker-compose.clickhouse.yml up -d
docker-compose -f docker/docker-compose.clickhouse.yml exec clickhouse clickhouse-client
```

## Configuration

Minimum useful `.env` values:

```bash
FOTMOB_X_MAS_TOKEN=your_token_here
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=fotmob_user
CLICKHOUSE_PASSWORD=fotmob_pass
MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_USER=orbit_admin
MONGODB_PASSWORD=your_mongodb_password_here
MONGODB_DATABASE=orbit_content
```

Bronze local storage is configured in `config.yaml`:

```yaml
fotmob:
  storage:
    bronze_path: data/fotmob
    enabled: true
```

## Common Commands

Run the standard pipeline for one date:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208
```

Run a date range or month:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py --month 202512
```

Run individual layers:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/bronze/scrape_fotmob.py 20251208
docker-compose -f docker/docker-compose.yml exec scraper python scripts/bronze/load_clickhouse.py --date 20251208
docker-compose -f docker/docker-compose.yml exec scraper python scripts/silver/load_clickhouse.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/load_clickhouse_scenarios.py
```

Preview non-destructive work:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/silver/load_clickhouse.py --dry-run
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/load_clickhouse_scenarios.py --dry-run
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/load_clickhouse_scenarios.py --part signals --dry-run
```

Run health and quality checks:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/health_check.py --json
docker-compose -f docker/docker-compose.yml exec scraper python scripts/quality/check_logging_style.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
```

## MongoDB Signal Catalog

Signal metadata is authored in markdown frontmatter under
`scripts/gold/signal/catalogs/*.md`. Sync it into MongoDB with:

```bash
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/mongodb/sync_signal_catalogs.py
```

The sync stores queryable metadata fields, the full frontmatter object, the
markdown body, and the relative source path.

## Project Layout

```text
depthmark/
  clickhouse/             ClickHouse DDL/DML by layer
  config/                 Python configuration modules
  data/fotmob/            raw Bronze files
  docker/                 local service definitions
  docs/                   project-wide architecture and contracts
  scripts/                operational entry points
  src/                    scraper, processor, storage, and utility code
```

Key script groups:

- `scripts/bronze/`: scrape, load, setup, and drop Bronze tables
- `scripts/silver/`: load, setup, and drop Silver tables
- `scripts/gold/`: setup/drop/load Gold scenarios and signals
- `scripts/orchestration/`: end-to-end setup and pipeline flows
- `scripts/quality/`: reconciliation and logging checks
- `scripts/mongodb/`: content catalog index and sync jobs

## Documentation

- `docs/DEVELOPMENT_ARCHITECTURE.md`: architecture, command surface, runbook, and operational guidance
- `docs/SCRIPTS_CONTRACT.md`: script behavior, style, CLI, and stability rules
- `docs/README.md`: documentation map
- `scripts/README.md`: script layout and inventory reference

Subsystem contracts stay next to the code they govern, such as
`scripts/gold/scenario/SCENARIOS_CONTRACT.md` and
`scripts/gold/signal/contracts/`.

## Notes

- DepthMark currently supports FotMob only.
- Use schema-qualified table names such as `bronze.general`, `silver.match`,
  `gold_scenarios.scenario_demolition`, and `gold_signals.sig_match_shooting_goals_goal_fest`.
- Bronze tables use `ReplacingMergeTree(inserted_at)` so reruns can be compacted
  by the ClickHouse optimization SQL in `clickhouse/bronze/99_optimize_tables.sql`.
