---
signal_id: sig_player_discipline_cards_heavy_hitter
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Heavy Hitter"
trigger: "Player wins <= 20% of tackles while committing >= 4 fouls in the same match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_heavy_hitter
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_heavy_hitter.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_heavy_hitter

## Purpose

Flags players who combine low tackle efficiency with high foul volume, surfacing defensive profiles that concede contact without winning enough duels cleanly.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_tackle_success_pct <= 20`
  - `triggered_player_fouls_committed >= 4`
  - `triggered_player_tackle_attempts > 0`
- Player tackle and foul metrics are sourced from `silver.player_match_stat`.
- Player card context is sourced from `silver.card` at `match_id + player_id` grain.
- Bilateral team context (fouls, cards, tackles won, duels won, possession) is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` fields.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_heavy_hitter.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_heavy_hitter`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_heavy_hitter
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for downstream joins |
| `match_date` | Match date | Football developer: supports temporal analysis |
| `home_team_id` | Home team ID | Football developer: fixed bilateral orientation anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral orientation anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home final score | Football developer: outcome context |
| `away_score` | Away final score | Football developer: outcome context |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation for side-aware analysis |
| `triggered_player_id` | Triggered player ID | Football developer: player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: binds player event to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context key |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_max_tackle_success_pct` | Tackle-success upper threshold (`20`) | Football developer: explicit trigger boundary for QA |
| `trigger_threshold_min_fouls_committed` | Foul-count lower threshold (`4`) | Football developer: explicit trigger boundary for QA |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: raw defensive success count |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Football developer: denominator for tackle-efficiency interpretation |
| `triggered_player_tackle_success_pct` | Tackle success percentage of triggered player | Football developer: core inefficiency trigger metric |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: core high-contact trigger metric |
| `triggered_player_total_cards` | Total cards for triggered player | Football developer: discipline escalation context |
| `triggered_player_yellow_cards` | Yellow cards for triggered player | Football developer: caution-level decomposition |
| `triggered_player_red_cards` | Red cards for triggered player | Football developer: severe-discipline decomposition |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context |
| `tackle_success_below_threshold_pct` | Gap below trigger tackle-success threshold (`20 - success_pct`) | Football developer: trigger severity measure beyond binary gate |
| `foul_count_above_threshold` | Fouls above trigger threshold (`fouls - 4`) | Football developer: trigger severity measure beyond binary gate |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) by triggered side | Football developer: team discipline environment around trigger |
| `opponent_total_cards` | Total cards (yellow+red) by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: team-level defensive success context |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive-success comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: physical-contest context |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-contest comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: style/control context around defensive risk |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
