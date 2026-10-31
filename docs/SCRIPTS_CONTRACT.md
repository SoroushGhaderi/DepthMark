# Scripts Contract

This file is the source of truth for script behavior, style, CLI semantics, and
stability rules in DepthMark. The canonical command list lives in
`DEVELOPMENT_ARCHITECTURE.md`; the script inventory lives in `../scripts/README.md`.

## Scope

1. This contract applies to Python files under `scripts/`.
2. It also applies to script-oriented helper modules under `src/` and
   application services behind script entry points.
3. Refactors must preserve behavior unless a functional change is explicitly
   requested.
4. If a file already follows this contract and is clean, leave it alone.

## Command Surface Rules

1. Layer and source entry points live under `scripts/bronze`, `scripts/silver`,
   `scripts/gold`, `scripts/oddspedia`, `scripts/orchestration`,
   `scripts/quality`, or `scripts/mongodb`.
2. Root-level layer scripts are not part of the command surface.
3. Root-level utility scripts are allowed for project-wide operations such as
   `ensure_directories.py`, `health_check.py`, and `refresh_turnstile.py`.
4. Do not add new root-level layer scripts.
5. Any command-surface change must update `src/cli.py`, its registry contract
   tests, `DEVELOPMENT_ARCHITECTURE.md`, and `../scripts/README.md` when those
   surfaces are affected.

## Handwriting Rules

1. Prefer explicit, descriptive names over short or ambiguous names.
2. Keep one style across modules for naming, function shape, error handling, and
   logging.
3. Make control flow obvious and linear.
4. Separate orchestration from logic: CLI parsing, execution, reporting, and
   shared helpers should be isolated.
5. Avoid clever one-liners in operational code.

## Script And Application-Service Boundary

1. Scripts are the documented operational command surface, and each one is a
   thin shim: it imports one `main(argv) -> int` from a command module under
   `src/<domain>/commands/` and calls it. Deprecated paths call
   `src.common.deprecation.run_deprecated_script()` around the same function.
2. Command modules own CLI parsing, `.env` loading, help text,
   backward-compatible arguments, dry-run flags, and exit codes. `depthmark`
   imports the same `main` and runs it in-process.
3. Reusable workflow coordination lives in stable source-specific or
   warehouse modules under `src/`, which command modules call.
4. These workflow modules may coordinate SQL discovery and execution, client
   setup, contract checks, validation, alerts, reports, and deterministic
   summaries.
5. Workflow modules must not contain reusable Silver or Gold analytical
   logic; those transformations belong in ClickHouse SQL.
6. Refactors that introduce workflow modules must preserve the script entry
   point and CLI behavior unless a breaking change is explicitly requested and
   documented.

## Naming Conventions

1. Functions and variables use `snake_case`.
2. Constants use `UPPER_SNAKE_CASE` and live near the file top.
3. Classes use `PascalCase`.
4. Private helpers start with `_`.
5. Boolean names should read as booleans, using prefixes such as `is_`, `has_`,
   `should_`, or `can_`.
6. Use suffixes intentionally:
   - `_path` for `Path` values
   - `_sql` for SQL strings
   - `_count` for integer counts
   - `_seconds` for durations

### Operational Script Names

1. Canonical source-owned workflow scripts use
   `<verb>_<source>[_<layer-or-entity>].py`.
2. The source token is mandatory even when the containing directory already
   implies ownership. Examples include `scrape_fotmob.py`,
   `load_fotmob_bronze.py`, `discover_oddspedia_events.py`, and
   `resolve_oddspedia_events.py`.
3. Use a business or warehouse verb (`scrape`, `discover`, `prioritize`,
   `load`, `resolve`, `run`, `setup`, `status`, or `report`) rather than naming
   a destination technology when the intent is broader than that technology.
4. Add the layer or entity suffix only when needed to distinguish the owned
   output. Do not invent matching phases for another source merely to make the
   command lists visually identical.
5. Shared source-neutral utilities may omit a source token. Examples include
   `health_check.py`, `report_scraping.py`, `check_data_quality.py`,
   `optimize_clickhouse.py`, and `recreate_clickhouse_tables.py`.
6. The package CLI uses the same grammar with hyphens, for example
   `load-fotmob-bronze` and `resolve-oddspedia-events`. `src/cli.py` is the
   authoritative package command registry.
7. A replaced filename may remain as a compatibility adapter. It must delegate
   to the same implementation, preserve arguments and exit codes, print a
   deprecation warning to stderr, and name the canonical replacement.
8. New documentation, orchestration, generated operator guidance, and tests
   must use canonical names. Compatibility names are documented only in a
   migration section or historical context.

### Scraping Reporting Interface

