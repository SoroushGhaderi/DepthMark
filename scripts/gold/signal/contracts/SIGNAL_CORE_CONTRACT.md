# Gold Signal Core Contract (Codex High)

This contract defines the high-value, creative part of Gold signal authoring:

1. Writing production signal SQL logic
2. Writing analyst-facing exploratory SQL
3. Producing the signal catalog markdown

This document is intended for deep tactical/analytical reasoning work where design quality matters most.

> Normative language (`MUST`/`SHOULD`/`MAY`) is defined in `SIGNAL_CONTRACT.md` § Normative Language.

## Scope

This contract applies to:

- `clickhouse/gold/signal/sig_*.sql`
- `scripts/gold/signal/catalogs/sig_*.md`
- `scripts/gold/signal/catalogs/README.md`

## Core Principles

1. Reproducibility: deterministic logic, explicit filters, stable naming.
2. Interpretability: triggered behavior and context are easy to explain.
3. Analytical fairness: triggered-side and opponent metrics are symmetric unless intentionally net/delta.
4. Operational simplicity: readable SQL and predictable execution.

## Signal Similarity Gate

When proposing a new signal, similarity against existing active signals MUST be checked first.

1. If trigger logic, core metric predicates, and tactical intent are materially close to an existing signal, the author MUST pause implementation and explicitly ask the owner to choose one path:
   - keep the previous signal as-is, or
   - proceed with the new logic (with clear replacement or coexistence rationale).
2. The proposal MUST cite the closest existing signal IDs and summarize overlap/differences before requesting the decision.
3. No production package changes SHOULD be finalized until that decision is provided.

### Token-Efficient Similarity Workflow

When signal inventory is large, similarity checks MUST follow this workflow to avoid loading unnecessary context:

1. Stage 1 (index-only scan):
   - Read only `scripts/gold/signal/catalogs/README.md` table rows.
   - Filter to `status=active` plus exact `entity`, `family`, and `subfamily` match.
2. Stage 2 (narrow candidate set):
   - Keep at most 8 candidates.
   - If more than 8 remain, prefer exact `grain` match first, then lexical proximity of `signal_id`.
3. Stage 3 (partial catalog read):
   - For shortlisted candidates, read only frontmatter, `Purpose`, and `Trigger` sections.
   - Do NOT read full schema tables or full SQL during initial similarity judgement.
4. Stage 4 (decision note):
   - Produce a compact overlap note containing: `signal_id`, overlap reason, key difference.
   - Keep similarity evidence concise (target <= 250 words total before implementation starts).
5. Stage 5 (deep read only when needed):
   - Open full catalog/SQL only for the top 2-3 most similar candidates, or when conflict risk is high.

## Naming and Consistency

See `SIGNAL_EXECUTION_CONTRACT.md` § Naming and Consistency Contract for the canonical naming rules.
All assets produced under this contract MUST conform to those rules.

## Column Naming Contract

1. Output column names MUST be `snake_case`.
2. Output columns MUST use full football/domain words:
   - Use `accuracy`, not `acc`.
   - Use `opposition` for pitch zones (`opposition_half`, `opposition_box`), not `opp`.
   - Use `opponent` only for the opposing team/entity, not as a pitch-zone abbreviation.
3. Percentage and rate columns MUST end with `_pct`.
   - Correct: `triggered_team_pass_accuracy_pct`
   - Incorrect: `triggered_team_pass_accuracy`, `triggered_team_pass_acc_pct`
4. Delta columns MUST include the measured unit when unit-sensitive:
   - Correct: `pass_accuracy_delta_pct`
   - Correct: `xg_delta`
   - Incorrect: `pass_accuracy_delta` when the value is a percentage-point delta
5. Period-specific columns MUST spell out the period before the unit suffix:
   - Correct: `triggered_team_pass_accuracy_first_half_pct`
   - Correct: `opponent_opposition_half_passes_second_half`
   - Incorrect: `triggered_team_pass_acc_fh`, `opponent_opp_half_passes_sh`
6. Triggered-side team metrics MUST use `triggered_team_*`.
7. Opponent team metrics MUST use `opponent_*`.
8. Player-triggered metrics MUST use `triggered_player_*` for player values and `triggered_team_*` for the player's team context.
9. Side-oriented non-triggered metrics MUST put the side first:
   - Correct: `home_pass_accuracy_pct`, `away_opposition_half_pass_pct`
   - Incorrect: `pass_accuracy_home_pct`, `home_opp_half_pass_pct`
10. Count columns SHOULD use explicit football action nouns:
    - Attempts: `*_attempts`
    - Accurate completions: `accurate_*`
    - Successful actions: `successful_*`
11. New output columns MUST NOT introduce abbreviations unless already canonical in football analytics (`xg`, `ppda`).

## Production SQL Contract

File: `clickhouse/gold/signal/sig_<name>.sql`

1. SQL MUST target `gold_signals.sig_<name>` for signal output tables.
   Legacy `INSERT INTO gold.sig_<name>` files are translated by the generic
   runner during migration, but new signal work SHOULD use the canonical
   `gold_signals` namespace.
