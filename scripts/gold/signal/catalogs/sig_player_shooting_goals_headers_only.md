---
signal_id: sig_player_shooting_goals_headers_only
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Headers-Only Brace"
trigger: "Player scores >= 2 goals and all scored goals are headers in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_headers_only
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_headers_only.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_headers_only

## Purpose

Flags players who score two or more goals in a match where every scored goal is a header, surfacing extreme aerial finishing concentration.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_goals >= 2`
  - `triggered_player_header_goals = triggered_player_goals`
  - `triggered_player_non_header_goals = 0`
- Header-goal attribution is sourced from `silver.shot` using `is_goal = 1` and `shot_type` text matching `header` (case-insensitive), excluding own goals.
- Player shooting totals and bilateral match context come from `silver.player_match_stat`, `silver.match`, and `silver.period_stat` (`period = 'All'`).
- Team and opponent aerial context (`*_header_goals`, `*_header_shots`, `*_header_expected_goals`) is derived symmetrically from shot-level data.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_headers_only.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_headers_only`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_headers_only
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join and deduplication key |
| `match_date` | Match date | Football developer: supports time-series slicing |
| `home_team_id` | Home team identifier | Football developer: bilateral match context anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team identifier | Football developer: bilateral match context anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home full-time score | Football developer: scoreline context for interpreting trigger impact |
| `away_score` | Away full-time score | Football developer: scoreline context for interpreting trigger impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player identifier | Football developer: player-level identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team identifier of triggered player | Football developer: links player signal to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: matchup context key |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_min_goals` | Minimum goals required by trigger (`2`) | Football developer: explicit trigger auditability |
| `triggered_player_goals` | Total goals scored by triggered player | Football developer: primary trigger metric |
| `triggered_player_header_goals` | Header goals scored by triggered player | Football developer: verifies aerial-only scoring condition |
| `triggered_player_non_header_goals` | Non-header goals scored by triggered player | Football developer: enforces strict exclusion logic |
| `triggered_player_header_goal_share_pct` | Share of player goals that were headers (%) | Football developer: captures aerial concentration severity |
| `triggered_player_total_shots` | Total shots attempted by triggered player | Football developer: volume context behind goal output |
| `triggered_player_shots_on_target` | Player shots on target | Football developer: shooting precision context |
| `triggered_player_shot_accuracy_pct` | Player shots-on-target share (%) | Football developer: finishing execution indicator |
| `triggered_player_header_shots` | Player header shot attempts | Football developer: aerial attempt volume context |
| `triggered_player_header_shots_on_target` | Player header shots on target | Football developer: aerial shot quality proxy |
| `triggered_player_header_shot_accuracy_pct` | Header shots-on-target share for triggered player (%) | Football developer: header execution quality indicator |
| `triggered_player_expected_goals` | Total expected goals of triggered player | Football developer: chance-quality baseline for output comparison |
| `triggered_player_header_expected_goals` | Expected goals from triggered player header shots | Football developer: aerial chance-quality footprint |
| `triggered_player_goal_minus_expected_goals` | Player goals minus player expected goals | Football developer: finishing overperformance diagnostic |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for event rarity |
| `goals_above_threshold` | Goal margin above trigger floor (`goals - 2`) | Football developer: ranks trigger intensity beyond binary activation |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring context around player output |
| `opponent_goals` | Goals scored by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome and game-state context |
| `triggered_team_expected_goals` | Expected goals for triggered side | Football developer: team-level chance creation baseline |
| `opponent_expected_goals` | Expected goals for opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: side-level chance-quality balance |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shooting execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_header_goals` | Header goals scored by triggered side | Football developer: team aerial-finishing environment around trigger |
| `opponent_header_goals` | Header goals scored by opponent side | Football developer: bilateral aerial-finishing comparator |
| `triggered_team_header_shots` | Header shots attempted by triggered side | Football developer: team aerial-attack volume context |
| `opponent_header_shots` | Header shots attempted by opponent side | Football developer: bilateral aerial volume comparator |
| `triggered_team_header_expected_goals` | Expected goals generated from triggered-side headers | Football developer: team aerial chance-quality context |
| `opponent_header_expected_goals` | Expected goals generated from opponent headers | Football developer: bilateral aerial chance-quality comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: scoring concentration within team output |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: individual chance-quality share |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: individual shooting responsibility |
| `player_share_of_team_header_goals_pct` | Triggered player share of team header goals (%) | Football developer: dominance within team aerial finishing |
