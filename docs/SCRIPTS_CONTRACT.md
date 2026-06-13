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

1. Layer entry points live under `scripts/bronze`, `scripts/silver`,
   `scripts/gold`, `scripts/orchestration`, `scripts/quality`, or
   `scripts/mongodb`.
2. Root-level layer scripts are not part of the command surface.
3. Root-level utility scripts are allowed for project-wide operations such as
   `ensure_directories.py`, `health_check.py`, and `refresh_turnstile.py`.
4. Do not add new root-level layer scripts.
5. Any command-surface change must update `DEVELOPMENT_ARCHITECTURE.md` and
   `../scripts/README.md`.

## Handwriting Rules

1. Prefer explicit, descriptive names over short or ambiguous names.
2. Keep one style across modules for naming, function shape, error handling, and
   logging.
3. Make control flow obvious and linear.
4. Separate orchestration from logic: CLI parsing, execution, reporting, and
   shared helpers should be isolated.
5. Avoid clever one-liners in operational code.

## Script And Application-Service Boundary

1. Scripts are the documented operational command surface.
2. Scripts own CLI parsing, `.env` loading, import-path bootstrap, help text,
   backward-compatible arguments, dry-run flags, and process exit codes.
3. Reusable workflow coordination may live in stable layer-specific application
   services under `src/`.
4. Application services may coordinate SQL discovery and execution, client
   setup, contract checks, validation, alerts, reports, and deterministic
   summaries.
5. Application services must not contain reusable Silver or Gold analytical
   logic; those transformations belong in ClickHouse SQL.
6. Refactors that introduce application services must preserve the script entry
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
2. Avoid duplicate `sys.path` insertions; guard before inserting.
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

## Data Safety

1. Do not change schema semantics unintentionally.
2. Do not rename contract fields without coordinated updates.
3. Intended behavior changes must be documented in the relevant PR or commit
   notes.
4. Destructive actions must support preview or clear confirmation where practical.

## Formatting and Quality Gates

1. Formatting baseline: `black`.
2. Import sorting baseline: `isort`.
3. Hygiene baseline: `pyflakes` clean.
4. Avoid wide mechanical rewrites unless requested.

## Update Policy

1. When asked to follow the scripts contract, this file is authoritative.
2. When asked to update the contract, edit this file first, then apply code
   changes against it.
3. If code and contract conflict, resolve the conflict explicitly by updating one
   or both with clear intent.
