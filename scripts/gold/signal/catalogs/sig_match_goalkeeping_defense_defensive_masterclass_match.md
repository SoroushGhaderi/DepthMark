---
signal_id: sig_match_goalkeeping_defense_defensive_masterclass_match
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Defensive Masterclass Match"
trigger: "Combined match interceptions exceed 35."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_defensive_masterclass_match
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_defensive_masterclass_match.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_goalkeeping_defense_defensive_masterclass_match

## Purpose

Detects finished matches with exceptional combined interception volume and emits side-oriented rows
so anticipation dominance, defensive workload, control state, and outcomes can be interpreted
symmetrically.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(interceptions_home, 0) + coalesce(interceptions_away, 0)) > 35` from `silver.period_stat` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `triggered_side = 'away'`) to preserve canonical `match_team` orientation.
- Severity is exposed as `match_total_interceptions_above_threshold = match_total_interceptions - 35`.
- Interception context is bilateral through raw counts, share percentages, and deltas, then enriched with clearances, tackles, duels, aerials, shot pressure faced, goalkeeper workload, discipline, possession, passing quality, and scoreline translation.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_tackle_war`: same entity/family/subfamily and match-level framing, but trigger axis is combined successful tackles, not interceptions.
  - `sig_match_goalkeeping_defense_offside_frenzy`: same family and bilateral defensive context style, but trigger axis is combined offsides rather than anticipation volume.
  - `sig_team_goalkeeping_defense_recovery_dominance`: related ball-regain intent, but team-triggered on side-level recoveries (`>= 60`), not match-triggered combined interceptions.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_defensive_masterclass_match.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_defensive_masterclass_match`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_goalkeeping_defense_defensive_masterclass_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal analysis and reproducible backfills |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for defensive interpretation |
| `away_score` | Away full-time goals | Scoreline context for defensive interpretation |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_interceptions` | Combined interception threshold baseline (`35`) | Explicit trigger provenance |
| `match_total_interceptions` | Combined interceptions (`home + away`) | Core trigger metric |
| `match_total_interceptions_above_threshold` | Combined interceptions above threshold | Trigger severity context |
| `triggered_team_interceptions` | Interceptions by triggered side | Side-level anticipation output |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_interceptions_share_pct` | Triggered-side share of combined interceptions (%) | Normalized anticipation contribution |
| `opponent_interceptions_share_pct` | Opponent share of combined interceptions (%) | Symmetric normalized comparator |
| `interceptions_share_delta_pct` | Triggered minus opponent interception share (pp) | Net normalized anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-duel defensive context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral duel comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net shot-stopping workload differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Discipline trade-off context |
| `opponent_fouls_committed` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates defensive event intensity from clean-sheet outcome |
