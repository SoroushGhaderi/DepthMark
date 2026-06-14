---
signal_id: sig_player_discipline_cards_walking_tightrope
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Walking Tightrope"
trigger: "Player receives a yellow card before the 20th minute."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_walking_tightrope
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_walking_tightrope.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_walking_tightrope

## Purpose

Flags players who are booked early (before minute 20), indicating immediate disciplinary risk that can constrain aggression and duel behavior for the rest of the match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_first_yellow_card_minute < 20`
- Trigger source:
  - `silver.card` yellow-card events (`card_type` contains "yellow"), grouped by player and match, using earliest yellow minute as the trigger anchor.
- Identity and side logic:
  - Output keeps full player identity (`triggered_player_*`) and team/opponent identity (`triggered_team_*`, `opponent_team_*`) using canonical `triggered_side`.
- Context enrichment:
  - Player context from `silver.player_match_stat` (fouls, duels, tackles, interceptions, minutes).
  - Bilateral team context from `silver.period_stat` (`period = 'All'`) for fouls, cards, duels, tackles, interceptions, and possession.
  - Score-state context at the booking moment via `score_margin_at_first_yellow`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_walking_tightrope.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_walking_tightrope`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_walking_tightrope
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable primary join key across Gold assets |
| `match_date` | Match calendar date | Football developer: enables temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Football developer: preserves fixed bilateral match orientation |
| `home_team_name` | Home team name | Football developer: human-readable home-side context |
| `away_team_id` | Away team ID | Football developer: preserves fixed bilateral match orientation |
| `away_team_name` | Away team name | Football developer: human-readable away-side context |
| `home_score` | Home full-time score | Football developer: outcome context for disciplinary interpretation |
| `away_score` | Away full-time score | Football developer: outcome context for disciplinary interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side key for consistent downstream orientation |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution for analysis and QA |
| `triggered_team_id` | Team ID of triggered player | Football developer: ties player event to team-level tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: required bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `trigger_threshold_card_minute` | Trigger cutoff minute (`20`) | Football developer: explicit rule transparency for reproducibility |
| `triggered_player_first_yellow_card_minute` | Earliest yellow-card minute for triggered player in match | Football developer: core signal trigger metric |
| `triggered_player_yellow_cards_total` | Total yellow cards for triggered player in match | Football developer: intensity/severity context after early booking |
| `triggered_player_red_cards_total` | Total red cards for triggered player in match | Football developer: escalation outcome context after early risk |
| `triggered_player_total_cards` | Total cards (yellow + red) for triggered player | Football developer: compact discipline-load feature |
| `score_margin_at_first_yellow` | Triggered-team score margin at first yellow moment | Football developer: situational pressure context at trigger time |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: behavioral aggression context behind early booking |
| `triggered_player_duels_won` | Duels won by triggered player | Football developer: contest profile context under disciplinary constraint |
| `triggered_player_duels_lost` | Duels lost by triggered player | Football developer: pressure and risk exposure context |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: defensive engagement context after caution |
| `triggered_player_interceptions` | Interceptions by triggered player | Football developer: positional discipline and anticipation context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for interpreting raw discipline counts |
| `triggered_team_total_fouls` | Total fouls by triggered player's team | Football developer: team aggression baseline around player trigger |
| `opponent_total_fouls` | Total fouls by opponent team | Football developer: bilateral foul-load comparator |
| `triggered_team_yellow_cards` | Team yellow cards on triggered side | Football developer: team-level disciplinary pressure context |
| `opponent_yellow_cards` | Team yellow cards on opponent side | Football developer: bilateral disciplinary balance reference |
| `triggered_team_red_cards` | Team red cards on triggered side | Football developer: high-impact game-state distortion context |
| `opponent_red_cards` | Team red cards on opponent side | Football developer: bilateral dismissal context for interpretation |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: physical contest intensity around trigger |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral contest-intensity comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: defensive intervention baseline around trigger |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive pressure comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Football developer: collective defensive anticipation context |
| `opponent_interceptions` | Team interceptions by opponent side | Football developer: bilateral interception baseline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context to interpret defensive risk behavior |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control context for tactical interpretation |
