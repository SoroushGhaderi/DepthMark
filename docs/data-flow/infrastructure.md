# Infrastructure

DepthMark runs on Docker Compose with ClickHouse, MongoDB, and an optional
scraper container.

## Services

| Service | Image | Port | Purpose |
| --- | --- | --- | --- |
| clickhouse | `clickhouse/clickhouse-server:24` | 8123 (HTTP), 9000 (native) | Data warehouse |
| mongodb | `mongo:8.0` | 27017 | Content catalog |
| scraper | Custom Python image | — | Runs pipeline scripts |

## Docker Compose Files

| File | Purpose |
| --- | --- |
| `docker/docker-compose.yml` | Full local stack (ClickHouse + MongoDB + scraper) |
| `docker/docker-compose.clickhouse.yml` | ClickHouse only |

## Environment Configuration

### Config Split

- `config.yaml` — non-sensitive settings (storage paths, feature flags)
- `.env` — credentials and secrets (never committed)

### Required `.env` Values

```bash
FOTMOB_X_MAS_TOKEN=your_token_here
DEPTHMARK_ENV=local
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=fotmob_user
CLICKHOUSE_PASSWORD=your_clickhouse_password_here
MONGODB_HOST=mongodb
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
3. `clickhouse/gold/00_create_database.sql` + scenario/signal/activation DDLs

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

Pydantic-settings based configuration:
- `clickhouse_host`, `clickhouse_port`, `clickhouse_user`, `clickhouse_password`
- `mongodb_host`, `mongodb_port`, `mongodb_user`, `mongodb_password`, `mongodb_database`
- `fotmob_api_token`, `fotmob_api_base_url`
- `enable_health_checks`, `enable_alerting`

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
  raw/{YYYYMMDD}/{match_id}.json    raw match payloads
  listings/{YYYYMMDD}.json          daily match listings
  compressed/{YYYYMMDD}.tar         optional archives
data/dlq/                           dead letter queue files
```

## Production Deployment

The tracked Docker Compose files are **local-development manifests**. They
expose database ports and keep local bootstrap defaults.

For production:
1. Use separate deployment configuration.
2. Set `DEPTHMARK_ENV=production`.
3. Provide non-default database credentials.
4. Do not expose database ports externally.
5. Use proper secrets management.
