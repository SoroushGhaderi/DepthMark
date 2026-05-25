---
signal_id: sig_match_goalkeeping_defense_tackle_and_interception_fest
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Tackle and Interception Fest"
trigger: "Combined match tackles won plus interceptions exceeds 80."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_goalkeeping_defense_tackle_and_interception_fest
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_tackle_and_interception_fest.sql
  runner: scripts/gold/signal/runners/sig_match_goalkeeping_defense_tackle_and_interception_fest.py
---
# sig_match_goalkeeping_defense_tackle_and_interception_fest

## Purpose

Detect finished matches with extreme combined tackle-plus-interception defensive intensity and emit side-oriented rows so each team's contribution and bilateral context are interpreted symmetrically.

## Tactical And Statistical Logic

- Trigger condition: `(tackles_succeeded_home + tackles_succeeded_away + interceptions_home + interceptions_away) > 80` from `silver.period_stat` at `period = 'All'`.
- Only finished matches are included via `silver.match.match_finished = 1` and `match_id > 0`.
- Trigger is match-level; output grain remains `match_team`, producing two rows per triggered match (`triggered_side = 'home'` and `triggered_side = 'away'`).
- The core intensity metric is `match_total_tackles_and_interceptions`; severity beyond threshold is surfaced as `match_total_tackles_and_interceptions_above_threshold`.
- Side contribution metrics (`triggered_team_tackles_and_interceptions`, share pct, and deltas) expose whether the defensive load is balanced or asymmetric.
- Bilateral context includes tackles, interceptions, clearances, duels, aerials, shots faced, keeper saves, fouls, possession, pass accuracy, and scoreline outcome.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_tackle_war`: same entity/family/subfamily and match-level framing, but trigger uses combined tackles only (`> 40`) instead of combined tackles plus interceptions.
  - `sig_match_goalkeeping_defense_defensive_masterclass_match`: same defensive-intensity lens, but trigger uses combined interceptions only (`> 35`) rather than the blended tackles+interceptions composite.
  - `sig_match_goalkeeping_defense_physical_duels_peak`: adjacent physicality profile, but trigger axis is total duel volume, not anticipation+ground-regain composite intensity.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_tackle_and_interception_fest.sql`
- Runner: `scripts/gold/signal/runners/sig_match_goalkeeping_defense_tackle_and_interception_fest.py`
- Target table: `gold.sig_match_goalkeeping_defense_tackle_and_interception_fest`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_goalkeeping_defense_tackle_and_interception_fest.py
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
| `trigger_threshold_min_combined_tackles_and_interceptions` | Configured trigger threshold (`80`) | Explicit trigger provenance for QA and reproducibility |
| `match_total_tackles_and_interceptions` | Combined tackles won and interceptions in match | Core match trigger metric |
| `match_total_tackles_and_interceptions_above_threshold` | Combined T+I above threshold (`value - 80`) | Measures trigger severity beyond activation |
| `triggered_team_tackles_and_interceptions` | Triggered-side tackles+interceptions total | Side contribution to combined defensive intensity |
| `opponent_tackles_and_interceptions` | Opponent tackles+interceptions total | Bilateral contribution comparator |
| `tackles_and_interceptions_delta` | Triggered minus opponent tackles+interceptions | Net defensive-intensity imbalance |
| `triggered_team_tackles_and_interceptions_share_pct` | Triggered-side share of combined T+I (%) | Normalized contribution context |
| `opponent_tackles_and_interceptions_share_pct` | Opponent share of combined T+I (%) | Symmetric normalized comparator |
| `tackles_and_interceptions_share_delta_pct` | Triggered minus opponent share (pp) | Compact normalized imbalance metric |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-defending component context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral ground-defending comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation component context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
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
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Control-state context around defensive intensity |
| `opponent_possession_pct` | Possession share of opponent side (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context for high-intensity defending matches |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline context |
| `goal_delta` | Triggered minus opponent goals | Compact match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates defensive activity from clean-sheet outcome |
