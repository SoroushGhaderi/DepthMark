# Gold Signal Execution Contract (Codex Low)

This contract defines the low-variance implementation part of Gold signals:

1. Creating and maintaining table DDL
2. Maintaining generic SQL execution and standard orchestration glue
3. Enforcing deterministic execution and release checks

This document is intended for routine implementation work where structure and consistency matter most.

> Normative language (`MUST`/`SHOULD`/`MAY`) is defined in `SIGNAL_CONTRACT.md` § Normative Language.

## Scope

This contract applies to:

- `clickhouse/gold/ddl/signals/{match,team,player}/create_table_{entity}_{family}_{subfamily}.sql` (or active signal DDL set)
- `clickhouse/gold/dml/signals/*/sig_*.sql`
- `scripts/gold/run_gold_sql_jobs.py`
- `src/services/gold/gold_dml_runner.py`
- `scripts/gold/load_clickhouse_gold.py`
- cross-asset wiring among SQL, table, and catalog files

Compatibility note:

- Legacy per-signal runner files may exist during migration.
- New work MUST NOT add handwritten per-signal Python runner files.

## Repository Layout Contract

`scripts/gold/signal/` MUST contain:

1. `catalogs/` for per-signal documentation (`sig_*.md`)
2. `SIGNAL_CONTRACT.md` as the top-level index to active contracts
3. `SIGNAL_CORE_CONTRACT.md` for creative/high-value logic contract
4. `SIGNAL_EXECUTION_CONTRACT.md` for routine execution contract

Operational compatibility:

- `runners/` MAY temporarily include legacy per-signal files while old jobs are being migrated.
- New or renamed signals MUST be executable through `scripts/gold/run_gold_sql_jobs.py`.

## Signal Package Contract

Each signal MUST ship as one 4-part package:

1. SQL transform: `clickhouse/gold/dml/signals/<entity>/sig_<name>.sql`
2. Target table: `gold_signals.sig_<name>`
3. Catalog: `scripts/gold/signal/catalogs/sig_<name>.md`
4. Catalog index entry in `scripts/gold/signal/catalogs/README.md`

No package is complete unless all 4 parts are present and consistent.

## Naming and Consistency Contract

1. Signal IDs MUST follow `sig_<name>` in `snake_case`.
2. Prefix MUST be `sig_` only for new work.
3. SQL filename and table suffix MUST match exactly by `<name>`.
4. Generic SQL job resolution MUST deterministically map signal id to SQL file (`sig_<name>` -> `sig_<name>.sql`) and target table (`gold_signals.sig_<name>`).
5. Catalog filename MUST be `catalogs/sig_<name>.md`.

## Runner Contract

1. The generic Gold SQL runner MUST:
   - initialize `ClickHouseClient`
   - load SQL from the selected signal SQL file
   - build a `ScopedSqlJob` for the validated execution scope
   - stage the insert query through `ScopedReplacementBatch`
   - commit with scoped partition replacement or full-history table exchange
   - exit non-zero on failure
2. Runner logic MUST NOT embed business SQL inline.
3. Individual signal execution MUST remain available through `scripts/gold/run_gold_sql_jobs.py --date <YYYYMMDD> --kind signal --id <signal_id>`.
4. Grouped signal execution MUST remain available through scoped
   `--entity` or `--family` selectors.
5. Runner SQL discovery MUST be deterministic and fail fast when the resolved SQL file is missing.
6. Any SQL used by shared signal orchestration helpers MUST live in `.sql` files. Python MAY render validated SQL-template placeholders and pass query parameters, but MUST NOT inline business or reference queries.

## Bulk Execution Contract

`scripts/gold/load_clickhouse_gold.py` is the canonical orchestrator.

1. MUST execute base Gold DDL from `clickhouse/gold/ddl/`.
2. MUST use the generic Gold SQL runner path for signal SQL jobs in sorted order.
3. MUST NOT require one Python runner file per new signal.
4. MUST support `--dry-run` plan mode.
5. MUST run `assert_gold_layer_contracts` after scenario and signal execution.
6. MUST require `--date`, `--month`, or `--full-history` and stage every
   selected signal target before committing any target.

## Validation and Release Gate

Before merge or release, run:

1. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --dry-run`
2. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208`
3. Verify no Gold-layer contract failures, including:
   - invalid `match_id`
   - missing signal tables
   - SQL job execution failures

Recommended focused checks:

1. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals --dry-run`
2. `python3 scripts/gold/load_clickhouse_gold.py --date 20251208 --part signals`
3. `python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --id <signal_id> --dry-run`
4. `python3 scripts/gold/run_gold_sql_jobs.py --month 202512 --kind signal --entity <entity> --dry-run`

## Git Commit Policy

A per-signal commit is mandatory. The commit MUST be created only after all 4 package parts are complete and consistent.
Each individual newly created signal MUST be committed separately; do not batch multiple new signals into one commit.
Do not create partial commits. Do not move to unrelated work before this commit exists.
For agent-driven workflows, the agent MUST create this per-signal commit immediately after the package is complete and checks pass, without waiting for a separate user reminder to commit.
If the commit cannot be created (for example permissions, conflicts, or policy constraints), work MUST pause and the blocker MUST be reported explicitly before any unrelated changes continue.

### Completion Checklist (verify before committing)

- [ ] `clickhouse/gold/dml/signals/<entity>/sig_<name>.sql` present and correct
- [ ] `clickhouse/gold/ddl/signals/{match,team,player}/create_table_{entity}_{family}_{subfamily}.sql` set updated with new table DDL
- [ ] `scripts/gold/signal/catalogs/sig_<name>.md` present and accurate
- [ ] `scripts/gold/signal/catalogs/README.md` updated with new catalog entry
- [ ] Validation gate passed (`--part signals` dry-run and full run)

### Commit Message Templates

**New signal:**

```
feat(signal): add sig_<name>

- SQL: clickhouse/gold/dml/signals/<entity>/sig_<name>.sql
- Table: gold_signals.sig_<name>
- Runner: scripts/gold/run_gold_sql_jobs.py
- Catalog: scripts/gold/signal/catalogs/sig_<name>.md
```

**Update to existing signal:**

```
fix(signal): update sig_<name> — <one-line summary of change>
```

**Rename (breaking):**

```
refactor(signal): rename sig_<old_name> → sig_<new_name>

Breaking: all downstream references to sig_<old_name> must be updated.
See `docs/DEVELOPMENT_ARCHITECTURE.md` for migration notes.

Changed:
- clickhouse/gold/dml/signals/sig_<old_name>.sql → sig_<new_name>.sql
- runners/sig_<old_name>.py → runners/sig_<new_name>.py
- gold_signals.sig_<old_name> → gold_signals.sig_<new_name>
- catalogs/sig_<old_name>.md → catalogs/sig_<new_name>.md
```

**Deprecation or deletion:**

```
chore(signal): deprecate sig_<name>

Reason: <brief explanation>
Replacement: sig_<replacement_name> (if applicable)
```

### Asset Consistency on Rename or Delete

When renaming or deleting a signal, all linked assets MUST be updated together in the same commit:

- SQL file
- runner
- table DDL
- catalog file
- catalog index

Breaking renames MUST also be documented in:

- `scripts/README.md`
- `docs/DEVELOPMENT_ARCHITECTURE.md` when boundary or command-surface behavior changes
