---
signal_id: sig_player_discipline_cards_penalty_conceder
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Penalty Conceder"
trigger: "Player commits a foul resulting in a penalty."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_penalty_conceder
  sql: clickhouse/gold/signal/sig_player_discipline_cards_penalty_conceder.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_penalty_conceder

## Purpose

Flags players whose foul-related card events align with opponent penalty awards, surfacing high-impact defensive errors that directly create penalty situations.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_penalties_conceded >= 1`
- Penalty awards are sourced from `silver.shot` using penalty-tagged shots (`situation`/`shot_type` contains `"penalty"`).
- Candidate conceders are taken from opposite-side `silver.card` events within a tight minute window around each penalty.
- Candidate selection is deterministic: per penalty shot, the highest relevance event is selected using description-based penalty/foul cues and closest timing.
- Output stores full player identity (`triggered_player_*`) plus team/opponent identity (`triggered_team_*`, `opponent_team_*`) for player-grain traceability.
- Bilateral discipline and possession context is sourced from `silver.period_stat` (`period = 'All'`) and penalty-volume context is sourced from match-level penalty shot aggregates.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_penalty_conceder.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_penalty_conceder`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_penalty_conceder
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across signal, player, and match context |
| `match_date` | Match calendar date | Football developer: enables temporal trend analysis for penalty-concession behavior |
| `home_team_id` | Home team ID | Football developer: preserves fixed bilateral orientation anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: preserves fixed bilateral orientation anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Final home goals | Football developer: outcome context for penalty-concession impact |
| `away_score` | Final away goals | Football developer: outcome context for penalty-concession impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream slicing |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player event to team-level tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup identity for bilateral comparisons |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup attribution |
| `trigger_threshold_penalties_conceded` | Configured trigger threshold for penalties conceded (`1`) | Football developer: explicit row-level trigger guard for reproducibility |
| `triggered_player_penalties_conceded` | Number of penalties attributed to triggered player in the match | Football developer: core trigger metric for high-impact defensive errors |
| `triggered_player_first_penalty_conceded_minute` | Minute of first penalty concession attributed to triggered player | Football developer: timing severity context for game-state impact |
| `triggered_player_penalties_conceded_scored` | Count of conceded penalties that were converted | Football developer: outcome severity context of conceded penalties |
| `triggered_player_penalties_conceded_missed` | Count of conceded penalties that were not converted | Football developer: variance and mitigation context for conceded penalties |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: broader disciplinary behavior context |
| `triggered_player_was_fouled` | Fouls suffered by triggered player | Football developer: duel-contact context for player profile balancing |
| `triggered_player_total_cards` | Total cards received by triggered player in the match | Football developer: individual discipline load around penalty concessions |
| `triggered_player_yellow_cards` | Yellow cards received by triggered player | Football developer: card-color decomposition for discipline profiling |
| `triggered_player_red_cards` | Red cards received by triggered player | Football developer: severe-discipline escalation context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting concession counts |
| `score_margin_at_first_penalty_concession` | Triggered-team score margin at first penalty concession | Football developer: pressure and game-state context at trigger moment |
| `triggered_team_penalties_awarded` | Penalties awarded to triggered player's team | Football developer: bilateral penalty-flow context in the same match |
| `opponent_penalties_awarded` | Penalties awarded to opponent team | Football developer: direct counterpart to concession-side penalty dynamics |
| `total_match_penalties_awarded` | Total penalties awarded in the match | Football developer: match-level penalty volatility context |
| `triggered_team_total_fouls` | Total fouls committed by triggered player's team | Football developer: team aggression baseline around the trigger |
| `opponent_total_fouls` | Total fouls committed by opponent team | Football developer: bilateral aggression comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) for triggered player's team | Football developer: team discipline context for officiating strictness |
| `opponent_total_cards` | Total cards (yellow+red) for opponent team | Football developer: bilateral discipline comparator |
| `triggered_team_yellow_cards` | Team yellow cards on triggered side | Football developer: team caution-load context |
| `opponent_yellow_cards` | Team yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Team red cards on triggered side | Football developer: high-impact discipline context |
| `opponent_red_cards` | Team red cards on opponent side | Football developer: bilateral severe-discipline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control/style context around concession patterns |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