1. `scripts/report_scraping.py` is the only canonical scraping-report entry
   point. It is source-neutral because one operational report owns the shared
   interface; `--source fotmob`, `--source oddspedia`, and `--source all`
   select explicit source adapters rather than a generic provider framework.
2. Every source-date report exposes the same summary contract: discovered,
   completed, failed, skipped, remaining, progress, artifact count, storage
   size, and Bronze-admission readiness. Source-specific inventory, priority,
   audit, log, and storage evidence remains nested under its source report.
3. Reporting is observational. Without an explicit `--output`, it must not
   create directories, locks, manifests, metrics, logs, source artifacts, or
   warehouse rows. An explicit output path may create only that report and its
   parent directories.
4. `summary`, `markdown`, and `json` render the same report bundle. Report
   generation exits `0` when it successfully observes an incomplete run;
   `--fail-on-attention` opts automation into exit `1` for incomplete, error,
   or not-started states.
5. The former Oddspedia status/report scripts and package commands are
   compatibility adapters to this interface. They must not retain independent
   reporting logic or appear in current runbooks.

## Function Design

1. Functions should do one clear job.
2. Prefer small helpers with focused responsibilities.
3. Prefer pure helpers when practical and isolate I/O boundaries.
4. Use early returns for guard clauses.
5. Avoid hidden side effects.
6. Keep argument lists minimal and meaningful.
7. Remove dead code, unused variables, and unused imports.

## Constants and Configuration

1. Avoid unexplained magic numbers and strings in logic.
2. Extract repeated literals to named constants.
3. Keep related constants grouped and clearly named.
4. Use domain-safe defaults.
5. Expose operational configuration through CLI arguments, environment variables,
   or config modules.

## Imports and Module Layout

1. Import order is standard library, third-party, then local modules.
2. Never modify `sys.path`. The editable install (`uv sync` or
   `pip install -e .`) and `PYTHONPATH=/app` in the image make `src`, `scripts`,
   and `config` importable; resolve checkout paths from
   `src.common.paths.PROJECT_ROOT`.
3. Keep module-level setup minimal and deterministic.
4. Avoid heavyweight runtime work at import time.
5. Scripts that depend on local credentials/config should load `.env` files from
   `project_root/.env` and `project_root.parent/.env` with `override=False`
   before runtime setup.

## Typing and Docstrings

1. Public functions require type hints.
2. CLI `main()` and parser helpers require explicit return types.
3. Write concise docstrings for non-obvious behavior and arguments.
4. Keep docstrings aligned with actual behavior.

## Logging and Error Handling

1. Use consistent logging with clear action/result context.
2. Use `get_logger(__name__)` for module loggers.
3. Log outcomes at boundaries: start, success, failure, and summary.
4. Never swallow exceptions silently.
5. Catch specific exceptions where possible.
6. Preserve original error details when re-raising or reporting.

## CLI Semantics

1. Exit code `0` means success; non-zero means failure.
2. Argument validation errors should return clear messages.
3. `--dry-run` must not mutate state.
4. Script summaries should be deterministic and comparable across runs.
5. Backward compatibility is the default for script arguments and outputs.

### Warehouse Execution Scopes

1. Silver, Gold, Gold SQL-job, and activation entry points require exactly one
   of `--date YYYYMMDD`, `--month YYYYMM`, or `--full-history`.
2. `--single-date` remains a backward-compatible alias for `--date`.
3. A scoped run replaces only rows whose match-date lineage is inside its
   output scope. `inserted_at` is never scope lineage.
4. Jobs may read all available history to preserve contextual calculations
   while replacing only the selected output scope.
5. Scoped derived loads stage and validate all selected outputs before commits.
   Date runs reconstruct the containing month with `REPLACE PARTITION`; month
   runs replace that month; full-history runs use staged table exchange.
6. Dry-run performs no ClickHouse writes, subprocess execution, notifications,
   or other state mutation. It reports context, output scope, selected tables,
   exclusions, and planned operations.

### FotMob Gold SQL Jobs And Signal Catalogs

1. `scripts/gold/run_fotmob_gold_jobs.py` is the only selected-job runner for
   Gold scenario and signal SQL (ADR 0001, ADR 0009, ADR 0033). It loads SQL
   from `.sql` files, builds a `ScopedSqlJob` per selected job, stages every job
   through `ScopedReplacementBatch` before committing any, and exits non-zero on
   failure. Python may render validated SQL placeholders but must not inline
   business or reference queries.
2. One signal runs with `--id <signal_id>`; batches use `--kind`, or the
   separate `--entity` or `--family` (`family` or `family_subfamily`)
   selectors. Selecting a deprecated or uncatalogued signal exits `2`.
