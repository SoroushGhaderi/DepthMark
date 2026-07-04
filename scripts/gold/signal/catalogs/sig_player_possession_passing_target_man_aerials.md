---
signal_id: sig_player_possession_passing_target_man_aerials
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Target Man Aerial Dominance"
trigger: "forward wins >= 10 aerial duels (proxy for long-ball possession)"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_target_man_aerials
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_target_man_aerials.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_target_man_aerials

## Purpose

Triggers when a forward wins at least 10 aerial duels, flagging target-man behavior as a proxy for direct long-ball possession routes.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 3`
  - `triggered_player_aerial_duels_won >= 10`
- Forward classification uses `silver.match_personnel.usual_playing_position_id = 3`, with match-specific `position_id` preserved for role diagnostics.
- Trigger uses player-level duel totals from `silver.player_match_stat`, with success rate and attempts retained to separate pure volume from efficiency.
- Signal includes bilateral team/opponent aerial, long-ball, passing, and possession context from `silver.period_stat` (`period = 'All'`) to explain whether the trigger reflects a broader direct-play plan.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_target_man_aerials.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_target_man_aerials`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_target_man_aerials
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and player feature sets |
| `match_date` | Calendar match date | Football developer: supports temporal feature windows and trend analysis |
| `home_team_id` | Home team ID | Football developer: preserves bilateral team context for the triggered player |
| `home_team_name` | Home team name | Football developer: human-readable context in analyst outputs |
| `away_team_id` | Away team ID | Football developer: preserves bilateral team context for the triggered player |
| `away_team_name` | Away team name | Football developer: human-readable context in analyst outputs |
| `home_score` | Home goals at full time | Football developer: result context for interpreting direct-play usage |
| `away_score` | Away goals at full time | Football developer: result context for interpreting direct-play usage |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: readable attribution for storytelling and QA |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player-level event to team tactical profile |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: matchup-aware context for feature engineering |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution for analysts |
| `triggered_player_position_id` | Match-specific lineup position ID | Football developer: role diagnostics for central vs wide forward usage |
| `triggered_player_usual_playing_position_id` | Broad position bucket used for forward filtering | Football developer: documents the role gate used in trigger logic |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for high-volume aerial output |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered player | Football developer: core trigger metric (`>= 10`) indicating target-man dominance |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered player | Football developer: trigger denominator to interpret sustainability of aerial wins |
| `triggered_player_aerial_duel_success_pct` | Triggered player aerial duel success percentage | Football developer: separates raw duel volume from duel efficiency |
| `triggered_player_total_passes` | Total passes by triggered player | Football developer: possession-chain involvement context beyond aerial phases |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: technical execution context when used as long-ball outlet |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: quality context for link-up play around aerial contests |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement baseline around target-man role |
| `triggered_player_touches_opposition_box` | Triggered player touches inside opposition box | Football developer: territorial payoff context of aerial-route usage |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: finishing-volume context after aerial platform wins |
| `triggered_player_expected_goals` | Triggered player xG | Football developer: chance-quality context linked to direct-play service |
| `triggered_team_aerials_won` | Aerial duels won by triggered player's team | Football developer: team-level aerial control baseline around the player trigger |
| `opponent_aerials_won` | Aerial duels won by opponent team | Football developer: bilateral comparator for aerial control balance |
| `triggered_team_aerial_attempts` | Aerial duel attempts by triggered player's team | Football developer: team aerial-volume context for direct-play intensity |
| `opponent_aerial_attempts` | Aerial duel attempts by opponent team | Football developer: bilateral volume comparator for matchup style |
| `triggered_team_aerial_success_pct` | Triggered team aerial duel win percentage | Football developer: indicates whether player trigger aligns with team aerial superiority |
| `opponent_aerial_success_pct` | Opponent aerial duel win percentage | Football developer: bilateral efficiency comparator for tactical interpretation |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered player's team | Football developer: validates target-man trigger as long-ball-possession proxy |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Football developer: bilateral directness comparator for game-state interpretation |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered player's team | Football developer: team execution quality of direct routes feeding the forward |
| `opponent_accurate_long_balls` | Accurate long balls by opponent team | Football developer: bilateral quality comparator for direct-play execution |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy percentage | Football developer: contextualizes whether aerial domination came with precise delivery |
| `opponent_long_ball_accuracy_pct` | Opponent long-ball accuracy percentage | Football developer: bilateral passing-quality benchmark for direct routes |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: denominator context for route-mix interpretation |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral possession-volume comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: circulating quality baseline around direct-play behavior |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting long-ball reliance |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `player_share_of_team_aerials_won_pct` | Triggered player aerial wins as % of team aerial wins | Football developer: quantifies concentration of aerial dominance in one target man |
| `player_share_of_team_long_ball_attempts_pct` | Triggered player aerial attempts as % of team long-ball attempts | Football developer: measures how strongly team directness is funneled to this forward |
