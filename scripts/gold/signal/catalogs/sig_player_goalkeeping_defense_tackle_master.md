---
signal_id: sig_player_goalkeeping_defense_tackle_master
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Tackle Master"
trigger: "Defender wins >= 6 tackles with 100% success rate in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_tackle_master
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_tackle_master.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_goalkeeping_defense_tackle_master

## Purpose

Flags defender performances with high-volume perfect tackling (`>= 6` wins and `100%` success), while preserving bilateral defensive and control context for interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_tackles_won >= 6`
  - `triggered_player_tackle_attempts = triggered_player_tackles_won` (perfect tackle success)
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `is_goalkeeper = 0`
- Player tackle and defensive-action metrics are sourced from `silver.player_match_stat`.
- Defender scope comes from `silver.match_personnel` (`usual_playing_position_id = 1`) using starter-priority resolution across personnel rows per match.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` metrics for tackles, duels, interceptions, clearances, fouls, possession, and pass accuracy.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_brick_wall`: same family/subfamily but goalkeeper save-volume logic; no overlap with defender tackle trigger.
  - `sig_player_goalkeeping_defense_reflex_save_streak`: same family/subfamily but rolling-window save burst logic; no overlap with tackle trigger.
  - `sig_player_discipline_cards_iron_man_discipline`: closest tackle-oriented player signal; this new signal coexists because it requires perfect tackle efficiency at `>= 6` wins and does not require `90` minutes or `0` fouls.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_tackle_master.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_tackle_master`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_tackle_master
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for player/team/match feature joins |
| `match_date` | Match date | Football developer: temporal trend and recency slicing |
| `home_team_id` | Home team ID | Football developer: fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context around tackle output |
| `away_score` | Away full-time goals | Football developer: outcome context around tackle output |
| `triggered_side` | Side of triggered defender (`home` or `away`) | Football developer: canonical orientation for side-aware aggregation |
| `triggered_player_id` | Triggered defender ID | Football developer: player-grain identity key |
| `triggered_player_name` | Triggered defender name | Football developer: readable signal attribution |
| `triggered_team_id` | Team ID of triggered defender | Football developer: links player event to team tactical context |
| `triggered_team_name` | Team name of triggered defender | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_role_group` | Derived role label for trigger scope (`defender`) | Football developer: explicit role provenance for QA |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: positional QA for defender attribution |
| `triggered_player_usual_playing_position_id` | Usual playing position ID from personnel data | Football developer: deterministic defender-scope gate |
| `trigger_threshold_min_tackles_won` | Tackles-won trigger threshold (`6`) | Football developer: explicit trigger boundary for reproducibility |
| `trigger_threshold_min_tackle_success_pct` | Tackle-success trigger threshold (`100`) | Football developer: explicit perfect-efficiency requirement |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Football developer: core trigger volume metric |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Football developer: denominator validating efficiency condition |
| `triggered_player_tackle_success_pct` | Tackle success percentage of triggered defender | Football developer: core perfect-execution trigger metric |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Football developer: discipline context around aggressive defending |
| `triggered_player_duels_won` | Duels won by triggered defender | Football developer: contest dominance context beyond tackles |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Football developer: balance context for duel profile interpretation |
| `triggered_player_interceptions` | Interceptions by triggered defender | Football developer: anticipation/reading-of-play context |
| `triggered_player_clearances` | Clearances by triggered defender | Football developer: box-defense workload context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Football developer: defensive load context around trigger |
| `triggered_player_recoveries` | Ball recoveries by triggered defender | Football developer: transition-defense contribution context |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Football developer: exposure context for comparing outputs |
| `triggered_player_tackles_won_above_threshold` | Tackle wins above threshold (`tackles_won - 6`) | Football developer: trigger severity beyond binary activation |
| `triggered_player_tackle_success_above_threshold_pct` | Tackle success above threshold in percentage points (`success_pct - 100`) | Football developer: precision drift monitor around perfect-efficiency rule |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: team defensive-intensity baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive-intensity comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: team physical-duel context |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-duel comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Football developer: team anticipation/press context |
| `opponent_interceptions` | Team interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Football developer: defensive-territory pressure context |
| `opponent_clearances` | Team clearances by opponent side | Football developer: bilateral pressure comparator |
| `triggered_team_fouls` | Team fouls committed by triggered side | Football developer: team discipline context around tackling style |
| `opponent_fouls` | Team fouls committed by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control/style context for defensive workload |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: team execution context under defensive pressure |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral execution comparator |
