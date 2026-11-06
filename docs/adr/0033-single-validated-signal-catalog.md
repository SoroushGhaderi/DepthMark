# ADR 0033: Read Signal Catalogs Through One Validated Module

## Status

Accepted. Amends [ADR 0008](0008-author-signal-catalogs-in-markdown.md):
markdown frontmatter remains the source of truth, but its location, its
`entity` meaning, its `status` vocabulary, its `asset_paths` keys, and the way
every consumer reads it change.

## Context

ADR 0008 made catalog frontmatter canonical but left every consumer to read it:

- The activation builder parsed frontmatter, took `entity`, `family`, and
  `subfamily` from the `signal_id`, and logged a warning when the frontmatter
  disagreed. The 93 `sig_match_*` catalogs declared `entity: team`, so every run
  logged 93 warnings and `gold.signal_activations` recorded `match`.
- The MongoDB sync parsed the same frontmatter with a copy of the same function,
  stored the frontmatter `entity` (`team`), skipped invalid files while counting
  them, and merged documents with `$set`, so deleted signals and removed fields
  stayed in MongoDB and `updated_at` changed on every sync.
- The strict quality gate parsed catalogs a third way and silently skipped any
  catalog it could not parse, removing that signal from duplicate-identity
  checks.
- The Gold runner found signal SQL by glob, so `status` did not decide what ran.
- Every catalog named the same generic runner in `asset_paths.runner`, and the
  sync embedded that runner's source into all 344 MongoDB documents.
- The signal contracts disagreed with each other and with the code: `entity` was
  `team|player` in one and `match|team|player` in another; `status` was
  `active|experimental|deprecated` in one and `active|inactive` in another; the
  contracts still described dropped per-signal runners, destructive DDL, and
  legacy namespaces.
- Catalogs, contracts, and the scenario catalog lived under `scripts/` although
  none of them is a script.

The catalog, DML, and DDL sets agreed (344 each), and every DDL
`signal_instance_id` default hashed exactly the catalog `row_identity`. The
review's proposed check against DDL `ORDER BY` would have failed on 132 signals
without indicating a defect, because `ORDER BY` is a physical sort key.

## Decision

1. **One reader.** `src/fotmob/gold/signal_catalog.py` is the only code that
   reads signal catalogs. `load_signal_catalog()` returns an immutable
   `SignalCatalog` of `SignalDefinition` records or raises one
   `SignalCatalogError` listing every violation. It performs no warehouse or
   MongoDB I/O. The activation builder, MongoDB sync, strict quality gate, Gold
   job list, and catalog check all consume it.
2. **Whole-catalog fail-closed.** Any invalid catalog stops every consumer
   before it acts: no Gold jobs, no activation rebuild, no MongoDB write, a
   failing strict quality check, and a failing pytest contract test. A signal is
   never dropped individually.
3. **Signal Entity is the subject scope.** `entity` is `match`, `team`, or
   `player` and must equal the second segment of
   `sig_<entity>_<family>_<subfamily>_<name>`; `family` and `subfamily` must
   equal their segments. The row grain lives only in `grain`: `match_team` for
   match and team signals, `match_player` for player signals.
4. **Signal Status is `active` or `deprecated`.** Active signals run in Gold,
   appear in activations, and sync to MongoDB. Deprecated signals do not run in
   Gold (selecting one by id is an error) and are excluded from activations, but
   still sync to MongoDB with their status and keep their table and identity
   checks. Deprecation applies to scopes rebuilt afterwards; a full-history
   activation rebuild applies it everywhere.
5. **The identity chain is the identity contract.** Every `row_identity` column
   exists in the signal's DDL table; the DDL `signal_instance_id` default hashes
   the identity scheme version, the `signal_id`, and `row_identity` in catalog
   order with `match_id` prepended when absent; the activation builder uses the
   same `identity_fields`; and DDL `ORDER BY` ends with `signal_instance_id`.
   `ORDER BY` leading columns are not checked against `row_identity`.
6. **Assets are per signal.** `asset_paths` holds exactly `table`
   (`gold_signals.<signal_id>`) and `sql`
   (`clickhouse/gold/dml/signals/<entity>/<signal_id>.sql`, which must exist).
   `asset_paths.runner` is removed; execution through the generic runner is
   documented once. Every signal DML file must have a catalog.
7. **MongoDB mirrors the catalog.** The sync replaces whole documents (keeping
   `created_at`), writes only when `content_sha256` changes, and deletes
   documents whose `signal_id` has no catalog. It refuses to prune when the
   catalog is empty or when the deletion share exceeds a threshold, unless
   `--allow-mass-prune` is passed. `--dry-run` reports inserts, updates,
   unchanged documents, and deletions without writing.
8. **The index is generated.** `scripts/quality/check_signal_catalogs.py`
   validates the catalog without services and, with `--write-index`, renders the
   index table in `catalogs/signals/README.md` between markers, including
   deprecated signals. The contract test fails when the committed index is
   stale.
9. **Content leaves `scripts/`.** Signal catalogs, their index, and the signal
   contracts move to `catalogs/signals/`; the scenario catalog and contract move
   to `catalogs/scenarios/`.
10. **Contracts are organized by artifact and lifecycle.**
    `catalogs/signals/contracts/` holds `README.md`, `AUTHORING.md`,
    `CATALOG.md`, `SQL.md`, and `TABLE.md`. Each mechanically checked rule names
    the check that enforces it; judgment rules remain normative prose. Runner
    and bulk-execution rules belong to `docs/SCRIPTS_CONTRACT.md` and the Gold
    data-flow docs.
11. **Source-owned Gold scripts follow ADR 0024.** The activation builder is
    `scripts/gold/build_fotmob_signal_activations.py`
    (`build-fotmob-signal-activations`) and the generic runner is
    `scripts/gold/run_fotmob_gold_jobs.py` (`run-fotmob-gold-jobs`). The old
    paths remain warning-emitting compatibility adapters. Catalog and quality
    utilities keep responsibility-based names: `sync_signal_catalogs.py` and
    `check_signal_catalogs.py` (`check-signal-catalogs`).

## Consequences

Benefits:

- A signal has one validated description everywhere; ClickHouse and MongoDB
  agree on its entity and status.
- A malformed catalog fails before merge instead of silently removing a signal
  from quality checks or MongoDB.
- `status` controls execution, so retiring a signal is a one-line catalog edit.
- MongoDB can be rebuilt from Git and holds no stale or duplicated content.
- Authors run one service-free command to validate a signal package and
  regenerate the index.

Costs:

- One malformed catalog blocks every Gold run until fixed.
- MongoDB documents change: 93 `entity` values become `match`, `source_path`
  values move to `catalogs/signals/`, and `asset_paths.runner` and
  `assets.runner` disappear. External readers of those fields must adapt.
- Deprecation leaves earlier activation scopes unchanged until they are rebuilt.
- Every catalog file changes once (location, `entity` for match signals, and the
  removed runner line).

## Follow-up Constraints

- Changing `row_identity` remains an activation identity migration (ADR 0006).
- New consumers of catalog metadata use `load_signal_catalog()`; parsing
  frontmatter elsewhere is a contract violation.
- Moving the activation builder and sync logic behind `main(argv)` in `src/` is
  the separate thin-entry-point change (architecture review candidate 3).
