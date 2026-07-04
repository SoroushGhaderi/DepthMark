---
signal_id: sig_player_shooting_goals_midfield_sniper
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Midfield Sniper"
trigger: "Central-midfielder proxy scores >= 2 non-own goals from outside the box in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_midfield_sniper
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_midfield_sniper.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_midfield_sniper

## Purpose

Detects rare match-player events where a central-midfielder proxy delivers a long-range brace, surfacing high-impact midfield finishing from outside-box shooting locations.

## Tactical And Statistical Logic

- Trigger condition:
  - Outside-box goals are derived from `silver.shot` with `is_from_inside_box = 0`, `is_goal = 1`, and `is_own_goal = 0`.
  - Signal fires at `triggered_player_outside_box_goals >= 2`.
  - Central-midfielder scope follows current project role taxonomy proxy:
    - `triggered_player_usual_playing_position_id = 2` (midfielder)
    - `triggered_player_position_id != 3` (exclude forward deployment)
- Identity and orientation:
  - Player identity is preserved via `triggered_player_*`.
  - Team/opponent identity is preserved via `triggered_team_*`, `opponent_team_*`, and `triggered_side`.
- Match-context enrichment:
  - Trigger evidence comes from shot-level aggregates at `match_id + player_id + team_id`.
  - Player totals come from `silver.player_match_stat`.
  - Bilateral context is sourced from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity gate note:
  - Closest active signals are `sig_player_shooting_goals_long_range_specialist` and `sig_player_shooting_goals_xg_accumulator_midfielder`; this signal is distinct because it jointly requires (1) a midfield role proxy and (2) a strict outside-box brace threshold (`>= 2` goals).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_midfield_sniper.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_midfield_sniper`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_midfield_sniper
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across Gold signals and downstream models |
| `match_date` | Match date | Football developer: temporal slicing for scouting and trend analysis |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: scoreline context around long-range brace events |
| `away_score` | Full-time away goals | Football developer: scoreline context around long-range brace events |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for player-grain signals |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_outside_box_goals` | Minimum outside-box goal trigger threshold (`2`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `trigger_threshold_required_usual_playing_position_id` | Required usual playing position ID (`2`) | Football developer: explicit midfielder scope provenance |
| `trigger_threshold_excluded_position_id` | Excluded deployed position ID (`3`) | Football developer: explicit non-forward scope provenance |
| `triggered_player_role_group` | Triggered role-group label (`central_midfielder_proxy`) | Football developer: compact semantic role marker for segmentation |
| `triggered_player_position_id` | Match deployment position ID from personnel model | Football developer: interpretable role diagnostics at match level |
| `triggered_player_usual_playing_position_id` | Usual role bucket from personnel model | Football developer: reproducible midfielder filter field |
| `triggered_player_outside_box_goals` | Outside-box goals scored by triggered player | Football developer: core location-based trigger metric |
| `triggered_player_outside_box_shots` | Outside-box shots attempted by triggered player | Football developer: long-range attempt-volume context |
| `triggered_player_outside_box_shots_on_target` | Outside-box shots on target by triggered player | Football developer: long-range execution precision context |
| `triggered_player_outside_box_expected_goals` | Summed expected goals of outside-box shots by triggered player | Football developer: chance-quality baseline for long-range attempts |
| `triggered_player_outside_box_shot_accuracy_pct` | Outside-box shots-on-target share (%) | Football developer: precision diagnostic for long-range attempts |
| `triggered_player_outside_box_goal_conversion_pct` | Outside-box goals per outside-box shot (%) | Football developer: finishing efficiency diagnostic for long-range profile |
| `triggered_player_goal_minus_outside_box_expected_goals` | Outside-box goals minus outside-box expected goals | Football developer: direct over/under-performance indicator for long-range finishing |
| `triggered_player_total_goals` | Total goals scored by triggered player in match | Football developer: broader scoring context beyond outside-box finishes |
| `triggered_player_total_shots` | Total shots attempted by triggered player in match | Football developer: overall shooting volume context |
| `triggered_player_total_expected_goals` | Total expected goals generated by triggered player in match | Football developer: overall chance-quality context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for intensity interpretation |
| `outside_box_goals_above_threshold` | Margin above trigger threshold (`outside_box_goals - 2`) | Football developer: trigger-intensity grading beyond binary activation |
| `triggered_player_outside_box_goal_share_pct` | Share of player goals that came from outside the box (%) | Football developer: profile marker of long-range scoring dependence |
| `triggered_player_outside_box_shot_share_pct` | Share of player shots attempted from outside the box (%) | Football developer: profile marker of shot-location preference |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring context around player output |
| `opponent_goals` | Goals scored by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome edge context |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: team chance-quality baseline around trigger |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team xG minus opponent xG | Football developer: net chance-quality context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context around player event |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_shots_outside_box` | Outside-box shots by triggered side | Football developer: team-level long-range tendency context |
| `opponent_shots_outside_box` | Outside-box shots by opponent side | Football developer: bilateral long-range tendency comparator |
| `triggered_team_big_chances` | Big chances by triggered side | Football developer: high-value chance context vs long-range reliance |
| `opponent_big_chances` | Big chances by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for trigger interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent box | Football developer: penetration context linked to shot-location choices |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of finishing contribution |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: concentration of shot-volume responsibility |
| `player_share_of_team_shots_outside_box_pct` | Triggered player share of team outside-box shots (%) | Football developer: concentration of team long-range shot-taking responsibility |
