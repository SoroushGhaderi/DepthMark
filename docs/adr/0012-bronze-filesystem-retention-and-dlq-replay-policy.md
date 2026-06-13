# ADR 0012: Bronze Filesystem Retention and DLQ Replay Policy

## Status

Accepted

## Context

Bronze is the only filesystem-backed data layer in DepthMark. Raw FotMob API
payloads are stored under `data/fotmob/` as match JSON files, daily listings,
and compressed tar archives. Failed ClickHouse insertions are written to
`data/dlq/` as JSONL files by `src/storage/dlq.py`.

Neither layer has a documented retention or cleanup policy. Files accumulate
indefinitely. The DLQ class docstring claims "replay" capability, but no
automated reprocessing code exists — only `get_dlq_records()` for reading records
back.

The Bronze loader (`scripts/bronze/load_clickhouse.py`) does not track which
filesystem files have been loaded to ClickHouse. It relies on
`ReplacingMergeTree` deduplication at the ClickHouse level. There is no
filesystem-side load-confirmation marker.

Operators need to know: how long to keep Bronze and DLQ files, how to safely
clean up, and what to do when DLQ files appear.

## Decision

Bronze filesystem files and DLQ files are retained indefinitely by default.
There are no automated deletion scripts, TTL mechanisms, or rotation policies for
either layer.

Cleanup of Bronze files (match JSONs, daily listings, tar archives) and DLQ
files is operator-initiated and manual only. Before deleting Bronze files for a
date, the operator queries ClickHouse `bronze.*` tables directly to verify the
data is loaded. No filesystem-side load-confirmation marker is used because it
would go stale on re-runs, `--truncate` reloads, or table drops.

DLQ replay is a manual operator workflow. When ClickHouse insertion failures
produce DLQ files, the operator inspects the JSONL records, fixes the root
cause, and re-runs the Bronze loader for the affected date. No automated retry
or reprocessing script exists or is planned.

## Consequences

Operators retain full control over when raw data is deleted. No automated
process can accidentally remove payloads that might be needed for debugging,
re-loading after a schema change, or auditing.

The absence of load-confirmation markers means operators must query ClickHouse
before cleanup. This is a deliberate trade-off: a marker would go stale on
re-runs and provide false confidence.

DLQ files are small and infrequent (created only on insertion failure), so
indefinite retention has minimal disk cost and preserves audit evidence.

## Operator Runbook

### Inspecting DLQ files

```bash
# List DLQ files
ls data/dlq/

# Read all records for a specific table and date
cat data/dlq/player_20260115.jsonl | python -m json.tool

# Get DLQ statistics
python -c "
from src.storage.dlq import DeadLetterQueue
dlq = DeadLetterQueue()
stats = dlq.get_dlq_stats()
print(f'Total files: {stats[\"total_files\"]}')
print(f'Total records: {stats[\"total_records\"]}')
print(f'By table: {stats[\"by_table\"]}')
"
```

### Verifying data is loaded before deleting Bronze files

```bash
# Check row count for a date in a bronze table
python -c "
from clickhouse_driver import Client
client = Client(host='localhost', port=9000, user='default', password='')
count = client.execute('SELECT count() FROM bronze.match_reference WHERE date = \\'20260115\\'')[0][0]
print(f'match_reference rows for 20260115: {count}')
"
```

### Safe manual cleanup

After verifying ClickHouse has the data:

```bash
# Remove a specific date's match files
rm -rf data/fotmob/matches/20260115

# Remove corresponding daily listing
rm -rf data/fotmob/daily_listings/20260115

# Remove DLQ files for a resolved table+date
rm data/dlq/player_20260115.jsonl
```

Always verify before deleting. There is no undo.
