---
signal_id: sig_player_goalkeeping_defense_clean_sheet_contributor
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Clean Sheet Contributor"
trigger: "Defender plays 90 minutes, wins 100% of total duels (ground + aerial), and team keeps a clean sheet."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_clean_sheet_contributor
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_clean_sheet_contributor.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_clean_sheet_contributor

## Purpose

Flags full-match defender performances where duel execution is perfect and the side concedes zero,
capturing clean-sheet contribution through direct defensive contests.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `triggered_player_minutes_played >= 90`
  - `triggered_player_total_duel_attempts >= 1`
  - `triggered_player_total_duels_won = triggered_player_total_duel_attempts`
  - `triggered_team_clean_sheet_flag = 1`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Combined duel metrics are computed as:
  - `triggered_player_total_duels_won = ground_duels_won + aerial_duels_won`
  - `triggered_player_total_duel_attempts = ground_duel_attempts + aerial_duel_attempts`
  - `triggered_player_total_duel_success_pct = 100 * total_duels_won / total_duel_attempts`
- Defender scope is resolved from `silver.match_personnel` with starter-priority role resolution at
  `(match_id, person_id)` grain.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric
  `triggered_team_*` and `opponent_*` defensive/control fields.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_no_fouls_defending`: same defender-family context, but that signal
    is discipline-focused (`0` fouls + contest volume) and does not require 90 minutes, perfect total duel
    record, or clean sheet outcome.
  - `sig_player_goalkeeping_defense_unbeatable_duelist`: closest duel-efficiency overlap, but this signal
    hard-requires full-match exposure (`>= 90`), perfect duel record (`100%`), and clean sheet.
  - `sig_player_goalkeeping_defense_clean_sheet_locked`: clean-sheet overlap exists, but that signal is
    goalkeeper-specific and pressure-quality driven (xGOT), not defender duel execution.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_clean_sheet_contributor.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_clean_sheet_contributor`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_clean_sheet_contributor
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing for trend analysis |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context for clean-sheet validation |
| `away_score` | Away full-time goals | Outcome context for clean-sheet validation |
| `triggered_side` | Side of triggered defender (`home` or `away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered defender ID | Player identity key |
| `triggered_player_name` | Triggered defender name | Readable player attribution |
| `triggered_team_id` | Triggered defender team ID | Links player trigger to team context |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role group label (`defender`) | Explicit role scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Role deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender gate traceability |
| `trigger_threshold_min_minutes_played` | Minimum minutes threshold (`90`) | Explicit full-match exposure trigger boundary |
| `trigger_threshold_min_total_duel_attempts` | Minimum total duel attempts threshold (`1`) | Prevents zero-attempt false positives |
| `trigger_threshold_min_total_duel_success_pct` | Minimum duel success threshold (`100`) | Explicit perfect-efficiency trigger boundary |
| `trigger_condition_clean_sheet_required` | Clean-sheet requirement flag (`1`) | Explicit outcome-condition provenance |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes zero | Trigger integrity check for outcome condition |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure reliability context |
| `triggered_player_total_duels_won` | Combined duel wins (`ground + aerial`) | Core trigger metric |
| `triggered_player_total_duel_attempts` | Combined duel attempts (`ground + aerial`) | Core trigger denominator |
| `triggered_player_total_duel_success_pct` | Combined duel success percentage | Perfect-duel execution metric |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Ground-contest contribution context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground-contest denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-contest efficiency diagnostic |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Aerial-contest contribution context |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Aerial-contest denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial-contest efficiency diagnostic |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Contest-balance context |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Defensive engagement context beyond trigger |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage by triggered defender | Tackling quality diagnostic |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation context |
| `triggered_player_clearances` | Clearances by triggered defender | Pressure-release context |
| `triggered_player_recoveries` | Recoveries by triggered defender | Regain-and-transition context |
| `triggered_player_defensive_actions` | Defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Discipline context around perfect duel execution |
| `triggered_player_dribbled_past` | Times dribbled past | Vulnerability counter-signal context |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered defender | Ball-retention quality context |
| `triggered_team_duels_won` | Team duels won by triggered side | Team contest-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest differential context |
| `triggered_team_ground_duels_won` | Team ground duels won by triggered side | Ground-contest baseline |
| `opponent_ground_duels_won` | Team ground duels won by opponent side | Bilateral ground-contest comparator |
| `ground_duels_won_delta` | Triggered minus opponent ground duels won | Net ground-contest differential context |
| `triggered_team_aerials_won` | Team aerial duels won by triggered side | Aerial-contest baseline |
| `opponent_aerials_won` | Team aerial duels won by opponent side | Bilateral aerial-contest comparator |
| `aerials_won_delta` | Triggered minus opponent aerial duels won | Net aerial-contest differential context |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential context |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential context |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential context |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net box-protection differential context |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure-volume context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-volume differential context |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential context |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context around clean-sheet profile |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential context |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution differential context |
| `player_share_of_team_total_duels_won_pct` | Triggered player share of side total duel wins | Concentration of perfect-duel contribution in one defender |
