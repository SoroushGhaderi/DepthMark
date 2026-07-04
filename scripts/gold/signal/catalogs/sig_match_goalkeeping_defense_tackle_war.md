---
signal_id: sig_match_goalkeeping_defense_tackle_war
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Tackle War"
trigger: "Combined match tackles exceed 40."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_tackle_war
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_tackle_war.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_goalkeeping_defense_tackle_war

## Purpose

Detects finished matches with extreme combined successful tackle volume and emits side-oriented rows so defensive workload and control context can be compared symmetrically.

## Tactical And Statistical Logic

- Trigger condition: `(tackles_succeeded_home + tackles_succeeded_away) > 40` from `silver.period_stat` at `period = 'All'`.
- Only finished matches are included via `silver.match.match_finished = 1` with valid `match_id > 0`.
- Trigger is match-level; output grain is `match_team` using two rows per match (`triggered_side = 'home'` and `triggered_side = 'away'`).
- Severity is exposed via `match_total_tackles_won_above_threshold = match_total_tackles_won - 40`.
- Symmetric enrichment includes interceptions, clearances, duels, aerials, shots faced, keeper saves, fouls, possession, pass accuracy, and scoreline context.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_tackle_volume_surge`: closest tackle-intensity overlap, but that signal is side-triggered (`triggered_team_tackles_won >= 25`) while this signal is match-triggered on combined tackles.
  - `sig_match_discipline_cards_blood_and_thunder`: match-level physicality overlap, but its trigger is duel+foul intensity, not tackle-specific volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_tackle_war.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_tackle_war`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_tackle_war
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports partitioning and temporal analysis |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for defensive-intensity interpretation |
| `away_score` | Away full-time goals | Outcome context for defensive-intensity interpretation |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical identity field at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable triggered team identity |
| `triggered_team_name` | Triggered-side team name | Readable triggered team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_tackles_won` | Configured tackle trigger threshold (`40`) | Explicit trigger provenance for QA and reproducibility |
| `match_total_tackles_won` | Combined successful tackles in match | Core match trigger metric |
| `match_total_tackles_won_above_threshold` | Combined tackles above threshold (`value - 40`) | Measures trigger severity beyond activation |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Side-level contribution to match tackle intensity |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackle comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackle-intensity differential |
| `triggered_team_tackles_won_share_pct` | Triggered-side share of combined tackles (%) | Normalized tackle burden contribution |
| `opponent_tackles_won_share_pct` | Opponent share of combined tackles (%) | Symmetric normalized comparator |
| `tackles_won_share_delta_pct` | Triggered minus opponent tackle share (pp) | Compact normalized intensity imbalance |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net interception differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical contest control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical contest context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line defensive workload context |
| `opponent_keeper_saves` | Saves by opponent goalkeeper | Bilateral goalkeeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net keeper workload differential |
| `triggered_team_fouls_committed` | Fouls by triggered side | Defensive aggression and discipline context |
| `opponent_fouls_committed` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Control-state context around defensive volume |
| `opponent_possession_pct` | Possession share of opponent side (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context for tackle-heavy matches |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline context |
| `goal_delta` | Triggered minus opponent goals | Compact match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates defensive activity from clean-sheet outcome |
