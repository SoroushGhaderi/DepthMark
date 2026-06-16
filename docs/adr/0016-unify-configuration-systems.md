# ADR 0016: Unify Configuration Systems

## Status

Accepted

## Context

DepthMark had two parallel, independent configuration systems that coexisted in
`config/`:

1. **YAML-based `FotMobConfig`** (older): Loads from `config.yaml` with manual
   `os.getenv()` overrides. Uses plain Python `@dataclass` classes. Has import-time
   side effects (`load_dotenv()` at module import). Used by Bronze scraper scripts.

2. **Pydantic-settings `Settings`** (newer): Loads from `.env` via `pydantic-settings`.
   Instantiates as a module-level singleton. Has import-time side effects (`Settings()`
   at module import). Used by ClickHouse/SQL pipeline scripts.

**Problems:**
- Duplicated settings (logging, proxy, metrics) with no reconciliation
- Callers must know which system owns which setting
- Import-time side effects (`load_dotenv()`, singleton instantiation) create fragility
- Two different override mechanisms (manual `os.getenv()` vs pydantic-settings)
- Cannot unit test with injected config — both systems are hardwired

## Decision

Consolidate into a single `Settings` class (pydantic-settings) as the single source
of truth for all configuration:

1. **Nested FotMob models**: `FotMobSettings` contains pydantic sub-models
   (`FotMobApiSettings`, `FotMobRequestSettings`, etc.) loaded from `config.yaml`
   with env-var overrides.

2. **Env-var mapping**: `FOTMOB_*` env vars map to nested fields
   (e.g., `FOTMOB_X_MAS_TOKEN` → `fotmob.api.x_mas_token`).

3. **Backward-compatible adapter**: `FotMobConfig` delegates to `Settings.fotmob`,
   preserving all existing attribute access patterns and `@property` accessors.

4. **No import-time side effects**: `load_dotenv()` removed from all modules.
   `get_settings()` is a lazy singleton that loads `.env` on first call.

5. **Explicit initialization**: Scripts call `get_settings()` in `main()`, not at
   module import.

## Consequences

- **Single source of truth**: All configuration lives in `Settings`. One place to
  find any setting.
- **Clean testability**: Tests can inject a `Settings` instance via `FotMobConfig(settings=...)`.
- **No import-time side effects**: Scripts are safe to import without triggering
  env loading or directory creation.
- **Backward compatibility**: All existing `FotMobConfig` consumers work unchanged.
  The adapter pattern means scraper code does not need to change.
- **Reduced code**: Removed ~300 lines of manual YAML loading and env override code.

## Follow-up

- The `config/base.py` dataclass types (`StorageConfig`, `LoggingConfig`, etc.) are
  retained as legacy aliases but should be phased out in favor of the pydantic models.
- `load_dotenv()` calls have been removed from all scripts. If a script needs env
  loading without `get_settings()`, it should call `get_settings()` explicitly.
