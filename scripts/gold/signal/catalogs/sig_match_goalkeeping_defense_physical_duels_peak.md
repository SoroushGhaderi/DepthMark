---
signal_id: sig_match_goalkeeping_defense_physical_duels_peak
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Physical Duels Peak"
trigger: "Combined total duels (ground + aerial) exceed 200."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_physical_duels_peak
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_physical_duels_peak.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_goalkeeping_defense_physical_duels_peak

## Purpose

Detects finished matches where total physical duel volume is extreme and emits bilateral side-oriented rows so duel burden, defensive workload, control context, and outcomes can be compared symmetrically.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(duels_won_home, 0) + coalesce(duels_won_away, 0) + coalesce(aerials_won_home, 0) + coalesce(aerials_won_away, 0)) > 200` from `silver.period_stat` at `period = 'All'`.
- Only finished matches are included (`silver.match.match_finished = 1`) with valid `match_id > 0`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Trigger severity is exposed by `match_total_combined_duels_won_above_threshold`, with decomposition into `match_total_ground_duels_won` and `match_total_aerial_duels_won`.
- Side asymmetry is measured via `match_physical_duels_balance_abs` and bilateral share/delta fields.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_aerial_battleground`: same entity/family/subfamily and bilateral shape, but trigger axis is aerial-only (`combined aerials > 60`) rather than total physical duels.
  - `sig_match_goalkeeping_defense_tackle_war`: same match-level defensive-intensity framing, but trigger is tackles-only (`combined tackles > 40`), not ground+aerial duel volume.
  - `sig_match_goalkeeping_defense_interruption_heavy`: same family and bilateral context pattern, but trigger dimension is stoppage intensity (`fouls + offsides`) instead of physical contest volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_physical_duels_peak.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_physical_duels_peak`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_physical_duels_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for duel-heavy matches |
| `away_score` | Away full-time goals | Outcome context for duel-heavy matches |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_total_duels_won` | Trigger baseline (`200`) | Explicit trigger provenance for QA and reproducibility |
| `match_total_combined_duels_won` | Combined physical duels (`ground + aerial`) in match | Core trigger metric |
| `match_total_combined_duels_won_above_threshold` | Combined physical duels above threshold | Trigger severity beyond activation |
| `match_total_ground_duels_won` | Combined ground duels in match | Decomposes physical volume into ground component |
| `match_total_aerial_duels_won` | Combined aerial duels in match | Decomposes physical volume into aerial component |
| `match_physical_duels_balance_abs` | Absolute side gap in combined physical duels | Distinguishes balanced battles from one-sided burden |
| `triggered_team_combined_duels_won` | Combined physical duels won by triggered side | Side-level contribution to trigger metric |
| `opponent_combined_duels_won` | Combined physical duels won by opponent side | Bilateral physical-volume comparator |
| `combined_duels_won_delta` | Triggered minus opponent combined physical duels | Net physical-battle differential |
| `triggered_team_combined_duels_won_share_pct` | Triggered-side share of combined physical duels (%) | Normalized contribution context |
| `opponent_combined_duels_won_share_pct` | Opponent share of combined physical duels (%) | Symmetric normalized comparator |
| `combined_duels_won_share_delta_pct` | Triggered minus opponent combined-duel share (pp) | Compact normalized asymmetry metric |
| `triggered_team_ground_duels_won` | Ground duels won by triggered side | Side-level ground-physical context |
| `opponent_ground_duels_won` | Ground duels won by opponent side | Bilateral ground-duel comparator |
| `ground_duels_won_delta` | Triggered minus opponent ground duels won | Net ground-physical differential |
| `triggered_team_aerial_duels_won` | Aerial duels won by triggered side | Side-level aerial-physical context |
| `opponent_aerial_duels_won` | Aerial duels won by opponent side | Bilateral aerial-duel comparator |
| `aerial_duels_won_delta` | Triggered minus opponent aerial duels won | Net aerial-physical differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Defensive engagement context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line workload context |
| `opponent_keeper_saves` | Saves by opponent goalkeeper | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net shot-stopping workload differential |
| `triggered_team_fouls_committed` | Fouls by triggered side | Discipline and aggression context |
| `opponent_fouls_committed` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context around physical volume |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates physical-duel intensity from clean-sheet outcome |
