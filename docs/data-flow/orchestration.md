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
python3 scripts/orchestration/pipeline.py 20251208
python3 scripts/orchestration/pipeline.py --date 20251208
python3 scripts/orchestration/pipeline.py --single-date 20251208

# Date range
python3 scripts/orchestration/pipeline.py --start-date 20251201 --end-date 20251207

# Full month
python3 scripts/orchestration/pipeline.py --month 202512

# Full history (scraping is intentionally skipped)
python3 scripts/orchestration/pipeline.py --full-history

# Partial runs
python3 scripts/orchestration/pipeline.py 20251208 --bronze-only
python3 scripts/orchestration/pipeline.py 20251208 --silver-only
python3 scripts/orchestration/pipeline.py 20251208 --gold-only

# Skip stages
python3 scripts/orchestration/pipeline.py 20251208 --skip-bronze
python3 scripts/orchestration/pipeline.py 20251208 --skip-silver
python3 scripts/orchestration/pipeline.py 20251208 --skip-gold
python3 scripts/orchestration/pipeline.py 20251208 --skip-clickhouse
python3 scripts/orchestration/pipeline.py 20251208 --skip-fotmob

# Options
python3 scripts/orchestration/pipeline.py 20251208 --force
python3 scripts/orchestration/pipeline.py 20251208 --debug
```

### Execution Model

Pipeline calls each layer script through CLI subprocesses (ADR 0002):

1. Each stage is a subprocess call to the layer script.
2. The selected date, month, or full-history scope is propagated to downstream
   layer scripts.
3. `--skip-*` flags bypass stages entirely.
4. `--*-only` flags run exactly one stage.
5. Date ranges invoke downstream loads once per date; month mode invokes one
   month-scoped load.
6. Full-history mode skips scraping and runs Historical Bronze loading, Silver,
   and Gold with `--full-history`.

### Mutually Exclusive Flags

- `date` / `--date` / `--single-date` / `--start-date` / `--month` /
  `--full-history` — one required
- `--bronze-only` / `--silver-only` / `--gold-only` — at most one

## Orchestrator (`src/orchestrator.py`)

The `FotMobOrchestrator` handles sequential scraping:

1. **Sequential scraping** — fetches one match at a time to reduce FotMob
   rate-limit and ban risk.
2. **Daily listing** — Fetches match IDs for the target date.
3. **Match detail** — Fetches full payloads for each match.
4. **Turnstile refresh** — Handles token rotation when needed.
5. **Health checks** — Validates storage and API connectivity before scraping.

The warehouse pipeline operates on Historical dates only. Live scraping is an
independent `scrape_fotmob.py --today` journey and does not invoke Bronze
loading, Silver, Gold, or S3 sync.

## Preflight Checks

Before running the full pipeline:

```bash
# System health
python3 scripts/health_check.py --json

# Preview Silver and Gold
python3 scripts/silver/load_clickhouse.py --date 20251208 --dry-run
python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run

# Read-only duplicate checks plus Bronze-to-Silver reconciliation
python3 scripts/quality/check_data_quality.py --date 20251208 --strict

# Logging style
python3 scripts/quality/check_logging_style.py
```

## MongoDB Sync

After Gold activation rebuild, sync signal catalogs to MongoDB:

```bash
python3 scripts/mongodb/init_indexes.py
python3 scripts/mongodb/sync_signal_catalogs.py --dry-run
python3 scripts/mongodb/sync_signal_catalogs.py
```

## Post-load Data Quality

The canonical quality workflow is
`scripts/quality/check_data_quality.py`. It performs two deliberately separate
classes of read-only SQL validation:

1. Duplicate identities across Bronze, Silver, and Gold. Bronze and Silver
   identities come from layer contracts; scenario identities come from DDL
   `ORDER BY`; signal identities come from catalog `row_identity`; activations
   use `signal_instance_id`.
2. Bronze-to-Silver reconciliation for match, period, player, momentum, shot,
   card, personnel, and team-form identity sets. Both missing-from-Silver and
   unexpected-in-Silver keys are failures.

| Layer / tables | Duplicate row identity |
| --- | --- |
| Bronze `general`, `timeline`, `venue`, `match_reference` | `match_id` |
| Bronze `player`, `starters`, `substitutes` | `match_id, player_id` |
| Bronze `shotmap` | `match_id, shot_id` |
| Bronze `goal`, `cards`, `red_card` | `match_id, event_id` |
| Bronze `period`; `momentum`; `coaches` | `match_id, period`; `match_id, minute`; `match_id, coach_id` |
| Bronze `team_form` | `match_id, team_id, form_position` |
| Silver `match` | `match_id` |
| Silver `period_stat`; `momentum` | `match_id, period`; `match_id, minute` |
| Silver `player_match_stat`; `shot`; `card` | `match_id, player_id`; `match_id, shot_id`; `match_id, event_id` |
| Silver `match_personnel`; `team_form` | `match_id, team_side, role, person_id`; `match_id, team_id, form_position` |
| Gold scenarios | Columns declared by each table's DDL `ORDER BY` grain |
| Gold signals | Each catalog's ordered `row_identity` columns |
| `gold.signal_activations` | `signal_instance_id` |

The ephemeral `gold.signal_activations_stage` rebuild table is not a stable
quality target; if present during a check, it is reported as skipped.

Gold is not reconciled to either upstream layer. Gold outputs apply separate
business logic, filters, aggregation, and entity grains, so row-count or key
parity would report expected product behavior as a defect. Gold remains covered
by duplicate detection.

```bash
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/quality/check_data_quality.py --month 202512 --strict
python3 scripts/quality/check_data_quality.py --full-history --strict
python3 scripts/quality/check_data_quality.py --month 202512 --layers gold --strict
```

The script reports existing tables whose grain or row identity is undefined.
On a completed run, exit `0` means clean or non-strict findings; strict mode
exits `1` when duplicates or Bronze-to-Silver mismatches exist. Argument errors
exit `2`; connection or query errors exit `1`. The legacy
`check_bronze_to_silver_reconciliation.py` command remains available and
forwards its compatible options to the unified workflow.

## Full Operational Sequence

```bash
# 1. Infrastructure
docker compose up -d
python3 scripts/orchestration/setup_clickhouse.py

# 2. Pipeline
python3 scripts/orchestration/pipeline.py 20251208

# 3. Catalog sync
python3 scripts/mongodb/init_indexes.py
python3 scripts/mongodb/sync_signal_catalogs.py

# 4. Validation
python3 scripts/quality/check_data_quality.py --date 20251208 --strict
python3 scripts/health_check.py --json
```

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Scraping fails (API) | Re-run `scrape_fotmob.py` for affected dates |
| Bronze load fails | Re-run `load_clickhouse.py --date <date>` or `--single-date <date>` |
| Silver SQL fails | Fix SQL, re-run `silver/load_clickhouse.py --date <YYYYMMDD>` for the same scope |
| Gold SQL fails | Re-run `run_gold_sql_jobs.py --date <YYYYMMDD> --kind signal --id <id>` |
| Activation fails | Re-run `build_signal_activations.py --date <YYYYMMDD>` with the same scope |
| Signal failures skipped activations | Fix signals, rerun `load_clickhouse_gold.py --date <YYYYMMDD> --part signals` |
| Commit fails after some tables changed | Re-run the identical scope; replacement converges safely |
| MongoDB sync fails | Re-run `sync_signal_catalogs.py` |
