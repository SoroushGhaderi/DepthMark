# MongoDB Content Catalog

MongoDB stores signal and scenario metadata as a synchronized serving copy.
The source of truth is markdown frontmatter in Git.

## Overview

```text
scripts/gold/signal/catalogs/*.md   (source of truth)
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

Each signal has a markdown file in `scripts/gold/signal/catalogs/sig_<name>.md`:

```markdown
---
signal_id: sig_player_shooting_goals_shot_conversion_peak
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_shot_conversion_peak
---

# Signal Name

Description of what this signal detects...
```

### Required Frontmatter Keys

| Key | Type | Description |
| --- | --- | --- |
| `signal_id` | string | Unique signal identifier |
| `status` | string | `active` or `inactive` |
| `entity` | string | `match`, `player`, or `team` |
| `family` | string | Taxonomy family |
| `subfamily` | string | Taxonomy subfamily |
| `grain` | string | Row grain (`match_team`, `match_player`) |
| `row_identity` | list | Fields that identify one activation row |
| `asset_paths` | object | Related asset locations |

### `row_identity` Contract

`row_identity` defines the stable identity for one activated signal row:

- **Team-grain**: `match_id`, `triggered_side`
- **Player-grain**: `match_id`, `triggered_player_id`, `triggered_team_id`

These values are used to compute `signal_instance_id` in
`gold.signal_activations`.

## Sync Flow

### 1. Index Initialization

```bash
python3 scripts/mongodb/init_indexes.py
```

Creates unique and compound indexes on all collections.

### 2. Catalog Sync

```bash
python3 scripts/mongodb/sync_signal_catalogs.py --dry-run  # preview
python3 scripts/mongodb/sync_signal_catalogs.py             # execute
```

Sync process:
1. Discovers all `scripts/gold/signal/catalogs/*.md` files.
2. Parses YAML frontmatter and markdown body.
3. Validates required frontmatter keys.
4. Validates `asset_paths.table` uses `gold_signals.<signal_id>` namespace.
5. Reads embedded SQL and runner source files.
6. Computes SHA-256 hashes for integrity.
7. Upserts into MongoDB with content hashing.

### 3. What Gets Stored

For each signal catalog:
- Flattened metadata fields for fast querying
- Full `frontmatter` object for full-fidelity reuse
- Full markdown body in `markdown_body`
- Embedded SQL in `assets.sql.content` with SHA-256 hash
- Embedded runner source in `assets.runner.content` with SHA-256 hash
- Relative source file path in `source_path`

## Repositories

`src/integrations/mongodb/` contains repository classes:
- `SignalsRepository` — CRUD with upsert semantics for signals
- `ScenariosRepository` — CRUD for scenarios
- `TemplatesRepository` — CRUD for channel templates

## Failure Modes

| Failure | Recovery |
| --- | ---|
| Index creation fails | Check MongoDB connectivity, re-run |
| Frontmatter validation fails | Fix markdown catalog, re-run |
| Upsert fails | Check MongoDB connectivity, re-run |
| Hash mismatch | Source file changed, re-sync |
