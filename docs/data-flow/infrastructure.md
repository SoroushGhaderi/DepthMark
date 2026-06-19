# Infrastructure

DepthMark runs on Docker Compose with ClickHouse, MongoDB, and an optional
scraper container.

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
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py --single-date 20251208
```

Prerequisites: Docker and Docker Compose, Python 3.11 when running scripts
outside Docker, a valid `FOTMOB_X_MAS_TOKEN`, and ClickHouse and MongoDB
credentials in `.env`.

## Docker Lifecycle

```bash
cp .env.example .env
docker compose up -d
docker compose ps
docker compose down
docker compose down -v   # also removes volumes (destructive)
```

Optional scheduler profile:

```bash
docker compose --profile scheduler up -d
```

Run pipeline commands inside the scraper service (see
[`orchestration.md`](orchestration.md) and
[`../DEVELOPMENT_ARCHITECTURE.md`](../DEVELOPMENT_ARCHITECTURE.md) for the full
command surface):

```bash
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py 20251208
docker compose exec depthmark-scraper python scripts/orchestration/pipeline.py --single-date 20251208
```

## TouchDesk Integration

TouchDesk (separate repo) connects to this stack read-only. Start DepthMark
first, then run TouchDesk from its own `docker-compose.yml`:

```bash
cd ../DepthMark && docker compose up -d --build
cd ../TouchDesk && docker compose up -d --build
```

TouchDesk `docker-compose.override.yml` joins `depthmark_network` for
service-name access (`depthmark-clickhouse`, `depthmark-mongodb`). See the
TouchDesk README for remote-host options.

DepthMark does not call TouchDesk. TouchDesk reads `gold.*` / `gold_signals.*`
from ClickHouse and the signal catalog from MongoDB.

## Services

| Service | Image | Port | Purpose |
| --- | --- | --- | --- |
| depthmark-clickhouse | `clickhouse/clickhouse-server:24` | 8123 (HTTP), 9000 (native) | Data warehouse |
| depthmark-mongodb | `mongo:8.0` | 27017 | Content catalog |
| depthmark-scraper | Custom Python image | — | Runs pipeline scripts |

**Network:** creates Docker network `depthmark_network` (fixed name). TouchDesk
can join it optionally via `docker-compose.override.yml`.

## Docker Compose

Local development uses the root `docker-compose.yml` for `depthmark-clickhouse`,
`depthmark-mongodb`, and `depthmark-scraper`. Image build assets live under
`docker/` (`Dockerfile`, `docker-entrypoint.sh`).

## Environment Configuration

### Config Split

- `config.yaml` — non-sensitive settings (storage paths, feature flags)
- `.env` — credentials and secrets (never committed)

### Required `.env` Values

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

### Credential Policy (ADR 0005)

- `DEPTHMARK_ENV=local` — local Docker development only.
- `DEPTHMARK_ENV=production` — non-default credentials required.
- ClickHouse setup rejects placeholder passwords outside local development.

## ClickHouse Setup

```bash
python scripts/orchestration/setup_clickhouse.py
```

Runs DDL in layer order:
1. `clickhouse/bronze/00_create_database.sql` + 15 table DDLs
2. `clickhouse/silver/ddl/00_create_database.sql` + 8 table DDLs
3. `clickhouse/gold/ddl/` — databases, scenario tables, signal table DDL under
   `ddl/signals/{match,team,player}/`, and `ddl/create_table_signal_activations.sql`
4. Activation stage DDL (`ddl/activations/`) is applied during activation rebuilds,
   not during `setup_clickhouse.py`

## MongoDB Setup

```bash
python scripts/mongodb/init_indexes.py
```

Creates 5 collections with unique and compound indexes:
- `signals` — unique on `signal_id`
- `scenarios` — unique on `scenario_id`
- `channel_templates` — unique on `template_id`
- `content_versions`
- `scenario_signal_map`

## Configuration Module (`config/settings.py`)

Unified pydantic-settings based configuration — single source of truth for all settings:

**Infrastructure settings** (from `.env` / environment variables):
- `clickhouse_host`, `clickhouse_port`, `clickhouse_user`, `clickhouse_password`
- `clickhouse_db_fotmob`, `clickhouse_db_gold`, `clickhouse_db_gold_scenarios`, `clickhouse_db_gold_signals`
- `telegram_bot_token`, `telegram_chat_id`, `telegram_enabled`
- standalone Bronze S3 sync reads `S3_ENDPOINT`, `S3_ACCESS_KEY`,
  `S3_SECRET_KEY`, optional `S3_BUCKET`, and optional `S3_REGION` directly from
  the environment
- `environment`, `log_level`, `log_dir`, `data_dir`

**FotMob scraping settings** (from `config.yaml` with env-var overrides):
- `fotmob.api.base_url`, `fotmob.api.user_agents`, `fotmob.api.x_mas_token`
- `fotmob.request.timeout`, `fotmob.request.delay_min`, `fotmob.request.delay_max`
- `fotmob.scraping.max_workers`, `fotmob.scraping.enable_parallel`
- `fotmob.storage.bronze_path`, `fotmob.storage.enabled`
- `fotmob.retry.*`, `fotmob.logging.*`, `fotmob.data_quality.*`, `fotmob.proxy.*`

Env vars override YAML values: `FOTMOB_X_MAS_TOKEN`, `FOTMOB_MAX_WORKERS`, etc.

`FotMobConfig` is a backward-compatible adapter that delegates to `Settings.fotmob`.

## Health Checks

```bash
python scripts/health_check.py --json
```

Checks:
- ClickHouse connectivity and query execution
- Storage path accessibility and write permissions
- Disk space against configurable threshold (GB)

## Alerting

`src/utils/alerting.py` provides `alert_health_check_failure()` for
standardized alerts when health checks fail.

## Bronze Storage

Configured in `config.yaml`:
```yaml
fotmob:
  storage:
    bronze_path: data/fotmob
    enabled: true
```

Storage structure:
```text
data/fotmob/
  historical/
    matches/{YYYYMMDD}/match_{id}.json[.gz]  completed-date payloads
    daily_listings/{YYYYMMDD}/matches.json   completed-date listings
  live/
    matches/{YYYYMMDD}/match_{id}.json       latest Live payloads
    daily_listings/{YYYYMMDD}/matches.json   refreshed Live listings
data/dlq/                           dead letter queue files
```

`FOTMOB_BRONZE_PATH` continues to configure the common `data/fotmob` root.
Historical loaders and S3 sync use only the `historical/` aspect. Migrate the
legacy layout with `scripts/bronze/migrate_fotmob_storage.py` (dry-run) and then
repeat with `--apply`.

S3-compatible storage is not part of the scrape or pipeline lifecycle. The
operator runs `scripts/bronze/sync_s3.py` explicitly. Uploads create temporary
`tar.gz` transfer archives containing both canonical date directories and store
them at `bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz`; the sync command does not modify
the scraper's local compression state or delete canonical local artifacts.

## Production Deployment

The tracked Docker Compose files are **local-development manifests**. They
expose database ports and keep local bootstrap defaults.

For production:
1. Use separate deployment configuration.
2. Set `DEPTHMARK_ENV=production`.
3. Provide non-default database credentials.
4. Do not expose database ports externally.
5. Use proper secrets management.
