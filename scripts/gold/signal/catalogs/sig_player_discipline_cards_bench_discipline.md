---
signal_id: sig_player_discipline_cards_bench_discipline
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Bench Discipline"
trigger: "Non-playing substitute or manager receives a yellow/red card (from match_personnel-linked card events)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_bench_discipline
  sql: clickhouse/gold/signal/sig_player_discipline_cards_bench_discipline.sql
  runner: scripts/gold/signal/runners/sig_player_discipline_cards_bench_discipline.py
---
# sig_player_discipline_cards_bench_discipline

## Purpose

Flags disciplinary incidents involving non-playing bench personnel (unused substitutes) and managers, so we can track technical-area and bench-control volatility separate from on-pitch player behavior.

## Tactical And Statistical Logic

- Trigger scope includes only `silver.match_personnel` roles:
  - `role = 'coach'` (manager)
  - `role = 'substitute'` with `substitution_time <= 0` (non-playing substitute)
- Card events are sourced from `silver.card` and linked by `match_id`, `player_id/person_id`, and `team_side`.
- Trigger card types include yellow/red (including second-yellow dismissals classified as dismissal type).
- One row is emitted per triggered personnel entry per match using the earliest qualifying card event.
- Bilateral team context (fouls, cards, possession, and passing quality) is attached from `silver.period_stat` (`period = 'All'`).
- Player-stat fields remain included for schema compatibility; manager and non-playing bench rows naturally resolve these player metrics to `0` when no `silver.player_match_stat` row exists.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_bench_discipline.sql`
- Runner: `scripts/gold/signal/runners/sig_player_discipline_cards_bench_discipline.py`
- Target table: `gold_signals.sig_player_discipline_cards_bench_discipline`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_discipline_cards_bench_discipline.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for downstream joins |
| `match_date` | Match date | Football developer: temporal analysis and windowing |
| `home_team_id` | Home team ID | Football developer: bilateral match anchor |
| `home_team_name` | Home team name | Football developer: readable match context |
| `away_team_id` | Away team ID | Football developer: bilateral match anchor |
| `away_team_name` | Away team name | Football developer: readable match context |
| `home_score` | Home final score | Football developer: outcome context |
| `away_score` | Away final score | Football developer: outcome context |
| `triggered_side` | Triggered side (`home`/`away`) | Football developer: canonical side orientation |
| `triggered_player_id` | Triggered personnel ID (`person_id`) | Football developer: personnel identity key |
| `triggered_player_name` | Triggered personnel name | Football developer: human-readable attribution |
| `triggered_team_id` | Team ID of triggered personnel | Football developer: team-context linkage |
| `triggered_team_name` | Team name of triggered personnel | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: bilateral matchup context |
| `triggered_personnel_role` | Raw role from match personnel (`coach`/`substitute`) | Football developer: reproducible role classification |
| `triggered_personnel_scope` | Derived trigger scope (`manager`/`non_playing_substitute`) | Football developer: explicit trigger explainability |
| `triggered_personnel_substitution_time` | Substitution time for personnel record | Football developer: validates non-playing substitute gating |
| `trigger_threshold_non_playing_substitution_time` | Non-playing threshold (`0`) | Football developer: fixed trigger boundary for QA |
| `triggered_player_card_minute` | Minute of first qualifying card | Football developer: trigger timing |
| `triggered_player_card_event_type` | Card event type (`yellow`, `red`, `second_yellow_dismissal`) | Football developer: severity decomposition |
| `triggered_team_score_at_card` | Triggered-team score at card time | Football developer: score-state context |
| `opponent_score_at_card` | Opponent score at card time | Football developer: bilateral score-state context |
| `score_margin_at_card` | Triggered-team score margin at card time | Football developer: pressure context at event |
| `triggered_player_total_cards_match` | Total cards for triggered personnel ID in match | Football developer: match-level discipline load |
| `triggered_player_yellow_cards_match` | Yellow cards for triggered personnel ID in match | Football developer: caution profile |
| `triggered_player_red_cards_match` | Red cards for triggered personnel ID in match | Football developer: dismissal profile |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: behavior context when available |
| `triggered_player_was_fouled` | Fouls suffered by triggered player | Football developer: contact context when available |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: confirms bench/non-playing dynamics |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_yellow_cards_match` | Yellow cards for triggered side | Football developer: team caution context |
| `opponent_yellow_cards_match` | Yellow cards for opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Red cards for triggered side | Football developer: team dismissal context |
| `opponent_red_cards_match` | Red cards for opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: circulation volume context |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: passing-output context |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral passing-output comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: technical efficiency context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral efficiency benchmark |