3. `scripts/gold/load_fotmob_gold.py` is the bulk orchestrator. It runs the
   selected scenario and signal jobs in id order, then
   `scripts/gold/build_fotmob_signal_activations.py` with the same scope, then
   `assert_gold_layer_contracts`. It never runs DDL; setup is separate
   (ADR 0026). It supports a `--dry-run` plan.
4. Signal catalog frontmatter is read only through `load_signal_catalog()` in
   `src/fotmob/gold/signal_catalog.py`. Every consumer (the runner, the bulk
   loader, the activation builder, `check_data_quality.py`, and
   `sync_signal_catalogs.py`) loads the catalog before it writes anything and
   exits `1` without writing when it reports any violation. Do not parse catalog
   frontmatter anywhere else.
5. New work must not add per-signal or per-scenario Python runner files.

### Oddspedia Source Pipeline

1. Oddspedia event intake is independent of the FotMob orchestration command.
   Its supported phases are `discover_oddspedia_events.py`,
   `prioritize_oddspedia_events.py`, `scrape_oddspedia_matches.py`, and
   `run_oddspedia_pipeline.py`; Bronze loading and resolution are separate
   `load_oddspedia_bronze.py` and `resolve_oddspedia_events.py` operations.
2. Discovery is fail-closed. An inventory is accepted only after complete
   target-date pagination and date validation, or an explicitly verified empty
   result. Accepted inventories must include a checksum. Missing or stale
   checksums cause discovery refresh and Bronze admission failure until the
   refreshed evidence is available.
3. Mutating date-scoped Oddspedia commands serialize through
   `data/oddspedia/locks/<sport>_<YYYYMMDD>.lock`. Dry-run and read-only report
   operations must not create or acquire that lock.
4. `load_oddspedia_bronze.py` stages all three source fact tables, validates
   date-scoped counts and payload audits, replaces the target partition only
   after the staged batch is ready, and records `staging`, `published`, or
   `failed` in `oddspedia_bronze.load_status`. Silver resolution may consume
   only a `published` batch.
5. Month-scoped Oddspedia commands continue processing independent dates but
   must exit non-zero when any date is missing, unaccepted, or failed. A
   successful month command means every requested date passed its phase gate.
6. Event intake, scraping reports, Bronze loading, and resolution accept an
   inclusive `--start-date/--end-date` scope. Both arguments are required
   together. A current-month event-intake selector stops at the machine-local
   current date; an explicit scope containing a future date fails.
7. Persisted source JSON is validated at an explicit artifact seam and written
   without model serialization or structural normalization. Manifest
   read-modify-write preserves unknown compatible fields. Do not migrate or
   rewrite existing artifacts merely to adopt a newer runtime contract.

### Quality Entry Points

1. `scripts/quality/check_data_quality.py` is the canonical warehouse quality
   entry point and is always read-only.
2. It supports `--date`, `--month`, and `--full-history`; omission defaults to
   full history for compatibility with the prior reconciliation command.
3. Duplicate checks may span Bronze, Silver, and Gold. Cross-layer
   reconciliation is limited to Bronze and Silver and must never infer Gold
   parity.
4. Strict mode exits `1` only for logical duplicate identities in the `FINAL`
   view or completed Bronze-to-Silver reconciliation mismatches. Extra physical
   `ReplacingMergeTree` versions are non-failing diagnostics. Tables with
   undefined identities are reported separately. Argument errors exit `2`;
   operational errors exit non-zero.
5. `scripts/quality/check_bronze_to_silver_reconciliation.py` remains a
   backward-compatible alias with its existing `--checks`, `--sample-limit`,
   and `--strict` arguments.
6. `scripts/quality/check_signal_catalogs.py` validates the signal catalog
   against its SQL and DDL without ClickHouse, MongoDB, or `.env`. It exits `1`
   on any violation or a stale index; `--write-index` regenerates the index
   table instead of failing on it and writes nothing else.

## Data Safety

1. Do not change schema semantics unintentionally.
2. Do not rename contract fields without coordinated updates.
3. Intended behavior changes must be documented in the relevant PR or commit
   notes.
4. Destructive actions must support preview or clear confirmation where practical.

## Formatting and Quality Gates

1. Formatting and import sorting: `ruff format` and `ruff check` (configured in
   `pyproject.toml`), enforced by pre-commit and CI.
2. Logging style: `scripts/quality/check_logging_style.py` passes.
3. Avoid wide mechanical rewrites unless requested; list any that land in
   `.git-blame-ignore-revs`.

## Update Policy

1. When asked to follow the scripts contract, this file is authoritative.
2. When asked to update the contract, edit this file first, then apply code
   changes against it.
3. If code and contract conflict, resolve the conflict explicitly by updating one
   or both with clear intent.
