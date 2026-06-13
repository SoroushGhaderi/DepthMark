---
signal_id: sig_player_creativity_playmaking_deadball_wizard
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Deadball Wizard"
trigger: "Player records >= 2 assists from corners in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_deadball_wizard
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_deadball_wizard.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_deadball_wizard

## Purpose

Detect player-level dead-ball playmaking performances where one player directly assists at least
two goals from corner deliveries in a single finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_corner_assists >= 2`
  - `match_finished = 1`
- Corner assists are computed from `silver.shot` rows where:
  - `situation = 'FromCorner'`
  - `assist_player_id = triggered_player_id`
  - `is_goal = 1`
  - `is_own_goal = 0`
- Additional corner-delivery context is retained via:
  - `triggered_player_corner_chances_created`
  - `triggered_player_corner_assisted_shots_on_target`
  - `triggered_player_corner_assisted_shot_expected_goals`
- Bilateral team/opponent context uses `silver.period_stat` (`period = 'All'`) plus corner shot/goal
  aggregation from `silver.shot`.
- Similarity gate note:
  - `sig_player_creativity_playmaking_assist_brace`: same assist floor (`>= 2`) but not
    corner-specific.
  - `sig_player_possession_passing_corner_specialist`: corner-originated chance creation signal
    (`> 1` created chances), but not restricted to actual assists/goals.
  - `sig_player_possession_passing_deadball_creator`: dead-ball creation from indirect free kicks
    using big-chance proxy, not corner-assist outcomes.
  - Coexistence rationale: this signal is outcome-specific to corner assists and sits under
    creativity/playmaking taxonomy for direct dead-ball chance-conversion attribution.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_deadball_wizard.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_deadball_wizard`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_deadball_wizard
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match-level join and deduplication key |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context for assist impact |
| `away_score` | Away full-time goals | Match outcome context for assist impact |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable bilateral comparator |
| `trigger_threshold_min_corner_assists` | Trigger floor (`2`) | Explicit threshold provenance and QA guard |
| `triggered_player_corner_assists` | Non-own goals assisted by triggered player from corner situations | Core trigger metric |
| `triggered_player_corner_assists_above_threshold` | Corner assists above trigger floor (`value - 2`) | Trigger severity beyond activation |
| `triggered_player_corner_chances_created` | Total corner-assisted shots created by triggered player | Volume context around corner-assist output |
| `triggered_player_corner_assisted_shots_on_target` | On-target corner-assisted shots created by triggered player | Delivery quality context |
| `triggered_player_corner_assisted_shot_expected_goals` | Sum of xG from triggered player's corner-assisted shots | Chance-quality context for created corner shots |
| `triggered_player_assists` | Total assists by triggered player (all situations) | Overall assist baseline versus corner-only trigger |
| `triggered_player_expected_assists` | Triggered player expected assists (all situations) | Chance-quality context for broader playmaking profile |
| `triggered_player_assist_minus_expected_assists` | Assists minus expected assists | Outcome-versus-expected conversion context |
| `triggered_player_chances_created` | Triggered player total chances created | All-phase creation-volume context |
| `triggered_player_assists_per_chance_created_pct` | Assist conversion of created chances (%) | Efficiency context for final-pass output |
| `triggered_player_cross_attempts` | Triggered player cross attempts | Delivery workload context around corner specialization |
| `triggered_player_accurate_crosses` | Triggered player accurate crosses | Delivery execution baseline |
| `triggered_player_cross_success_rate_pct` | Triggered player cross accuracy (%) | Delivery efficiency context |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Progression context around dead-ball impact |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Advanced-territory involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution context |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Passing reliability context |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for threshold interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_corner_goals` | Non-own goals scored by triggered team from corner situations | Team corner-conversion baseline around player trigger |
| `opponent_corner_goals` | Non-own goals scored by opponent from corner situations | Bilateral corner-conversion comparator |
| `triggered_team_corner_shots` | Total corner shots by triggered team | Team corner-shot environment context |
| `opponent_corner_shots` | Total corner shots by opponent team | Bilateral corner-shot comparator |
| `triggered_team_corners` | Corners won by triggered team | Set-piece opportunity baseline |
| `opponent_corners` | Corners won by opponent team | Bilateral set-piece opportunity comparator |
| `triggered_team_cross_attempts` | Cross attempts by triggered team | Team wide-service workload context |
| `opponent_cross_attempts` | Cross attempts by opponent team | Bilateral wide-service comparator |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team | Team delivery-quality baseline |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Bilateral delivery-quality comparator |
| `triggered_team_cross_accuracy_pct` | Triggered team cross accuracy (%) | Team wide-delivery efficiency context |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Bilateral wide-delivery efficiency comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team passing execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing execution comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `player_share_of_team_corner_goals_assisted_pct` | Triggered player corner assists as % of triggered team corner goals | Concentration of corner-goal creation ownership |
| `player_share_of_team_goals_assisted_pct` | Triggered player total assists as % of team goals | Broader direct-output contribution context |
| `player_share_of_team_crosses_pct` | Triggered player cross attempts as % of team cross attempts | Delivery role centrality context beyond set pieces |
