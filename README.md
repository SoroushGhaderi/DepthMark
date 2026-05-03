# PitchWise Orbit

PitchWise Orbit is a FotMob-only football data pipeline with an explicit medallion architecture.

- Bronze: raw FotMob API responses stored on disk and loaded into ClickHouse `bronze.*` tables
- Silver: cleaned ClickHouse `silver.*` tables built from Bronze
- Gold: analytics-ready ClickHouse `gold.*` tables built from Silver

## Architecture

```text
FotMob API
  -> data/fotmob/                   raw Bronze files
  -> bronze.*                       ClickHouse Bronze tables
  -> silver.*                       ClickHouse Silver tables
  -> gold.*                         ClickHouse Gold tables
```

## Layer Rules

- Bronze is the only filesystem-backed layer
- Silver and Gold exist only in ClickHouse
- Bronze warehouse tables live in the `bronze` schema
- Silver warehouse tables live in the `silver` schema
- Gold warehouse tables live in the `gold` schema
- PitchWise Orbit currently supports FotMob only

## Prerequisites

- Docker and Docker Compose
- Python 3.11 if running locally outside Docker
- A valid `FOTMOB_X_MAS_TOKEN`
- ClickHouse credentials in `.env`
- MongoDB credentials in `.env` (for content catalog)

## Quick Start

```bash
git clone <repository-url>
cd pitchwise_orbit
cp .env.example .env
# edit .env and set FOTMOB_X_MAS_TOKEN plus ClickHouse credentials

docker-compose -f docker/docker-compose.yml up -d

# create Bronze + Silver + Gold schema
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/setup_clickhouse.py

# run a complete single-day pipeline
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208
```

## ClickHouse Only (No Scraper)

Use this when you only want the database container:

```bash
docker-compose -f docker/docker-compose.clickhouse.yml up -d
```

Open a ClickHouse client session:

```bash
docker-compose -f docker/docker-compose.clickhouse.yml exec clickhouse clickhouse-client
```

## Required Configuration

### `.env`

Minimum useful values:

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

### `config.yaml`

Bronze is the only local layer path:

```yaml
fotmob:
  storage:
    bronze_path: data/fotmob
    enabled: true
```

See `DEVELOPMENT_ARCHITECTURE.md` for the full development, architecture, and configuration reference.

### MongoDB code layout

- `src/storage/mongodb/` - client, collection constants, indexes, repositories
- `schemas/mongodb/` - JSON schemas for content collections
- `scripts/mongodb/init_indexes.py` - index bootstrap script

## Running The Code

### 1. Start infrastructure

```bash
docker-compose -f docker/docker-compose.yml up -d
```

To start only MongoDB (content catalog service):

```bash
docker-compose -f docker/docker-compose.yml up -d mongodb
```

### 2. Create ClickHouse schema

Create all layers:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/setup_clickhouse.py
```

Or create one layer at a time:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/bronze/setup_clickhouse.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/silver/setup_clickhouse.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/setup_clickhouse_gold.py
```

### 2.1 Initialize MongoDB content indexes

```bash
python scripts/mongodb/init_indexes.py
```

### 3. Scrape Bronze files

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/bronze/scrape_fotmob.py 20251208
```

This writes raw FotMob match responses into `data/fotmob/`.

### 4. Load Bronze files into ClickHouse Bronze tables

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/bronze/load_clickhouse.py --date 20251208
```

This creates or appends records in tables such as:

- `bronze.match_reference`
- `bronze.general`
- `bronze.player`
- `bronze.shotmap`
- `bronze.goal`
- `bronze.period`

`bronze.match_reference` is a compact lookup table for filtering and tracking games by
`match_id`, `match_date`, home/away team ids and names, league context, match
status, and score. It is populated from the same FotMob general payload during
Bronze loading, partitioned by `match_date`, and ordered by `(match_date, match_id)`
for date/id/team-oriented queries.

### 5. Build Silver tables

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/silver/load_clickhouse.py
```

Preview silver load jobs without writes:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/silver/load_clickhouse.py --dry-run
```

