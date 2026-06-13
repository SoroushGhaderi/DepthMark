---
signal_id: sig_player_discipline_cards_sub_card_speedrun
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Sub Card Speedrun"
trigger: "Substitute player receives a yellow or red card within 5 minutes of entering the pitch."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_sub_card_speedrun
  sql: clickhouse/gold/signal/sig_player_discipline_cards_sub_card_speedrun.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_sub_card_speedrun

## Purpose

Flags substitute players who are booked almost immediately after coming on, surfacing high-risk discipline cameos that can quickly distort match control.

## Tactical And Statistical Logic

- Trigger condition:
  - `minutes_from_substitution_to_card <= 5`
- Substitute entry time is sourced from `silver.match_personnel` rows where `role = 'substitute'`.
- Card events are sourced from `silver.card`; yellow and red cards are both considered valid trigger events.
- The signal emits one row per triggered substitute player per match using the earliest qualifying card event after substitution.
- Output preserves full player identity (`triggered_player_*`) and team identity (`triggered_team_*`) at player grain.
- Bilateral team context (cards, fouls, possession, passing) is attached from `silver.period_stat` (`period = 'All'`) to support tactical interpretation and QA.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_sub_card_speedrun.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_sub_card_speedrun`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_sub_card_speedrun
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for downstream joins |
| `match_date` | Match date | Football developer: supports temporal analysis and model windowing |
| `home_team_id` | Home team ID | Football developer: bilateral orientation anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: bilateral orientation anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home final score | Football developer: outcome context for immediate-card impact |
| `away_score` | Away final score | Football developer: outcome context for immediate-card impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream slicing |
| `triggered_player_id` | Triggered substitute player ID | Football developer: player identity key at signal grain |
| `triggered_player_name` | Triggered substitute player name | Football developer: human-readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player event to team tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `trigger_threshold_minutes_from_substitution` | Trigger threshold in minutes (`5`) | Football developer: explicit trigger boundary for reproducibility and QA |
| `triggered_player_substitution_time` | Minute the player entered from bench | Football developer: validates substitute status and entry timing |
| `triggered_player_card_minute` | Minute of the first qualifying card event after entry | Football developer: core trigger timestamp |
| `minutes_from_substitution_to_card` | Delay between entry and qualifying card event | Football developer: core severity metric for rapid discipline collapse |
| `triggered_player_card_event_type` | Qualifying card event type (`yellow`, `red`, or `second_yellow_dismissal`) | Football developer: distinguishes caution vs dismissal profiles |
| `triggered_player_score_at_card` | Triggered-team score at card time | Football developer: score-state context at the trigger moment |
| `opponent_score_at_card` | Opponent score at card time | Football developer: bilateral score-state context at trigger |
| `score_margin_at_card` | Triggered-team score margin at card time | Football developer: pressure context for interpreting the event |
| `triggered_player_total_cards_match` | Total cards for triggered player in the match | Football developer: validates broader discipline load around trigger |
| `triggered_player_yellow_cards_match` | Yellow cards for triggered player in the match | Football developer: card-color decomposition for discipline profiling |
| `triggered_player_red_cards_match` | Red cards for triggered player in the match | Football developer: escalation/severity context |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: aggression context behind rapid booking |
| `triggered_player_was_fouled` | Fouls suffered by triggered player | Football developer: contact profile context around trigger |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting discipline counts |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline around the event |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_yellow_cards_match` | Total yellow cards for triggered side | Football developer: team caution context around substitute booking |
| `opponent_yellow_cards_match` | Total yellow cards for opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Total red cards for triggered side | Football developer: team dismissal context around the trigger |
| `opponent_red_cards_match` | Total red cards for opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for tactical interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: circulation volume context |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: passing-output context around disruption |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral passing-output comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: technical control efficiency context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral efficiency benchmark |
