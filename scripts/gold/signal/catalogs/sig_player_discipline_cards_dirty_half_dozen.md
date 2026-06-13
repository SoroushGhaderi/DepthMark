---
signal_id: sig_player_discipline_cards_dirty_half_dozen
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Dirty Half Dozen"
trigger: "Player commits >= 6 fouls while winning 0 tackles in the same match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_dirty_half_dozen
  sql: clickhouse/gold/signal/sig_player_discipline_cards_dirty_half_dozen.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_discipline_cards_dirty_half_dozen

## Purpose

Flags players with extreme foul volume and zero tackle wins, surfacing high-contact defensive profiles that disrupt play without producing clean ball-winning outcomes.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_fouls_committed >= 6`
  - `triggered_player_tackles_won = 0`
- Player foul/tackle context is sourced from `silver.player_match_stat`.
- Player card context is sourced from `silver.card` at `match_id + player_id` grain.
- Bilateral team context (fouls, cards, tackles won, duels won, possession) is sourced from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` fields.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_dirty_half_dozen.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_discipline_cards_dirty_half_dozen`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_discipline_cards_dirty_half_dozen
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
| `trigger_threshold_min_fouls_committed` | Foul-count lower threshold (`6`) | Football developer: explicit trigger boundary for QA |
| `trigger_threshold_max_tackles_won` | Tackle-wins upper threshold (`0`) | Football developer: explicit trigger boundary for QA |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: core contact-intensity trigger metric |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: core no-ball-winning trigger metric |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Football developer: defensive engagement context beyond wins |
| `triggered_player_tackle_success_pct` | Tackle success percentage of triggered player | Football developer: efficiency context for no-win foul-heavy profile |
| `triggered_player_total_cards` | Total cards for triggered player | Football developer: discipline escalation context |
| `triggered_player_yellow_cards` | Yellow cards for triggered player | Football developer: caution-level decomposition |
| `triggered_player_red_cards` | Red cards for triggered player | Football developer: severe-discipline decomposition |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context |
| `foul_count_above_threshold` | Fouls above trigger threshold (`fouls - 6`) | Football developer: trigger severity measure beyond binary gate |
| `tackle_attempts_without_win` | Tackle attempts recorded while still at zero wins | Football developer: highlights failed tackling volume behind the trigger |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team aggression baseline around trigger |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral aggression comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) by triggered side | Football developer: team discipline environment around trigger |
| `opponent_total_cards` | Total cards (yellow+red) by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: team-level defensive success context |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive-success comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: physical-contest context |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-contest comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: style/control context around defensive risk |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
