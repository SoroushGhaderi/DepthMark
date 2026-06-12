---
signal_id: sig_player_shooting_goals_impossible_angle
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Impossible Angle Finisher"
trigger: "Player scores >= 1 non-own goal from a shot with expected_goals < 0.02 in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_impossible_angle
  sql: clickhouse/gold/signal/sig_player_shooting_goals_impossible_angle.sql
  runner: scripts/gold/signal/runners/sig_player_shooting_goals_impossible_angle.py
---
# sig_player_shooting_goals_impossible_angle

## Purpose

Detects match-player events where a player scores from an ultra-low-probability shot (`expected_goals < 0.02`), surfacing "impossible-angle"-like finishes through a strict shot-quality threshold.

## Tactical And Statistical Logic

- Trigger condition:
  - Shot-level scope is `expected_goals < 0.02` in `silver.shot`.
  - Goal events require `is_goal = 1` and exclude own goals (`is_own_goal = 0`).
  - Signal fires when `triggered_player_low_expected_goals_goals >= 1` in the same finished match.
- Identity and orientation:
  - Player identity is preserved via `triggered_player_*`.
  - Team/opponent context is preserved via `triggered_team_*`, `opponent_*`, and `triggered_side`.
- Match-context enrichment:
  - Trigger evidence is aggregated from `silver.shot` at `match_id + player_id + team_id` grain.
  - Player shooting totals come from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity gate note:
  - Closest active shooting-goals signals are `sig_player_shooting_goals_long_range_specialist` and `sig_player_shooting_goals_clutch_equalizer`; this signal is distinct because it is probability-threshold-based (`expected_goals < 0.02`) rather than location-only (outside box) or timing/state-change based (late equalizer).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_impossible_angle.sql`
- Runner: `scripts/gold/signal/runners/sig_player_shooting_goals_impossible_angle.py`
- Target table: `gold_signals.sig_player_shooting_goals_impossible_angle`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_shooting_goals_impossible_angle.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deduplication |
| `match_date` | Match date | Football developer: temporal slicing for scouting and trend analysis |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: scoreline context around low-probability finishing |
| `away_score` | Full-time away goals | Football developer: scoreline context around low-probability finishing |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player outputs |
| `triggered_player_id` | Triggered player identifier | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team identifier of triggered player | Football developer: binds player event to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_max_shot_expected_goals` | Maximum per-shot expected-goals trigger threshold (`0.02`) | Football developer: explicit trigger provenance and reproducibility |
| `triggered_player_low_expected_goals_goals` | Goals scored by triggered player from shots with `expected_goals < 0.02` | Football developer: core trigger evidence for impossible-angle-like finishing |
| `triggered_player_low_expected_goals_shots` | Total shots by triggered player with `expected_goals < 0.02` | Football developer: low-probability attempt volume context |
| `triggered_player_low_expected_goals_shots_on_target` | On-target shots by triggered player with `expected_goals < 0.02` | Football developer: execution quality context within low-probability attempts |
| `triggered_player_low_expected_goals_sum_expected_goals` | Sum of expected goals for triggered player's `expected_goals < 0.02` shots | Football developer: cumulative chance-quality baseline for low-probability attempts |
| `triggered_player_low_expected_goals_min_goal_expected_goals` | Lowest expected-goals value among triggered player's qualifying goals | Football developer: extremity marker for most difficult converted chance |
| `triggered_player_low_expected_goals_avg_goal_expected_goals` | Average expected-goals value across triggered player's qualifying goals | Football developer: average difficulty of converted low-probability goals |
| `triggered_player_low_expected_goals_shot_accuracy_pct` | On-target rate for triggered player's `expected_goals < 0.02` shots (%) | Football developer: precision diagnostic in impossible-angle-like attempts |
| `triggered_player_low_expected_goals_goal_conversion_pct` | Goal conversion rate for triggered player's `expected_goals < 0.02` shots (%) | Football developer: finishing efficiency on ultra-low-probability attempts |
| `triggered_player_goal_minus_low_expected_goals_sum_expected_goals` | Low-expected-goals goals minus low-expected-goals summed xG | Football developer: overperformance signal for extreme finishing outcomes |
| `triggered_player_total_goals` | Total goals by triggered player in match | Football developer: full-match scoring context beyond the trigger subset |
| `triggered_player_total_shots` | Total shots by triggered player in match | Football developer: full-match shooting-volume context |
| `triggered_player_total_expected_goals` | Total expected goals by triggered player in match | Football developer: full-match chance-quality context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting event intensity |
| `low_expected_goals_goals_above_threshold` | Margin above trigger threshold (`low_expected_goals_goals - 1`) | Football developer: severity ranking beyond binary activation |
| `triggered_player_low_expected_goals_goal_share_pct` | Share of triggered player's goals from `expected_goals < 0.02` shots (%) | Football developer: profile marker of reliance on difficult finishes |
| `triggered_player_low_expected_goals_shot_share_pct` | Share of triggered player's total shots with `expected_goals < 0.02` (%) | Football developer: profile marker of extremely low-probability shot selection |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team score context around the trigger |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral score comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome edge context |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: side-level chance-quality baseline |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality framing |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances by triggered side | Football developer: high-quality chance context around low-probability conversion events |
| `opponent_big_chances` | Big chances by opponent side | Football developer: bilateral high-quality chance comparator |
| `triggered_team_possession_pct` | Possession percentage by triggered side | Football developer: control-profile context for trigger interpretation |
| `opponent_possession_pct` | Possession percentage by opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Touches in opposition box by triggered side | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Touches in opposition box by opponent side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of finishing contribution |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality burden |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: concentration of shot-taking volume |
| `player_share_of_team_shots_on_target_pct` | Triggered player share of team shots on target (%) | Football developer: concentration of on-target execution |