2. SQL MUST NOT include DDL (`CREATE`, `ALTER`, `DROP`).
3. All source tables MUST be schema-qualified (`bronze.*`, `silver.*`, `gold.*`).
4. `match_id` MUST be present in final rows and MUST be valid (`NOT NULL`, `> 0`).
5. Queries joining `silver.match` MUST filter `m.match_finished = 1`, unless a signal explicitly models non-finished states.
6. Null-sensitive arithmetic and aggregations SHOULD use `coalesce(col, 0)` (or equivalent explicit handling).
7. Nullable keys in `GROUP BY` or `ORDER BY` SHOULD be normalized (for example `assumeNotNull()` when safe).
8. Signal value columns MUST be descriptive. Avoid redundant boolean/value columns named exactly like the signal when a richer metric exists.
9. Header comments MUST appear immediately after the `INSERT` column list:
   - `-- Signal: sig_<name>`
   - `-- Intent: ...`
10. `-- Trigger: ...` SHOULD be present and explicit when a threshold/rule exists. If omitted, trigger logic MUST still be obvious in SQL predicates.
11. Clause comment style MUST be consistent within each file and SHOULD be consistent across the signal family.
12. Query shape SHOULD remain simple and consistent across signals. Avoid unnecessary CTE layers and indirection.
13. `FINAL` on source tables SHOULD be used only when correctness requires it; if used, add a short comment explaining why the performance trade-off is justified.
14. Enrichment MUST be domain-relevant, not generic filler:
    - Passing: accuracy differential plus volume
    - Pressing: PPDA or press-success metrics
    - Shooting: xG, shot volume, on-target rate
    - Defending: defensive action counts
15. Tactical context metrics MUST be symmetric as `triggered_team_*` and `opponent_*` pairs. Unpaired fields are allowed only for explicit net/delta outputs.
16. Canonical side-orientation field is `triggered_side`. Legacy `triggered_team_side` is tolerated for existing tables, but new signals MUST use `triggered_side`.
17. If both teams can satisfy a trigger in one match but only one row is emitted, SQL MUST define deterministic precedence (for example home-priority) and expose an explicit bilateral flag (for example `both_sides_triggered`).
18. Player-triggered signals MUST store both player identity and team context in final output rows:
    - `triggered_player_id` and `triggered_player_name`
    - `triggered_team_id` and `triggered_team_name`
    - `triggered_side` plus opponent team identifiers (`opponent_team_id`, `opponent_team_name`) unless explicitly non-opponent-oriented.

## Analyst Query Contract (Ad-hoc SQL Before Production)

When generating analyst-facing exploratory SQL:

1. Output MUST be a single `SELECT` query (no `INSERT`, no DDL).
2. SQL SHOULD use the same comment style as production signal SQL.
3. Output MUST include minimum match context:
   - `match_id`, `match_date`
   - `home_team_id`, `home_team_name`
   - `away_team_id`, `away_team_name`
   - `home_score`, `away_score`
   - triggered entity identifier (team or player)
   - measured signal value
   - for player-triggered signals: include both player identifiers (`triggered_player_id`, `triggered_player_name`) and triggered team identifiers (`triggered_team_id`, `triggered_team_name`)
4. Enrichment SHOULD remain tactically relevant and symmetric.
5. A markdown schema table MUST follow SQL with exactly these headers:
   - `Column Name`
   - `Description`
   - `Reason`
6. The schema table MUST cover every selected column without omission.

## Catalog Contract

File: `scripts/gold/signal/catalogs/sig_<name>.md`

Each catalog MUST include:

1. Metadata block
2. Purpose
3. Tactical and statistical logic
4. Technical asset references (convention-based unless overridden)
5. Example execution command
6. Output schema table with:
   - `Column Name`
   - `Description`
   - `Reason`

Additional rules:

1. Catalogs MUST begin with a YAML metadata block before the heading:

   ```yaml
   ---
   signal_id: sig_<name>
   status: active
   entity: team
   family: possession
   subfamily: passing
   grain: match_team
   headline: "Human-readable signal headline"
   trigger: "human-readable trigger expression"
   row_identity:
     - match_id
     - triggered_side
   asset_paths:
     table: gold_signals.sig_<name>
     sql: clickhouse/gold/signal/sig_<name>.sql
     runner: scripts/gold/signal/runners/sig_<name>.py
   ---
   ```

2. Required metadata fields are:
   - `signal_id`
   - `status` (`active`, `experimental`, or `deprecated`)
   - `entity` (`team` or `player`)
   - `family`
   - `subfamily`
   - `grain`
   - `headline`
   - `trigger`
   - `row_identity`
   - `asset_paths.table`
   - `asset_paths.sql`
   - `asset_paths.runner`
3. `grain` MUST describe row grain. Accepted values:
   - `match_team`
   - `match_player`
4. `row_identity` MUST list stable deduplication identity for final rows:
   - Team-triggered signals SHOULD use `match_id` and `triggered_side`.
   - Player-triggered signals SHOULD use `match_id`, `triggered_player_id`, and `triggered_team_id`.
   - Changing `row_identity` for an existing signal changes activation identity
     and MUST be treated as an explicit migration decision.
5. Asset paths SHOULD follow convention and MUST match actual package files:
   - table: `gold_signals.<signal_id>`
   - SQL path: `clickhouse/gold/signal/<signal_id>.sql`
   - runner path: `scripts/gold/run_sql_job.py`
6. Catalogs MUST reference SQL by path and MUST NOT embed full SQL bodies.
7. `Reason` entries MUST explain analytical value (diagnostics, tactical interpretation, feature engineering, QA, or downstream modeling impact).
8. `catalogs/README.md` MUST include every active `sig_<name>.md` in a structured table with these headers:
   - `Signal ID`
   - `Entity`
   - `Family`
   - `Subfamily`
   - `Grain`
   - `Status`
   - `Catalog`
9. For player-triggered signals, catalog output schemas MUST document both `triggered_player_*` and `triggered_team_*` identity fields.
