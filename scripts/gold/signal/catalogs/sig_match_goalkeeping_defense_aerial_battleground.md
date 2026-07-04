---
signal_id: sig_match_goalkeeping_defense_aerial_battleground
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Aerial Battleground"
trigger: "Combined match aerial duels exceed 60."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_aerial_battleground
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_aerial_battleground.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_goalkeeping_defense_aerial_battleground

## Purpose

Detect finished matches where aerial contest intensity is extreme, then emit side-oriented bilateral context so vertical control, defensive workload, and outcome effects are interpretable for each team perspective.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(aerials_won_home, 0) + coalesce(aerials_won_away, 0)) > 60` from `silver.period_stat` at `period = 'All'`.
- Only finished matches are included (`silver.match.match_finished = 1`) with valid `match_id > 0`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Trigger severity is explicit via `match_total_aerials_won_above_threshold = match_total_aerials_won - 60` and balance is captured by `match_aerials_won_balance_abs`.
- Symmetric enrichment preserves physical and defensive context using duels, tackles, interceptions, clearances, pressure faced, keeper saves, fouls, possession, pass accuracy, and scoreline metrics.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_tackle_war`: closest match-level defensive intensity overlap, but trigger axis is combined tackles rather than combined aerial duels.
  - `sig_match_goalkeeping_defense_offside_frenzy`: same entity/family/subfamily and row grain, but trigger axis is combined offsides, not aerial contests.
  - `sig_team_possession_passing_aerial_reliance`: aerial theme overlap, but that signal is team-triggered on distribution style, while this one is match-triggered on bilateral aerial volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_aerial_battleground.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_aerial_battleground`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_aerial_battleground
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
| `home_score` | Home full-time goals | Outcome context for high-aerial matches |
| `away_score` | Away full-time goals | Outcome context for high-aerial matches |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical identity field at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable triggered team identity |
| `triggered_team_name` | Triggered-side team name | Readable triggered team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_aerials_won` | Configured aerial trigger threshold (`60`) | Explicit trigger provenance for QA and reproducibility |
| `match_total_aerials_won` | Combined aerial duels won in match | Core trigger metric for aerial-intensity detection |
| `match_total_aerials_won_above_threshold` | Combined aerials won above threshold (`value - 60`) | Measures trigger severity beyond activation |
| `match_aerials_won_balance_abs` | Absolute aerial-win gap between sides | Distinguishes balanced aerial battles from one-sided domination |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Side-level contribution to aerial intensity |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net vertical-control differential |
| `triggered_team_aerials_won_share_pct` | Triggered-side share of combined aerial wins (%) | Normalized aerial-burden contribution |
| `opponent_aerials_won_share_pct` | Opponent share of combined aerial wins (%) | Symmetric normalized comparator |
| `aerials_won_share_delta_pct` | Triggered minus opponent aerial-win share (pp) | Compact normalized intensity imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Broader physical contest control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-defensive activity context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
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
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Control-state context around aerial volume |
| `opponent_possession_pct` | Possession share of opponent side (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context for aerial-heavy matches |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline context |
| `goal_delta` | Triggered minus opponent goals | Compact match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates aerial intensity from clean-sheet outcome |
