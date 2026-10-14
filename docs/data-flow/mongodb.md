# MongoDB Content Catalog

MongoDB stores signal and scenario metadata as a synchronized serving copy.
The source of truth is markdown frontmatter in Git.

## Overview

```text
catalogs/signals/*.md   (source of truth)
  → sync_signal_catalogs.py
  → MongoDB signals collection       (serving copy)
```

## Collections

| Collection | Purpose | Key Fields |
| --- | --- | --- |
| `signals` | Signal catalog metadata | `signal_id`, `entity`, `family`, `subfamily`, `grain` |
| `scenarios` | Scenario catalog metadata | `scenario_id`, `entity`, `grain` |
| `channel_templates` | Content channel templates | `template_id` |
| `content_versions` | Content version tracking | — |
| `scenario_signal_map` | Scenario-to-signal relationships | — |

## Signal Catalog Format

Each signal has a markdown catalog at `catalogs/signals/sig_<name>.md`. The
frontmatter schema, its rules, and the body sections are defined in
[`catalogs/signals/contracts/CATALOG.md`](../../catalogs/signals/contracts/CATALOG.md).
Every reader, the sync included, goes through `load_signal_catalog()` in
`src/fotmob/gold/signal_catalog.py` (ADR 0033).

## Sync Flow

### 1. Index Initialization

```bash
python3 scripts/mongodb/init_indexes.py
```

Creates unique and compound indexes on all collections.

### 2. Catalog Sync

```bash
python3 scripts/mongodb/sync_signal_catalogs.py --dry-run  # report the plan
python3 scripts/mongodb/sync_signal_catalogs.py             # apply it
```

The sync makes the `signals` collection an exact mirror of the catalog:

1. Loads and validates every catalog. Any violation writes nothing and exits 1.
2. Builds one document per signal, active and deprecated, with a
   `content_sha256` over its content.
3. Reads the stored `signal_id`, `content_sha256`, and `created_at` values.
4. Plans inserts (new signals), updates (changed hash), unchanged signals, and
   deletes (stored signals that no longer have a catalog).
5. Refuses to delete every stored document, or more than 10% of them, unless
   `--allow-mass-prune` is passed.
6. With `--dry-run`, logs the plan and stops. Otherwise it replaces changed
   documents whole, keeping `created_at`, and deletes the orphans.
   Unchanged documents are not written, so `updated_at` marks a real change.

`--dry-run` connects to MongoDB to compute the plan. To validate catalogs
without any service, run `python3 scripts/quality/check_signal_catalogs.py`.

### 3. What Gets Stored

For each signal:

- `signal_id`, `status`, `entity`, `family`, `subfamily`, `grain`, `headline`,
  `trigger`, and `row_identity` for querying
- `asset_paths` (`table`, `sql`) as authored
- `assets.table`, and the signal SQL in `assets.sql` with its path, content,
  SHA-256 hash, and byte count
- the full `frontmatter` object and the markdown body in `markdown_body`
- the project-relative catalog path in `source_path`
- `content_sha256`, `created_at`, and `updated_at`

`entity` is the signal's subject scope (`match`, `team`, or `player`) and
`status` is `active` or `deprecated`. Documents carry no runner path or runner
source.

## Repositories

`src/integrations/mongodb/` contains repository classes:
- `SignalsRepository` — mirror operations for signals: read stored hashes,
  replace whole documents, and delete orphans
- `ScenariosRepository` — CRUD for scenarios
- `TemplatesRepository` — CRUD for channel templates

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Index creation fails | Check MongoDB connectivity, re-run |
| Catalog violation | Fix the catalog (`check_signal_catalogs.py` lists every violation), re-run |
| Mass prune refused | Check `--catalog-dir` and the deletion list; pass `--allow-mass-prune` only when intended |
| Replace or delete fails | Check MongoDB connectivity, re-run; the mirror converges |
