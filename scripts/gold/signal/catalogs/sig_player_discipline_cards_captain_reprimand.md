---
signal_id: sig_player_discipline_cards_captain_reprimand
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Captain Reprimand"
trigger: "Team captain receives a yellow card for dissent/reprimand."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_captain_reprimand
  sql: clickhouse/gold/signal/sig_player_discipline_cards_captain_reprimand.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_captain_reprimand

## Purpose

Flags matches where the on-field captain is cautioned for dissent/reprimand, preserving player identity, event timing, and bilateral team context for discipline-pressure analysis.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_is_captain = 1`
  - at least one yellow-card event tagged with dissent/reprimand text in `silver.card` (`card_type` or `description`).
- Captains are sourced from `silver.match_personnel` (`role = 'starter'`, `is_captain = 1`) and aligned by match, player, and side.
- The signal emits one row per triggered captain per match using the first qualifying dissent yellow-card event.
- Output stores player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) at player grain.
- Bilateral team context (cards, fouls, possession, and passing) is attached from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` fields.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_captain_reprimand.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_captain_reprimand`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_captain_reprimand
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
| `home_score` | Home final score | Football developer: scoreline context around captain dissent event |
| `away_score` | Away final score | Football developer: scoreline context around captain dissent event |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation for slicing |
| `triggered_player_id` | Triggered captain player ID | Football developer: player identity key for captain-specific analysis |
| `triggered_player_name` | Triggered captain player name | Football developer: readable captain attribution |
| `triggered_team_id` | Triggered captain team ID | Football developer: binds player event to team context |
| `triggered_team_name` | Triggered captain team name | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context key |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_dissent_yellow_cards` | Trigger threshold count for dissent yellow cards (`1`) | Football developer: explicit trigger guard for QA |
| `triggered_player_is_captain` | Captain flag for triggered player (`1`) | Football developer: confirms leadership-role filter |
| `triggered_player_dissent_yellow_card_minute` | Minute of the first qualifying dissent/reprimand yellow card | Football developer: core trigger timing |
| `triggered_team_score_at_dissent_card` | Triggered-team score at dissent card time | Football developer: in-game state context at trigger |
| `opponent_score_at_dissent_card` | Opponent score at dissent card time | Football developer: bilateral game-state comparator |
| `score_margin_at_dissent_card` | Triggered-team score margin at dissent card time | Football developer: pressure/scoreline interpretation context |
| `triggered_player_yellow_cards_match` | Triggered player's yellow cards in match | Football developer: discipline-load context for triggered captain |
| `triggered_player_red_cards_match` | Triggered player's red cards in match | Football developer: escalation context beyond caution |
| `triggered_player_total_cards_match` | Triggered player's total cards in match | Football developer: compact discipline-intensity metric |
| `triggered_player_fouls_committed` | Fouls committed by triggered captain | Football developer: aggression context around dissent caution |
| `triggered_player_duels_won` | Duels won by triggered captain | Football developer: contest profile around disciplinary event |
| `triggered_player_duels_lost` | Duels lost by triggered captain | Football developer: pressure-exposure context |
| `triggered_player_tackles_won` | Tackles won by triggered captain | Football developer: defensive engagement context |
| `triggered_player_interceptions` | Interceptions by triggered captain | Football developer: anticipation and role context |
| `triggered_player_minutes_played` | Minutes played by triggered captain | Football developer: exposure normalization context |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline around event |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_yellow_cards_match` | Team yellow cards on triggered side | Football developer: team caution environment around captain booking |
| `opponent_yellow_cards_match` | Team yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Team red cards on triggered side | Football developer: severe-discipline context on triggered side |
| `opponent_red_cards_match` | Team red cards on opponent side | Football developer: bilateral severe-discipline comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control context around discipline trigger |
| `opponent_possession_pct` | Opponent-side possession percentage | Football developer: bilateral control comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: technical output context |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral technical-output comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: control-efficiency context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral efficiency benchmark |
