# Signal SQL Contract

Rules for signal DML (`clickhouse/gold/dml/signals/<entity>/<signal_id>.sql`)
and for analyst queries written before a signal is productionized. Tags are
defined in [`README.md`](README.md). SQL owns the analytical logic (ADR 0007).

## Principles

1. Reproducibility: deterministic logic, explicit filters, stable naming.
2. Interpretability: the triggered behavior and its context are easy to explain.
3. Analytical fairness: triggered-side and opponent metrics are symmetric unless
   intentionally net or delta.
4. Operational simplicity: readable SQL and predictable execution.

## Production DML

1. Every signal DML file MUST have a catalog, and the catalog's
   `asset_paths.sql` MUST point to it. **[catalog]**
2. The DML MUST be one `INSERT ... SELECT` into the signal's table whose column
   list equals the DDL columns minus `signal_instance_id` and `inserted_at`,
   which ClickHouse fills from their defaults. **[test]**
   `test_signal_dml_insert_columns_match_ddl_and_catalog_identity`
3. The insert column list MUST include every `row_identity` column. **[test]**
   same test.
4. New DML SHOULD insert into `gold_signals.<signal_id>`. Existing DML inserts
   into the legacy `gold.<signal_id>` name, which the runner rewrites to the
   target database; migrate it when a file is touched.
5. DML MUST NOT contain DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`).
6. Source tables MUST be schema-qualified (`silver.*`, `bronze.*`).
7. Final rows MUST have a valid `match_id` (`NOT NULL`, `> 0`). **[runtime]**
8. Queries joining `silver.match` MUST filter `m.match_finished = 1`, unless the
   signal explicitly models unfinished matches.
9. Null-sensitive arithmetic and aggregation SHOULD use `coalesce(col, 0)` or
   equivalent explicit handling. Nullable keys in `GROUP BY` or `ORDER BY`
   SHOULD be normalized (for example `assumeNotNull()` when safe).
10. Header comments MUST follow the `INSERT` column list: `-- Signal: <signal_id>`
    and `-- Intent: ...`. `-- Trigger: ...` SHOULD state the threshold or rule;
    if omitted, the trigger MUST be obvious from the predicates.
11. Comment style MUST be consistent within a file and SHOULD be consistent
    across the family.
12. Query shape SHOULD stay simple; avoid unnecessary CTE layers.
13. `FINAL` on source tables SHOULD appear only when correctness needs it, with
    a short comment saying why.
14. Enrichment MUST be domain-relevant, not filler:
    - Passing: accuracy differential plus volume
    - Pressing: PPDA or press-success metrics
    - Shooting: xG, shot volume, on-target rate
    - Defending: defensive action counts
15. Tactical context metrics MUST come in `triggered_team_*` / `opponent_*`
    pairs. Unpaired fields are allowed only for explicit net or delta outputs.
16. The side-orientation column is `triggered_side`.
17. If both teams can satisfy a trigger but only one row is emitted, the SQL
    MUST define deterministic precedence (for example home first) and expose a
    bilateral flag such as `both_sides_triggered`.
18. Player signals MUST output `triggered_player_id`, `triggered_player_name`,
    `triggered_team_id`, `triggered_team_name`, `triggered_side`, and, unless
    the signal is explicitly not opponent-oriented, `opponent_team_id` and
    `opponent_team_name`.
19. Signal value columns MUST be descriptive; avoid a boolean or value column
    named exactly like the signal when a richer metric exists.

## Column Naming

1. Output columns MUST be `snake_case` with full football words: `accuracy`,
   not `acc`; `opposition` for pitch zones (`opposition_half`,
   `opposition_box`); `opponent` only for the opposing team or player.
2. Percentage and rate columns MUST end with `_pct`, for example
   `triggered_team_pass_accuracy_pct`.
3. Delta columns MUST name the unit when it matters: `pass_accuracy_delta_pct`
   for percentage points, `xg_delta`.
4. Period-specific columns MUST spell out the period before the unit suffix:
   `triggered_team_pass_accuracy_first_half_pct`,
   `opponent_opposition_half_passes_second_half`.
5. Triggered-side team metrics MUST use `triggered_team_*`, opponent metrics
   `opponent_*`, and player metrics `triggered_player_*` with
   `triggered_team_*` for the player's team context.
6. Side-oriented non-triggered metrics MUST put the side first:
   `home_pass_accuracy_pct`, `away_opposition_half_pass_pct`.
7. Count columns SHOULD use explicit action nouns: `*_attempts`, `accurate_*`,
   `successful_*`.
8. New columns MUST NOT introduce abbreviations unless canonical in football
   analytics (`xg`, `ppda`).

## Analyst Queries

An analyst query explores a signal before it ships.

1. It MUST be a single `SELECT`: no `INSERT` and no DDL.
2. It SHOULD use the production comment style.
3. It MUST output `match_id`, `match_date`, `home_team_id`, `home_team_name`,
   `away_team_id`, `away_team_name`, `home_score`, `away_score`, the triggered
   entity identifier, and the measured signal value. Player signals add
   `triggered_player_id`, `triggered_player_name`, `triggered_team_id`, and
   `triggered_team_name`.
4. Enrichment SHOULD stay tactically relevant and symmetric.
5. A markdown schema table with exactly `Column Name`, `Description`, `Reason`
   MUST follow the SQL and cover every selected column.