This refreshes tables such as:

- `silver.match`
- `silver.period_stat`
- `silver.player_match_stat`
- `silver.momentum`
- `silver.team_form`

### 6. Build Gold tables

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/load_clickhouse_scenarios.py
```

Preview gold SQL + scenario/signal execution without writes:

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/gold/load_clickhouse_scenarios.py --dry-run
```

This refreshes tables such as:

- `gold.scenario_demolition`
- `gold.scenario_route_one_masterclass`
- `gold.scenario_pressing_masterclass`

It also refreshes scenario narrative tables (via `scripts/gold/scenario/scenario_*.py`), including:

- `gold.scenario_high_intensity_engine`
- `gold.scenario_black_hole`
- `gold.scenario_high_line_trap`
- `gold.scenario_ghost_poacher`
- `gold.scenario_route_one_masterclass`
- `gold.scenario_total_suffocation`
- `gold.scenario_territorial_suffocation`
- `gold.scenario_clinical_pivot`

And it refreshes signal tables (via `scripts/gold/signal/runners/sig_*.py`), including:

- `gold.sig_team_possession_passing_high_press_victim`

## Full Pipeline Modes

### One date

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208
```

### Date range

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207
```

### Month

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py --month 202512
```

### Bronze only

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208 --bronze-only
```

### Silver only

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208 --silver-only
```

### Gold only

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208 --gold-only
```

### Skip scraping and reuse existing Bronze files

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/pipeline.py 20251208 --skip-bronze
```

## Bronze Table Engine

All ClickHouse Bronze tables use:

```sql
ENGINE = ReplacingMergeTree(inserted_at)
```

That allows re-runs and deduplication by keeping the newest inserted version before compaction.

Run optimization periodically:

```bash
docker-compose -f docker/docker-compose.yml exec -T clickhouse clickhouse-client \
  --user fotmob_user --password fotmob_pass \
  < clickhouse/bronze/99_optimize_tables.sql
```

## Project Structure

```text
pitchwise_orbit/
├── clickhouse/
│   ├── bronze/
│   ├── silver/
│   └── gold/
│       ├── scenario/
│       ├── signal/
│       └── reference/
├── config/
├── scripts/
│   ├── bronze/
│   │   ├── scrape_fotmob.py
│   │   ├── load_clickhouse.py
│   │   └── setup_clickhouse.py
│   ├── silver/
│   │   ├── load_clickhouse.py
│   │   └── setup_clickhouse.py
│   ├── gold/
│   │   ├── load_clickhouse_scenarios.py
│   │   └── setup_clickhouse_gold.py
│   ├── orchestration/
│   │   ├── pipeline.py
│   │   └── setup_clickhouse.py
│   ├── quality/
│   │   ├── check_bronze_to_silver_reconciliation.py
│   │   └── check_logging_style.py
│   ├── ensure_directories.py
│   ├── health_check.py
│   ├── refresh_turnstile.py
│   └── utils/
├── src/
│   ├── processors/
│   │   ├── bronze/
│   │   ├── silver/
│   │   └── gold/
│   └── storage/
│       ├── bronze/
│       ├── silver/
│       └── gold/
└── data/
    └── fotmob/
```

## Troubleshooting

### Create local directories early

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/ensure_directories.py
```

### Check system health

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/health_check.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/health_check.py --json
```

### Recreate schema

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/orchestration/setup_clickhouse.py
```

### Run quality checks

```bash
docker-compose -f docker/docker-compose.yml exec scraper python scripts/quality/check_logging_style.py
docker-compose -f docker/docker-compose.yml exec scraper python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
```

## Notes

- PitchWise Orbit is currently FotMob-only
- Silver and Gold are warehouse layers, not local directories
- Always use schema-qualified names like `bronze.general`, `gold.scenario_demolition`, or `gold.match_summary`

## Repo Hygiene

- Script inventory: `SCRIPTS_AUDIT.md`
- Script command + handwriting contract: `SCRIPTS_CONTRACT.md`
- Script layout reference: `scripts/README.md`
