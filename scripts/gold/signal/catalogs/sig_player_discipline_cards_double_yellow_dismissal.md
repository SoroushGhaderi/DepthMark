---
signal_id: sig_player_discipline_cards_double_yellow_dismissal
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Double Yellow Dismissal"
trigger: "Player receives two yellow cards and is dismissed in the same match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_double_yellow_dismissal
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_double_yellow_dismissal.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_double_yellow_dismissal

## Purpose

Flags players dismissed via second-yellow dynamics, preserving trigger timing and bilateral match context for discipline-impact analysis.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_yellow_cards_match >= 2`
  - a second-yellow dismissal event is detected in `silver.card` (`card_type`/`description` patterns such as "second yellow", "yellowred", or yellow+red compound labels).
- The signal emits one row per triggered player per match.
- Trigger timing keeps both the first yellow minute and second-yellow dismissal minute.
- Output stores full player identity (`triggered_player_*`) and team identity (`triggered_team_*`) at player grain.
- Bilateral team context (fouls, cards, possession, and passing) is added from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` fields.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_double_yellow_dismissal.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_double_yellow_dismissal`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_double_yellow_dismissal
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for downstream joins |
| `match_date` | Match date | Football developer: supports temporal analysis windows |
| `home_team_id` | Home team ID | Football developer: fixed bilateral orientation anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral orientation anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home final score | Football developer: outcome context around dismissal impact |
| `away_score` | Away final score | Football developer: outcome context around dismissal impact |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation for slicing |
| `triggered_player_id` | Triggered player ID | Football developer: player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Triggered player team ID | Football developer: binds player event to team context |
| `triggered_team_name` | Triggered player team name | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context key |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_yellow_cards_for_dismissal` | Yellow-card threshold for trigger (`2`) | Football developer: explicit trigger guard for QA |
| `triggered_player_first_yellow_card_minute` | Minute of first yellow card | Football developer: early-risk timing context |
| `triggered_player_second_yellow_dismissal_minute` | Minute of second-yellow dismissal event | Football developer: core trigger timestamp |
| `triggered_player_yellow_cards_match` | Triggered player yellow cards in match | Football developer: confirms trigger volume |
| `triggered_player_red_cards_match` | Triggered player red cards in match | Football developer: dismissal-escalation context |
| `triggered_player_total_cards_match` | Triggered player total cards in match | Football developer: compact discipline-load metric |
| `triggered_team_score_at_dismissal` | Triggered-team score at dismissal moment | Football developer: game-state context at trigger |
| `opponent_score_at_dismissal` | Opponent score at dismissal moment | Football developer: bilateral game-state context |
| `score_margin_at_dismissal` | Triggered-team score margin at dismissal | Football developer: pressure/scoreline context at event time |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: aggression context around dismissal |
| `triggered_player_duels_won` | Duels won by triggered player | Football developer: contest profile around disciplinary risk |
| `triggered_player_duels_lost` | Duels lost by triggered player | Football developer: pressure-exposure context |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: defensive engagement context |
| `triggered_player_interceptions` | Interceptions by triggered player | Football developer: anticipation and defensive role context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure normalization context |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_yellow_cards_match` | Team yellow cards on triggered side | Football developer: team-level caution context |
| `opponent_yellow_cards_match` | Team yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Team red cards on triggered side | Football developer: severe-discipline team context |
| `opponent_red_cards_match` | Team red cards on opponent side | Football developer: bilateral severe-discipline comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control context around dismissal |
| `opponent_possession_pct` | Opponent-side possession percentage | Football developer: bilateral control comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: technical output context |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral technical output comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: control efficiency context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral efficiency benchmark |
