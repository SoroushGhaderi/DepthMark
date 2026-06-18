# Orchestration

Orchestration coordinates the full pipeline: scraping, Bronze loading, Silver
processing, Gold materialization, and activation rebuilds.

Bronze S3 sync is deliberately outside this orchestration boundary. Run
`scripts/bronze/sync_s3.py` independently when local/remote transfer is needed;
pipeline success never depends on S3 availability.

## Pipeline Flow

```text
pipeline.py [date]
  ├── 1. Bronze Scraping (scrape_fotmob.py)
  ├── 2. Bronze Loading (load_clickhouse.py)
  ├── 3. Silver Processing (load_clickhouse.py)
  ├── 4. Gold Loading (load_clickhouse_gold.py)
  │     ├── Scenario SQL jobs
  │     ├── Signal SQL jobs
  │     └── Activation rebuild
  └── Exit code: 0 = success, non-zero = failure
```

## Pipeline Script (`scripts/orchestration/pipeline.py`)

### CLI Interface

```bash
# Single date
python scripts/orchestration/pipeline.py 20251208
python scripts/orchestration/pipeline.py --single-date 20251208

# Date range
python scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207

# Full month
python scripts/orchestration/pipeline.py --month 202512

# Partial runs
python scripts/orchestration/pipeline.py 20251208 --bronze-only
python scripts/orchestration/pipeline.py 20251208 --silver-only
python scripts/orchestration/pipeline.py 20251208 --gold-only

# Skip stages
python scripts/orchestration/pipeline.py 20251208 --skip-bronze
python scripts/orchestration/pipeline.py 20251208 --skip-silver
python scripts/orchestration/pipeline.py 20251208 --skip-gold
python scripts/orchestration/pipeline.py 20251208 --skip-clickhouse
python scripts/orchestration/pipeline.py 20251208 --skip-fotmob

# Options
python scripts/orchestration/pipeline.py 20251208 --force
python scripts/orchestration/pipeline.py 20251208 --debug
```

### Execution Model

Pipeline calls each layer script through CLI subprocesses (ADR 0002):

1. Each stage is a subprocess call to the layer script.
2. Non-zero exit from any stage halts the pipeline.
3. `--skip-*` flags bypass stages entirely.
4. `--*-only` flags run exactly one stage.
5. Date range and month modes iterate dates sequentially.

### Mutually Exclusive Flags

- `date` / `--single-date` / `--start-date` / `--month` — one required
- `--bronze-only` / `--silver-only` / `--gold-only` — at most one

## Orchestrator (`src/orchestrator.py`)

The `FotMobOrchestrator` handles parallel scraping:

1. **Parallel scraping** — `ThreadPoolExecutor` fetches multiple matches
   concurrently.
2. **Daily listing** — Fetches match IDs for the target date.
3. **Match detail** — Fetches full payloads for each match.
4. **Turnstile refresh** — Handles token rotation when needed.
5. **Health checks** — Validates storage and API connectivity before scraping.

## Preflight Checks

Before running the full pipeline:

```bash
# System health
python scripts/health_check.py --json

# Preview Silver and Gold
python scripts/silver/load_clickhouse.py --dry-run
python scripts/gold/load_clickhouse_gold.py --dry-run

# Reconciliation
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict

# Logging style
python scripts/quality/check_logging_style.py
```

## MongoDB Sync

After Gold activation rebuild, sync signal catalogs to MongoDB:

```bash
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py --dry-run
python scripts/mongodb/sync_signal_catalogs.py
```

## Full Operational Sequence

```bash
# 1. Infrastructure
docker compose up -d
python scripts/orchestration/setup_clickhouse.py

# 2. Pipeline
python scripts/orchestration/pipeline.py 20251208

# 3. Catalog sync
python scripts/mongodb/init_indexes.py
python scripts/mongodb/sync_signal_catalogs.py

# 4. Validation
python scripts/quality/check_bronze_to_silver_reconciliation.py --strict
python scripts/health_check.py --json
```

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Scraping fails (API) | Re-run `scrape_fotmob.py` for affected dates |
| Bronze load fails | Re-run `load_clickhouse.py --date <date>` or `--single-date <date>` |
| Silver SQL fails | Fix SQL, re-run `silver/load_clickhouse.py` |
| Gold SQL fails | Re-run `run_sql_job.py --kind signal --id <id>` |
| Activation fails | Re-run `build_signal_activations.py` (requires populated `gold_signals.sig_*`) |
| Signal failures skipped activations | Fix signals, rerun `load_clickhouse_gold.py --part signals`, or run `build_signal_activations.py` |
| MongoDB sync fails | Re-run `sync_signal_catalogs.py` |
