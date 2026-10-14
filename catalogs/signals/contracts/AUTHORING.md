# Signal Authoring Guide

How to add, change, deprecate, rename, or delete a FotMob Gold signal. Artifact
rules live in [`CATALOG.md`](CATALOG.md), [`SQL.md`](SQL.md), and
[`TABLE.md`](TABLE.md); tags are defined in [`README.md`](README.md).

## The Signal Package

A signal is three authored files plus one generated index row:

| Part | Path |
| --- | --- |
| Catalog | `catalogs/signals/<signal_id>.md` |
| DML | `clickhouse/gold/dml/signals/<entity>/<signal_id>.sql` |
| DDL | the table in `clickhouse/gold/ddl/signals/<entity>/create_table_<entity>_<family>_<subfamily>.sql` |
| Index row | generated in `catalogs/signals/README.md` |

A package is complete only when all parts agree. **[catalog]** Every signal is
executed by the generic runner, `scripts/gold/run_fotmob_gold_jobs.py`; never
add a per-signal Python runner (ADR 0001, ADR 0009).

## Similarity Gate

Before implementing a new signal, check it against existing signals.

1. If its trigger logic, core metric predicates, and tactical intent are close
   to an existing signal, the author MUST stop and ask the owner to choose:
   keep the existing signal, or proceed with the new logic and say whether it
   replaces or coexists with the old one.
2. The request MUST name the closest signal ids and summarize overlap and
   differences.
3. Production changes SHOULD wait for that decision.

Keep the check cheap:

1. Scan only the index table in `catalogs/signals/README.md`. Filter by exact
   `Entity`, `Family`, and `Subfamily`. Include deprecated rows: retired logic
   is still a reason to stop.
2. Keep at most 8 candidates; prefer an exact `Grain` match, then the closest
   `signal_id`.
3. For the shortlist, read only frontmatter, Purpose, and the trigger.
4. Write a short overlap note: signal id, overlap, key difference (about 250
   words in total).
5. Open full catalogs or SQL only for the 2–3 closest candidates, or when the
   conflict risk is high.

The resulting note belongs in the new catalog's logic section.

## Add A Signal

1. Pass the similarity gate.
2. Write the catalog with `status: active` ([`CATALOG.md`](CATALOG.md)).
3. Write the DML ([`SQL.md`](SQL.md)) and add the table to its DDL file
   ([`TABLE.md`](TABLE.md)).
4. Validate and regenerate the index:

   ```bash
   python3 scripts/quality/check_signal_catalogs.py --write-index
   pytest tests/unit/test_signal_catalog.py tests/unit/test_data_quality.py
   python3 scripts/gold/run_fotmob_gold_jobs.py --date 20251208 --kind signal --id <signal_id> --dry-run
   ```

5. Create the table (`python3 scripts/orchestration/setup_fotmob_warehouse.py`)
   and run the signal for a real scope before release:

   ```bash
   python3 scripts/gold/run_fotmob_gold_jobs.py --date 20251208 --kind signal --id <signal_id>
   python3 scripts/gold/load_fotmob_gold.py --date 20251208 --part signals --dry-run
   ```

6. Sync MongoDB: `python3 scripts/mongodb/sync_signal_catalogs.py`.

## Change A Signal

- **Logic, thresholds, or catalog text**: edit the DML or catalog, validate as
  above, and rerun the affected scopes. Activation IDs do not change.
- **Output columns**: edit the DML and DDL together, then recreate the table
  (`scripts/maintenance/recreate_clickhouse_tables.py --drifted`, ADR 0026) and
  repopulate it.
- **`row_identity`**: an identity migration (ADR 0006). Update the catalog and
  the DDL hash together, recreate the table, and rebuild activations for full
  history, because every Signal Activation ID of the signal changes.

## Deprecate A Signal

1. Set `status: deprecated` and regenerate the index.
2. The signal stops running in Gold and leaves activations for every scope
   rebuilt afterwards. Rebuild activations for full history to remove it
   everywhere.
3. Its table, its identity checks, and its MongoDB document (now
   `status: deprecated`) remain.

Prefer deprecation over deletion: the catalog keeps the retired logic visible
to the similarity gate.

## Rename Or Delete A Signal

A rename is a new `signal_id`, so it is a new signal with new activation IDs.
Add the new signal and deprecate the old one rather than editing the id in
place.

To delete a signal, remove its catalog, DML, and DDL in one change and
regenerate the index. The next MongoDB sync deletes its document. Its warehouse
table and earlier activations remain until removed by explicit maintenance or
a full-history activation rebuild.

## Commits

- Each new signal is committed on its own, once its package is complete and the
  checks above pass. Do not batch several new signals into one commit or commit
  a partial package.
- If a commit cannot be created, stop and report the blocker before unrelated
  work continues.

Commit message templates:

```text
feat(signal): add <signal_id>
fix(signal): update <signal_id> — <one-line summary>
chore(signal): deprecate <signal_id>

Reason: <why>
Replacement: <signal_id or none>
```
