---
signal_id: sig_player_shooting_goals_defensive_scorer
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Set-Piece Center-Back Scorer"
trigger: "Center back scores >= 1 non-own goal from a corner/set-piece sequence in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_defensive_scorer
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_defensive_scorer.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_defensive_scorer

## Purpose

Flags center backs who score from dead-ball attacking phases (corner or set-piece) to isolate defensive players providing direct scoring impact.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1`
  - `triggered_player_position_id IN (3, 4)`
  - `triggered_player_set_piece_goals >= 1`
- Set-piece events are sourced from `silver.shot` where `situation IN ('FromCorner', 'SetPiece')` and own goals are excluded for goal attribution.
- Center-back scope is derived from `silver.match_personnel` using match-specific role precedence (`starter` preferred over `substitute`).
- Bilateral match context comes from `silver.match` and `silver.period_stat` (`period = 'All'`) with symmetric triggered-team/opponent metrics.
- Similarity gate note: closest active signals are `sig_player_shooting_goals_headers_only` and `sig_player_shooting_goals_freekick_master`; this signal is distinct because it enforces center-back identity and broader set-piece sequence scoring (not only headers or direct free-kicks).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_defensive_scorer.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_defensive_scorer`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_defensive_scorer
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join and deduplication key |
| `match_date` | Match date | Football developer: supports chronological slicing |
| `home_team_id` | Home team identifier | Football developer: fixed bilateral context |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team identifier | Football developer: fixed bilateral context |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home final score | Football developer: scoreline context for trigger impact |
| `away_score` | Away final score | Football developer: scoreline context for trigger impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation |
| `triggered_player_id` | Triggered player identifier | Football developer: player-level feature key |
| `triggered_player_name` | Triggered player name | Football developer: readable attribution |
| `triggered_team_id` | Triggered player team identifier | Football developer: links player trigger to team context |
| `triggered_team_name` | Triggered player team name | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_min_set_piece_goals` | Minimum set-piece goals required by trigger (`1`) | Football developer: explicit trigger provenance |
| `triggered_player_role_group` | Role label assigned by trigger logic (`center_back`) | Football developer: semantic role grouping for downstream filters |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: center-back scope QA |
| `triggered_player_usual_playing_position_id` | Broad role bucket from personnel data | Football developer: reproducible defender gating |
| `triggered_player_goals` | Total goals by triggered player | Football developer: baseline finishing output |
| `triggered_player_set_piece_goals` | Set-piece/corner non-own goals by triggered player | Football developer: core trigger metric |
| `triggered_player_corner_goals` | Corner-situation goals by triggered player | Football developer: disaggregates corner contribution within set-piece goals |
| `triggered_player_non_set_piece_goals` | Non-set-piece non-own goals by triggered player | Football developer: separates open-play finishing from dead-ball output |
| `triggered_player_set_piece_goal_share_pct` | Share of player goals scored from set-pieces (%) | Football developer: trigger-intensity diagnostic |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: shooting volume context |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: finishing execution context |
| `triggered_player_shot_accuracy_pct` | Overall shot accuracy of triggered player (%) | Football developer: precision signal for goal output |
| `triggered_player_set_piece_shots` | Set-piece shot attempts by triggered player | Football developer: dead-ball shot volume context |
| `triggered_player_set_piece_shots_on_target` | On-target set-piece shots by triggered player | Football developer: dead-ball execution quality context |
| `triggered_player_set_piece_shot_accuracy_pct` | Set-piece shot accuracy of triggered player (%) | Football developer: dead-ball shot precision indicator |
| `triggered_player_expected_goals` | Total expected goals by triggered player | Football developer: chance-quality baseline |
| `triggered_player_set_piece_expected_goals` | Expected goals from triggered player set-piece shots | Football developer: dead-ball chance-quality footprint |
| `triggered_player_goal_minus_expected_goals` | Triggered player goals minus expected goals | Football developer: over/under-performance finishing diagnostic |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for rarity |
| `set_piece_goals_above_threshold` | Set-piece goals above trigger floor (`set_piece_goals - 1`) | Football developer: ranks trigger strength beyond binary activation |
| `triggered_team_goals` | Goals scored by triggered side | Football developer: team scoreline context |
| `opponent_goals` | Goals scored by opponent side | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome context |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: side chance-quality baseline |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality balance |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume context |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_set_piece_goals` | Set-piece/corner non-own goals by triggered side | Football developer: team dead-ball scoring environment |
| `opponent_set_piece_goals` | Set-piece/corner non-own goals by opponent side | Football developer: bilateral dead-ball scoring comparator |
| `triggered_team_set_piece_shots` | Set-piece shot attempts by triggered side | Football developer: team dead-ball shot volume context |
| `opponent_set_piece_shots` | Set-piece shot attempts by opponent side | Football developer: bilateral dead-ball shot-volume comparator |
| `triggered_team_set_piece_expected_goals` | Expected goals from triggered-side set-piece shots | Football developer: team dead-ball chance-quality context |
| `opponent_set_piece_expected_goals` | Expected goals from opponent-side set-piece shots | Football developer: bilateral dead-ball chance-quality comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: player scoring concentration within team output |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: player chance-quality share within team context |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: player shooting workload concentration |
| `player_share_of_team_set_piece_goals_pct` | Triggered player share of team set-piece goals (%) | Football developer: player dominance in team dead-ball finishing |
