---
signal_id: sig_player_discipline_cards_late_red_drama
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Late Red Drama"
trigger: "Player receives a red card at minute > 85."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_late_red_drama
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_late_red_drama.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_discipline_cards_late_red_drama

## Purpose

Flags players sent off after the 85th minute, preserving endgame dismissal timing with bilateral match-discipline context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_red_card_minute > 85`
- Red-card events come from `silver.card` rows where `card_type` contains `"red"`.
- The signal emits one row per triggered player per match using the first qualifying late red-card event.
- Output stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for player-grain traceability.
- Bilateral team context (cards, fouls, possession, passing) is attached from `silver.period_stat` (`period = 'All'`) to support interpretation of late-match game-state disruption.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_late_red_drama.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_discipline_cards_late_red_drama`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_discipline_cards_late_red_drama
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable primary key for cross-table joins |
| `match_date` | Match date | Football developer: supports temporal analysis and training windows |
| `home_team_id` | Home team ID | Football developer: bilateral orientation anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: bilateral orientation anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Final home goals | Football developer: outcome context for interpreting late-dismissal impact |
| `away_score` | Final away goals | Football developer: outcome context for interpreting late-dismissal impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream slicing |
| `triggered_player_id` | Triggered player ID | Football developer: core player key for attribution and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: ties player event to team-level tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context for bilateral comparisons |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_min_red_card_minute` | Hard trigger threshold minute (`86`) | Football developer: explicit trigger guard for QA and reproducibility |
| `triggered_player_red_card_minute` | Minute of first qualifying red card for triggered player | Football developer: core trigger metric and endgame timing marker |
| `triggered_team_score_at_red` | Triggered-team score at card time | Football developer: in-game state context at dismissal event |
| `opponent_score_at_red` | Opponent score at card time | Football developer: bilateral in-game state context at dismissal event |
| `triggered_player_red_card_count_match` | Total red cards for triggered player in the match | Football developer: confirms whether dismissal was isolated or repeated-event data artifact |
| `triggered_team_red_cards_match` | Total red cards for triggered side in match totals | Football developer: team-level discipline load around triggered event |
| `opponent_red_cards_match` | Total red cards for opponent side in match totals | Football developer: bilateral discipline context for fairness |
| `triggered_team_yellow_cards_match` | Total yellow cards for triggered side in match totals | Football developer: broader caution profile around dismissal |
| `opponent_yellow_cards_match` | Total yellow cards for opponent side in match totals | Football developer: bilateral caution-pressure context |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: aggression baseline linked to dismissal dynamics |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral foul-pressure context |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context around late-match dismissal |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: circulation volume context in late-match phases |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: passing-output context around the dismissal event |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral passing-output comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: technical control efficiency in endgame conditions |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral efficiency benchmark |
