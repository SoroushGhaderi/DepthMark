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
  -> data/fotmob/          raw Bronze files
  -> bronze.*              raw warehouse tables
  -> silver.*              cleaned analytical tables
  -> gold_scenarios.*      scenario outputs
  -> gold_signals.*        signal outputs
  -> gold.*                shared Gold metadata and activation tables
```

Bronze is the only filesystem-backed data layer. Silver and Gold exist only in
ClickHouse.

Gold uses separate ClickHouse namespaces for scenario outputs, signal outputs,
and shared metadata. Scenario SQL targets `gold_scenarios.scenario_*` and runs
through the bulk Gold loader with `--part scenarios` or `--part all`.

## Prerequisites

- Docker and Docker Compose
- Python 3.11 when running scripts outside Docker
- A valid `FOTMOB_X_MAS_TOKEN`
- ClickHouse credentials in `.env`
- MongoDB credentials in `.env` for the signal content catalog

## Quick Start

```bash
git clone <repository-url>
cd DepthMark
cp .env.example .env
# edit .env and set FOTMOB_X_MAS_TOKEN, ClickHouse, and MongoDB values
# keep DEPTHMARK_ENV=local only for the tracked local Docker workflow

docker compose up -d
docker compose exec depthmark-scraper python scripts/orchestration/setup_clickhouse.py
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py 20251208
```

TouchDesk (separate repo) connects to this stack read-only. Start DepthMark first, then run TouchDesk from its own `docker-compose.yml`:

```bash
cd ../DepthMark && docker compose up -d --build
cd ../TouchDesk && docker compose up -d --build
```

TouchDesk `docker-compose.override.yml` joins `depthmark_network` for service-name access (`depthmark-clickhouse`, `depthmark-mongodb`). See TouchDesk README for remote-host options.

To start only ClickHouse:

```bash
docker compose -f docker/docker-compose.clickhouse.yml up -d
docker compose -f docker/docker-compose.clickhouse.yml exec depthmark-clickhouse clickhouse-client
```

`docker/docker-compose.yml` is a compatibility shim that includes the root `docker-compose.yml`.

## Configuration

The tracked Docker Compose files are local-development manifests. They expose
database ports and keep local bootstrap defaults for convenience; do not use
them as production deployment manifests.

Use `DEPTHMARK_ENV=local` for local Docker development. Outside local
development, set `DEPTHMARK_ENV=production` and provide non-empty, non-default
database credentials. ClickHouse setup rejects empty, placeholder, or known
local-dev passwords outside local development and does not use the empty-password
`default` user bootstrap path.

Minimum useful `.env` values:

```bash
FOTMOB_X_MAS_TOKEN=your_token_here
DEPTHMARK_ENV=local
CLICKHOUSE_HOST=depthmark-clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=fotmob_user
CLICKHOUSE_PASSWORD=your_clickhouse_password_here
MONGODB_HOST=depthmark-mongodb
MONGODB_PORT=27017
MONGODB_USER=orbit_admin
MONGODB_PASSWORD=your_mongodb_password_here
MONGODB_DATABASE=orbit_content
```

## Docker (standalone)

DepthMark ships its own root `docker-compose.yml` (MongoDB, ClickHouse, scraper). It does **not** include TouchDesk.

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

**Published ports (for TouchDesk on another host or compose stack):**

| Service | Port |
|---------|------|
| `depthmark-clickhouse` HTTP | `8123` |
| `depthmark-clickhouse` native | `9000` |
| `depthmark-mongodb` | `27017` |

**Network:** creates Docker network `depthmark_network` (fixed name). TouchDesk can join it optionally via `docker-compose.override.yml` (see TouchDesk repo).

**Downstream:** TouchDesk reads `gold.*` / `gold_signals.*` from ClickHouse and the signal catalog from MongoDB. DepthMark does not call TouchDesk.

Optional scheduler profile:

```bash
docker compose --profile scheduler up -d
```

Stop and remove containers:

```bash
docker compose down
docker compose down -v   # also removes volumes (destructive)
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
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py 20251208
```

Run a date range or month:

```bash
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py --month 202512
```

Run individual layers:

```bash
docker compose exec depthmark-scraper python scripts/bronze/scrape_fotmob.py 20251208
docker compose exec depthmark-scraper python scripts/bronze/load_clickhouse.py --date 20251208
docker compose exec depthmark-scraper python scripts/silver/load_clickhouse.py
docker compose exec depthmark-scraper python scripts/gold/load_clickhouse_gold.py
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --entity player
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --family shooting_goals
```

Preview non-destructive work:

```bash
docker compose exec depthmark-scraper python scripts/silver/load_clickhouse.py --dry-run
docker compose exec depthmark-scraper python scripts/gold/load_clickhouse_gold.py --dry-run
docker compose exec depthmark-scraper python scripts/gold/load_clickhouse_gold.py --part signals --dry-run
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --dry-run
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --dry-run
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_shot_conversion_peak --dry-run
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --entity player --dry-run
docker compose exec depthmark-scraper python scripts/gold/run_sql_job.py --kind signal --family shooting_goals --dry-run
```

Run health and quality checks:

```bash
docker compose exec depthmark-scraper python scripts/health_check.py --json
docker compose exec depthmark-scraper python scripts/quality/check_logging_style.py
docker compose exec depthmark-scraper python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
```

## MongoDB Signal Catalog

Signal metadata is authored in markdown frontmatter under
`scripts/gold/signal/catalogs/*.md`. These markdown catalogs are the source of
truth; MongoDB is a synchronized serving/query copy. Sync catalogs into MongoDB
with:

```bash
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/mongodb/sync_signal_catalogs.py
```

The sync validates required frontmatter, including `asset_paths.table` values in
the `gold_signals.<signal_id>` namespace. It stores queryable metadata fields,
the full frontmatter object, the markdown body, the relative source path, and
embedded SQL/runner asset contents with hashes for integrity checks.

`row_identity` in each signal catalog is the canonical per-row identity used for
deterministic activation IDs. Typical values are:

- team-grain signal: `match_id`, `triggered_side`
- player-grain signal: `match_id`, `triggered_player_id`, `triggered_team_id`

DepthMark also materializes signal activations in the serving table
`gold.signal_activations` using a deterministic hash key:

- `signal_instance_id = SHA256(\"v1|signal_id|<row_identity values>\")`
- version prefix (`v1`) is the activation identity scheme version, not the
  signal-definition version
- IDs stay stable across reruns and ordinary signal SQL/catalog changes when
  `signal_id` and `row_identity` values are unchanged
- each `gold_signals.sig_*` table also defines `signal_instance_id` with the
  same deterministic identity expression
- activation metadata is rebuilt with full-table rebuilds into the single
  `gold.signal_activations` serving table
- Parsed `signal_id` structure is also stored:
  - `signal_prefix` (for example `sig`)
  - `signal_entity` (for example `match`, `team`, `player`)
  - `signal_family` and `signal_subfamily` (taxonomy tags)
  - `signal_name` (remaining suffix after taxonomy)
  - `signal_tags` (array form of taxonomy tags)

Each activation row also carries common fixture/team/player context when present
in the source signal row, the full source signal row in `source_row_json`, and
`source_row_columns` for payload discovery. Match-level activation summary
fields are repeated on each activation row for serving convenience, including:

- `activated_signal_instance_ids` (array of raw `signal_instance_id` values)
- `activated_signal_ids` (array of unique active `signal_id` values)
- `activated_signal_entities` (array of entity types such as match/team/player)
- `activated_signal_tags` (array of unique taxonomy tags from activated signals)
- `activated_signal_names` (array of unique signal name suffixes)
- `total_signal_rows` (raw activation row count in the match)
- `unique_signal_count` (distinct active signal IDs)

## Project Layout

```text
DepthMark/
  clickhouse/             ClickHouse DDL/DML by layer
  config/                 Python configuration modules
  data/fotmob/            raw Bronze files
  docker/                 Dockerfile, entrypoint; root docker-compose.yml is the main stack
  docs/                   project-wide architecture and contracts
  scripts/                operational entry points
  src/                    application services, scraper, storage, and utility code
```

Scripts are the supported operational entry points. Reusable workflow
coordination lives in layer-specific `src/services/` behind those scripts, but
Silver and Gold analytical transformations remain in ClickHouse SQL.

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
- `docs/data-flow/`: **source of truth** for system data flow, layer diagrams, and interactive wireframes
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
