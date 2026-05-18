---
signal_id: sig_player_shooting_goals_freekick_master
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Free-Kick Master"
trigger: "Player scores >= 1 direct free-kick goal in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold.sig_player_shooting_goals_freekick_master
  sql: clickhouse/gold/signal/sig_player_shooting_goals_freekick_master.sql
  runner: scripts/gold/signal/runners/sig_player_shooting_goals_freekick_master.py
---
# sig_player_shooting_goals_freekick_master

## Purpose

Detects match-player performances where a player scores directly from a free kick, surfacing elite dead-ball finishers with bilateral match context.

## Tactical And Statistical Logic

- Trigger condition:
  - Direct free-kick events are modeled from `silver.shot` with `situation = 'FreeKick'`, `is_own_goal = 0`, and no assister (`assist_player_id` is null/0) as a direct-delivery proxy.
  - Signal fires when `triggered_player_direct_free_kick_goals >= 1` in a finished match.
- Identity and orientation:
  - Player identity is preserved via `triggered_player_*`.
  - Team/opponent identity is preserved via `triggered_team_*`, `opponent_team_*`, and `triggered_side`.
- Match-context enrichment:
  - Player direct free-kick evidence is aggregated from `silver.shot` at `match_id + player_id + team_id` grain.
  - Player total shooting context comes from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity note:
  - Closest active signals are `sig_player_shooting_goals_long_range_specialist` (location-driven outside-box scoring) and `sig_player_possession_passing_deadball_creator` (indirect free-kick chance creation). This signal is distinct because it isolates direct free-kick goal conversion by the shooter.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_freekick_master.sql`
- Runner: `scripts/gold/signal/runners/sig_player_shooting_goals_freekick_master.py`
- Target table: `gold.sig_player_shooting_goals_freekick_master`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_shooting_goals_freekick_master.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across Gold signals and downstream models |
| `match_date` | Match date | Football developer: temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Football developer: fixed fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: scoreline context around trigger |
| `away_score` | Full-time away goals | Football developer: scoreline context around trigger |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player rows |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_direct_free_kick_goals` | Minimum direct free-kick goal trigger threshold (`1`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `triggered_player_direct_free_kick_goals` | Direct free-kick goals scored by triggered player | Football developer: core trigger evidence |
| `triggered_player_direct_free_kick_shots` | Direct free-kick shots taken by triggered player | Football developer: set-piece attempt volume context |
| `triggered_player_direct_free_kick_shots_on_target` | Direct free-kick shots on target by triggered player | Football developer: dead-ball execution precision context |
| `triggered_player_direct_free_kick_expected_goals` | Summed expected goals of triggered player's direct free-kick shots | Football developer: chance-quality baseline for direct deliveries |
| `triggered_player_direct_free_kick_shot_accuracy_pct` | Direct free-kick shots-on-target share (%) | Football developer: direct set-piece precision diagnostic |
| `triggered_player_direct_free_kick_goal_conversion_pct` | Direct free-kick goals per direct free-kick shot (%) | Football developer: dead-ball finishing efficiency diagnostic |
| `triggered_player_goal_minus_direct_free_kick_expected_goals` | Direct free-kick goals minus direct free-kick expected goals | Football developer: over/under-performance signal for direct deliveries |
| `triggered_player_total_goals` | Total goals scored by triggered player in match | Football developer: scoring context beyond free kicks |
| `triggered_player_total_shots` | Total shots attempted by triggered player in match | Football developer: overall shooting volume context |
| `triggered_player_total_expected_goals` | Total expected goals by triggered player in match | Football developer: overall chance-quality context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for output interpretation |
| `direct_free_kick_goals_above_threshold` | Margin above trigger threshold (`direct_free_kick_goals - 1`) | Football developer: trigger-intensity grading beyond binary activation |
| `triggered_player_direct_free_kick_goal_share_pct` | Share of player goals that came from direct free kicks (%) | Football developer: direct free-kick scoring dependence marker |
| `triggered_player_direct_free_kick_shot_share_pct` | Share of player shots that were direct free kicks (%) | Football developer: dead-ball shot-profile marker |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring context around player trigger |
| `opponent_goals` | Goals scored by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome edge context |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: team chance-quality baseline around trigger |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team xG minus opponent xG | Football developer: net chance-quality context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context around trigger |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_direct_free_kick_goals` | Direct free-kick goals scored by triggered side | Football developer: team-level direct set-piece scoring context |
| `opponent_direct_free_kick_goals` | Direct free-kick goals scored by opponent side | Football developer: bilateral direct set-piece scoring comparator |
| `triggered_team_direct_free_kick_shots` | Direct free-kick shots by triggered side | Football developer: team direct set-piece volume context |
| `opponent_direct_free_kick_shots` | Direct free-kick shots by opponent side | Football developer: bilateral direct set-piece volume comparator |
| `triggered_team_direct_free_kick_expected_goals` | Direct free-kick expected goals by triggered side | Football developer: team direct set-piece quality baseline |
| `opponent_direct_free_kick_expected_goals` | Direct free-kick expected goals by opponent side | Football developer: bilateral direct set-piece quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for trigger interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent box | Football developer: penetration context around direct free-kick reliance |
| `opponent_touches_opposition_box` | Opponent touches in triggered side's box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of finishing contribution |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: concentration of shooting-volume responsibility |
| `player_share_of_team_direct_free_kick_goals_pct` | Triggered player share of team direct free-kick goals (%) | Football developer: concentration of direct dead-ball goal contribution |
