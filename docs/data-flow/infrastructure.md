# Infrastructure

DepthMark runs on Docker Compose with ClickHouse, MongoDB, and a scraper
container. The same Compose stack serves servers and local development
(ADR 0030).

## Quick Start

One command initializes a new server; it needs only Docker with Compose v2 and
a checkout. It is safe to rerun, for example after `git pull`:

```bash
git clone <repository-url> DepthMark
cd DepthMark
FOTMOB_X_MAS_TOKEN=<token> scripts/bootstrap.sh
```

`scripts/bootstrap.sh`:

1. Creates `.env` from `.env.example` (or adds keys a newer template
   introduced), generates the ClickHouse application, ClickHouse maintenance,
   and MongoDB passwords when they are missing or placeholders, writes any
   exported `FOTMOB_X_MAS_TOKEN`, `TELEGRAM_*`, or `S3_*` secrets, and sets
   `DEPTHMARK_ENV=production` and `DEPTHMARK_UID`.
2. Builds the image, starts the stack, and waits for ClickHouse and MongoDB to
   report healthy.
3. Runs FotMob and Oddspedia warehouse setup, MongoDB index setup, and the
   signal catalog sync inside the scraper container, then the health check.
4. Installs the recurring schedule in the user's crontab (see
   [Scheduling](#scheduling)).

It also creates the paths Compose bind-mounts (`data/`, `logs/`, and an empty
`credentials.json`), because Docker would otherwise create them as root-owned
directories.

Options: `--local` sets `DEPTHMARK_ENV=local` for development,
`--no-schedule` skips the crontab, and `--env-only` only prepares `.env` and
the local files without touching Docker.
Existing real values in `.env` are never replaced, so reruns keep database
credentials stable.

Run pipelines inside the scraper container:

```bash
docker compose exec depthmark-scraper python3 scripts/orchestration/run_fotmob_pipeline.py 20251208
docker compose exec depthmark-scraper python3 scripts/orchestration/run_fotmob_pipeline.py --full-history
```

Prerequisites: Docker and Docker Compose, Python 3.11 when running scripts
outside Docker, a valid `FOTMOB_X_MAS_TOKEN`, and ClickHouse and MongoDB
credentials in `.env`.

To run commands outside Docker, install DepthMark in editable mode from the
repository root. This also provides the `depthmark` command:

```bash
uv sync --extra dev          # creates .venv from uv.lock, installs DepthMark editable
source .venv/bin/activate
pre-commit install
depthmark --help
```

Without uv, `python3 -m pip install -r requirements.txt` followed by
`python3 -m pip install -e ".[dev]"` installs the same runtime versions.

DepthMark runs from a source checkout: the `depthmark` command dispatches to
scripts by path and reads `clickhouse/` SQL and configuration files from the
checkout. A non-editable wheel install is not supported, and the command
exits with an error when it cannot find the checkout.

## Docker Lifecycle

```bash
scripts/bootstrap.sh          # first start and every upgrade
docker compose ps
docker compose down
docker compose down -v   # also removes volumes (destructive)
```

Compose has no scheduler service; recurring runs come from an external
scheduler (see [Scheduling](#scheduling)).

Run pipeline commands inside the scraper service (see
[`orchestration.md`](orchestration.md) and
[`../DEVELOPMENT_ARCHITECTURE.md`](../DEVELOPMENT_ARCHITECTURE.md) for the full
command surface):

```bash
docker compose exec depthmark-scraper python3 scripts/orchestration/run_fotmob_pipeline.py 20251208
docker compose exec depthmark-scraper python3 scripts/orchestration/run_fotmob_pipeline.py --single-date 20251208
```

## TouchDesk Integration

TouchDesk (separate repo) connects to this stack read-only. Start DepthMark
first, then run TouchDesk from its own `docker-compose.yml`:

```bash
cd ../DepthMark && docker compose up -d --build
cd ../TouchDesk && docker compose up -d --build
```

TouchDesk `docker-compose.override.yml` joins `depthmark_network` for
service-name access (`depthmark-clickhouse`, `depthmark-mongodb`). Published
database ports bind to `127.0.0.1` by default, so a TouchDesk on another host
needs `DEPTHMARK_BIND_ADDRESS` set to a trusted private interface. See the
TouchDesk README for remote-host options.

DepthMark does not call TouchDesk. TouchDesk reads `gold.*` / `gold_signals.*`
from ClickHouse and the signal catalog from MongoDB. Before trusting a month
partition, TouchDesk should check that its latest status in
`gold.scope_publication` is `published` (ADR 0028).

## Services

| Service | Image | Port | Purpose |
| --- | --- | --- | --- |
| depthmark-clickhouse | `clickhouse/clickhouse-server:24` | 127.0.0.1:8123 (HTTP), 127.0.0.1:9000 (native) | Data warehouse |
| depthmark-mongodb | `mongo:8.0` | 127.0.0.1:27017 | Content catalog |
| depthmark-scraper | Custom Python image | — | Runs pipeline scripts |

**Network:** creates Docker network `depthmark_network` (fixed name). TouchDesk
can join it optionally via `docker-compose.override.yml`.

## Docker Compose

Local development uses the root `docker-compose.yml` for `depthmark-clickhouse`,
`depthmark-mongodb`, and `depthmark-scraper`. Image build assets live under
`docker/` (`Dockerfile`, `docker-entrypoint.sh`).

## Scheduling

DepthMark has no scheduler service (ADR 0027). `scripts/bootstrap.sh` installs
the recurring jobs into the host user's crontab through
`scripts/install_schedule.sh`, which can also be run on its own:

```bash
scripts/install_schedule.sh            # install or refresh
scripts/install_schedule.sh --remove   # remove
```

The installer writes one marked block keyed by the checkout path and replaces
it on every run, so jobs are never duplicated and other crontab entries are
kept. Each job runs `scripts/orchestration/run_scheduled_job.py` inside the
scraper container, which owns the job's date and overlap lock (ADR 0030):

| Time (host clock) | Job | Runs |
| --- | --- | --- |
| 03:00 | `fotmob-daily` | `run_fotmob_pipeline.py` for yesterday (completed dates only) |
| 05:00 | `oddspedia-daily` | `run_oddspedia_pipeline.py --date <two days ago, UTC> --silver-reference-window-ready` |

- A job whose previous run still holds its lock under
  `data/locks/scheduled/` is skipped with exit code 0. Oddspedia commands also
  take their own per-date locks under `data/oddspedia/locks/`.
- Otherwise the exit code is the pipeline's exit code. Output goes to
  `logs/scheduler/<job>.log`; FotMob layer completion alerts also go to
  Telegram when configured.
- Oddspedia priority and resolution need FotMob Silver for the previous,
  current, and following date, so it runs two days back, after FotMob.
  `--silver-reference-window-ready` asserts that ordering; the command still
  verifies the FotMob reference window and fails closed when it is incomplete.
- Preview a job without running it:
  `docker compose exec depthmark-scraper python3 scripts/orchestration/run_scheduled_job.py fotmob-daily --dry-run`.

## Environment Configuration

### Config Split

- `config.yaml` — non-sensitive settings (storage paths, feature flags)
- `.env` — credentials and secrets (never committed)

### Required `.env` Values

```bash
FOTMOB_X_MAS_TOKEN=your_token_here
DEPTHMARK_ENV=production   # bootstrap sets local with --local
DEPTHMARK_BIND_ADDRESS=127.0.0.1
DEPTHMARK_UID=1000          # bootstrap sets the host UID
CLICKHOUSE_HOST=depthmark-clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=fotmob_user
CLICKHOUSE_PASSWORD=your_clickhouse_password_here
CLICKHOUSE_MAINTENANCE_USER=depthmark_admin
CLICKHOUSE_MAINTENANCE_PASSWORD=your_clickhouse_maintenance_password_here
MONGODB_HOST=depthmark-mongodb
MONGODB_PORT=27017
MONGODB_USER=orbit_admin
MONGODB_PASSWORD=your_mongodb_password_here
MONGODB_DATABASE=orbit_content
```

### ClickHouse Identities (ADR 0029)

| Identity | Variables | Rights | Used by |
| --- | --- | --- | --- |
| Application | `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` | `SELECT, INSERT, ALTER DELETE` on warehouse databases; create, drop, optimize, and truncate only in `warehouse_stage` | Bronze loads and `--replace`, scoped `remove_fotmob_bronze.py`, date/month Silver and Gold loads, activations, Oddspedia loads and resolution, quality checks |
| Maintenance | `CLICKHOUSE_MAINTENANCE_USER` / `CLICKHOUSE_MAINTENANCE_PASSWORD` | Full access with access management | Both setup commands, full-history loads (`EXCHANGE TABLES`) including `load_fotmob_bronze.py --full-history --rebuild`, `remove_fotmob_bronze.py --full-history` (truncate), Table Recreation, optimization, drop scripts |

The ClickHouse container creates the maintenance user from these variables.
Setup connects as the maintenance user and creates or resets the application
user to its narrow grants on every run, so the two names must differ. All
staging tables live in `warehouse_stage`; the application user cannot drop,
truncate, optimize, rename, or alter columns of a warehouse table.

### Credential Policy (ADR 0005)

- `DEPTHMARK_ENV=local` — local Docker development only.
- `DEPTHMARK_ENV=production` — non-default credentials required.
- ClickHouse setup rejects placeholder passwords outside local development.
- Compose has no password defaults: `docker compose` refuses to start unless
  `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_MAINTENANCE_PASSWORD`, and
  `MONGODB_PASSWORD` are set in `.env`.
- Database ports publish on `DEPTHMARK_BIND_ADDRESS` (default `127.0.0.1`).

The environment selector is read explicitly from the process environment or
the project/parent `.env` files. Do not rely on an undeclared default: set
`DEPTHMARK_ENV=production` in every production deployment.

### Oddspedia Browser Configuration

The Oddspedia driver auto-detects supported Chrome/Chromium and matching
platform driver candidates. Set an explicit path when the runtime uses a
non-standard installation or container image:

```bash
ODDSPEDIA_CHROME_BIN=/usr/bin/chromium
ODDSPEDIA_CHROMEDRIVER_PATH=/usr/bin/chromedriver
```

`CHROME_BIN` and `CHROMEDRIVER_PATH` remain accepted compatibility aliases.
The driver resolves platform and architecture candidates on macOS, Linux, and
Windows; an unsupported architecture must provide an explicit executable.

## ClickHouse Setup

```bash
python3 scripts/orchestration/setup_fotmob_warehouse.py
```

Runs DDL in layer order:
1. `clickhouse/bronze/00_create_database.sql` + 15 table DDLs
2. `clickhouse/silver/ddl/00_create_database.sql` + 8 table DDLs
3. `clickhouse/gold/ddl/` — databases, scenario tables, signal table DDL under
   `ddl/signals/{match,team,player}/`, and `ddl/create_table_signal_activations.sql`
4. Activation stage DDL (`ddl/activations/`) is applied during activation rebuilds,
   not during setup

Setup runs explicitly, once for a new warehouse and again after setup DDL
changes; containers do not run it on start.

Oddspedia has an independent setup command:

```bash
python3 scripts/oddspedia/setup_oddspedia_warehouse.py
python3 scripts/oddspedia/setup_oddspedia_warehouse.py --dry-run
```

It creates `oddspedia_bronze.event`, `oddspedia_bronze.match_payload`,
`oddspedia_bronze.market`, `oddspedia_bronze.load_status`, and
`silver.oddspedia_match_resolution`. The source loader publishes a date only
after all three Bronze fact tables are staged, validated, and replaced; the
resolver refuses dates without the resulting `published` status.

Setup is schema-only and non-destructive: both setup commands only create
missing databases and tables, and never drop, alter, or optimize a table.
Before creating anything they compare existing tables with their DDL. Schema
drift (a different column name, column type, or `ORDER BY` key) stops setup
with a non-zero exit and a list of the drifted tables.

## ClickHouse Table Recreation

Apply schema drift with an explicit Table Recreation. It drops the selected
tables, recreates them empty from setup DDL, and never reloads rows. The command
plans by default:

```bash
python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted
python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted --execute
```

The plan lists each selected table with its current row count. After
`--execute`, reload the affected scope with the normal layer loader (the
command logs the matching loader command).

## ClickHouse Optimization Maintenance

Run optimization only as explicit operator maintenance after reviewing physical
row-version diagnostics from `check_data_quality.py`. The maintenance command
is dry-run by default:

```bash
python3 scripts/maintenance/optimize_clickhouse.py --layer bronze
python3 scripts/maintenance/optimize_clickhouse.py --layer silver --execute
python3 scripts/maintenance/optimize_clickhouse.py --layer gold --database gold_signals
python3 scripts/maintenance/optimize_clickhouse.py --database gold_signals --table sig_team_shooting_goals_efficiency_peak --execute
```

Use `--execute` only after the planned `OPTIMIZE TABLE ... FINAL DEDUPLICATE`
statements are acceptable for the selected layer, database, or table.

## MongoDB Setup

```bash
python3 scripts/mongodb/init_indexes.py
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
- `s3_endpoint`, `s3_access_key`, `s3_secret_key`, optional `s3_bucket` and
  `s3_region` (standalone Bronze S3 sync)
- `mongodb_host`, `mongodb_port`, `mongodb_user`, `mongodb_password`,
  `mongodb_database`, `mongodb_auth_source`, optional `mongodb_uri`
- `clickhouse_gold_target_db` (optional Gold output redirect)
- `environment`, `deployment_environment` (first of `DEPTHMARK_ENV`,
  `ENVIRONMENT`, `SCRAPER_ENV`), `log_level`, `log_dir`, `data_dir`

**FotMob scraping settings** (from `config.yaml` with env-var overrides):
- `fotmob.api.base_url`, `fotmob.api.user_agents`, `fotmob.api.x_mas_token`
- `fotmob.request.timeout`, `fotmob.request.delay_min`, `fotmob.request.delay_max`
- `fotmob.scraping.max_workers`, `fotmob.scraping.enable_parallel`
- `fotmob.storage.bronze_path`, `fotmob.storage.enabled`
- `fotmob.retry.*`, `fotmob.logging.*`, `fotmob.data_quality.*`, `fotmob.proxy.*`

`config/settings.py` is the only reader of configuration. Precedence, highest
first: process environment, the documented flat names in
`NESTED_ENV_ALIASES` (`FOTMOB_X_MAS_TOKEN`, `FOTMOB_MAX_WORKERS`,
`FOTMOB_TIMEZONE`, `ODDSPEDIA_MIN_DELAY`, `ODDSPEDIA_CHROME_BIN`/`CHROME_BIN`,
...), `.env` in the checkout and its parent (the checkout wins), the `fotmob` and
`oddspedia` sections of `config.yaml`, then defaults. Any nested field can also
be set with `__`, for example `FOTMOB__REQUEST__TIMEOUT=45`. pydantic validates
every value, so a malformed number or boolean fails at startup instead of being
silently coerced. FotMob code receives the `Settings.fotmob` model directly;
the `FotMobConfig` adapter and the legacy `config/base.py` dataclasses are gone.

## Health Checks

```bash
python3 scripts/health_check.py --json
```

Checks:
- ClickHouse connectivity and query execution
- Storage path accessibility and write permissions
- Disk space against configurable threshold (GB)

## Alerting

`src/operations/health.py` coordinates standardized health-check failure
notifications through the `src/integrations/telegram/` adapter.

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
    matches/{YYYYMM}/{YYYYMMDD}/match_{id}.json[.gz]  completed-date payloads
    daily_listings/{YYYYMM}/{YYYYMMDD}/matches.json   completed-date listings
  live/
    matches/{YYYYMM}/{YYYYMMDD}/match_{id}.json       latest Live payloads
    daily_listings/{YYYYMM}/{YYYYMMDD}/matches.json   refreshed Live listings
data/dlq/                           dead letter queue files
```

`FOTMOB_BRONZE_PATH` continues to configure the common `data/fotmob` root.
Historical loaders and S3 sync use only the `historical/` aspect.

S3-compatible storage is not part of the scrape or pipeline lifecycle. The
operator runs `scripts/bronze/sync_s3.py` explicitly. Uploads create temporary
`tar.gz` transfer archives containing both canonical date directories and store
them at `bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz`; the sync command does not modify
the scraper's local compression state or delete canonical local artifacts.

## Production Deployment

The tracked Compose stack is the supported server deployment (ADR 0030). Run
`scripts/bootstrap.sh` on the server; it sets `DEPTHMARK_ENV=production`,
generates strong database passwords into `.env` (mode `600`), and keeps the
database ports on `127.0.0.1`.

- Keep `.env` on the server only and back it up with the data volumes; the
  generated passwords are the only copy.
- Expose ClickHouse or MongoDB beyond the host only over a trusted private
  network (`DEPTHMARK_BIND_ADDRESS`) or a TLS-terminating proxy.
- Containers restart with Docker (`restart: unless-stopped`); enable the
  Docker service at boot so the stack returns after a reboot.
- Upgrades: `git pull && scripts/bootstrap.sh`. Setup fails closed on schema
  drift (ADR 0026); apply it with Table Recreation, then rerun the bootstrap.
