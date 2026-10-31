# Signal Catalog Contract

A catalog is one markdown file, `catalogs/signals/<signal_id>.md`, whose YAML
frontmatter is the source of truth for the signal's metadata (ADR 0008) and
whose body explains the signal to people. Tags are defined in
[`README.md`](README.md).

## Frontmatter

```yaml
---
signal_id: sig_match_creativity_playmaking_big_chance_fest
status: active
entity: match
family: creativity
subfamily: playmaking
grain: match_team
headline: "Big Chance Fest"
trigger: "Combined big chances in the match exceed 8 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_big_chance_fest
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_big_chance_fest.sql
---
```

1. The frontmatter MUST open the file and hold exactly these keys:
   `signal_id`, `status`, `entity`, `family`, `subfamily`, `grain`, `headline`,
   `trigger`, `row_identity`, `asset_paths`. A missing or undeclared key is a
   violation. **[catalog]**
2. `signal_id` MUST equal the file name and follow
   `sig_<entity>_<family>_<subfamily>_<name>`, lowercase `snake_case`, where
   `entity` is `match`, `team`, or `player` and `family` and `subfamily` are
   single words. **[catalog]**
3. `entity` is the Signal Entity, the subject scope. It MUST equal the id's
   entity segment. A match signal emitted once per side is `entity: match`
   with `grain: match_team`. **[catalog]**
4. `family` and `subfamily` MUST equal the id's segments. **[catalog]**
5. `status` MUST be `active` or `deprecated` (Signal Status). **[catalog]**
   - `active`: runs in Gold, appears in activations, syncs to MongoDB.
   - `deprecated`: does not run in Gold and is excluded from activations;
     still syncs to MongoDB and keeps its table and identity checks.
6. `grain` MUST be `match_player` for player signals and `match_team` for
   match and team signals. **[catalog]**
7. `headline` and `trigger` MUST be non-empty strings. **[catalog]** They
   SHOULD read as a short human title and an exact, human-readable rule.
8. `row_identity` MUST be a non-empty list of distinct column names. **[catalog]**
   - Team-grain signals SHOULD use `match_id`, `triggered_side`.
   - Player-grain signals SHOULD use `match_id`, `triggered_player_id`,
     `triggered_team_id`.
   - Its place in the identity chain is defined in [`TABLE.md`](TABLE.md).
   - Changing `row_identity` of an existing signal changes its Signal
     Activation IDs and MUST be treated as an identity migration (ADR 0006).
9. `asset_paths` MUST hold exactly `table` and `sql`. **[catalog]**
   - `table` MUST be `gold_signals.<signal_id>`.
   - `sql` MUST be `clickhouse/gold/dml/signals/<entity>/<signal_id>.sql`, and
     the file MUST exist.
   - There is no runner path: every signal runs through
     `scripts/gold/run_fotmob_gold_jobs.py`.

## Body

The body follows the frontmatter, starts with `# <signal_id>`, and MUST contain:

1. **Purpose**: what the signal detects and why it matters.
2. **Tactical and statistical logic**: the trigger condition, its sources,
   match scope, side orientation, and how it differs from its closest
   siblings (the similarity note from [`AUTHORING.md`](AUTHORING.md)).
3. **Technical asset references**: the SQL path, target table, and runner.
4. **Example execution command**, for example
   `python3 scripts/gold/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id <signal_id>`.
5. **Output schema** table with exactly the headers `Column Name`,
   `Description`, `Reason`, covering every output column.

Additional rules:

1. The body MUST reference SQL by path and MUST NOT embed the full SQL.
2. `Reason` entries MUST explain analytical value: diagnostics, tactical
   interpretation, feature engineering, QA, or downstream modeling impact.
3. Player-signal schemas MUST document both the `triggered_player_*` and the
   `triggered_team_*` identity columns.

## Index

`catalogs/signals/README.md` holds the index table between
`<!-- signal-index:start -->` and `<!-- signal-index:end -->`. It is generated,
lists every catalog including deprecated ones, and MUST match the catalog.
**[catalog]** via `check_signal_catalogs.py`, **[test]**
`test_repository_signal_index_is_current`. Regenerate it with
`python3 scripts/quality/check_signal_catalogs.py --write-index`; never edit the
table by hand.
