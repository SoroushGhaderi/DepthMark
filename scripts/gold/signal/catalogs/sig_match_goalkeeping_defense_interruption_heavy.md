---
signal_id: sig_match_goalkeeping_defense_interruption_heavy
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Interruption Heavy"
trigger: "Combined fouls and offsides exceed 40 (fragmented play)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_interruption_heavy
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_interruption_heavy.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_goalkeeping_defense_interruption_heavy

## Purpose

Detect finished matches where whistle-driven fragmentation is extreme, using a joint fouls-plus-offsides trigger, and emit side-oriented bilateral context for defensive workload, control state, and outcomes.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(fouls_home, 0) + coalesce(fouls_away, 0) + coalesce(offsides_home, 0) + coalesce(offsides_away, 0)) > 40` from `silver.period_stat` at `period = 'All'`.
- Only finished matches are included (`silver.match.match_finished = 1`) with valid `match_id > 0`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Trigger severity is exposed by `match_total_fouls_and_offsides_above_threshold = match_total_fouls_and_offsides - 40`, while side symmetry is captured by `match_interruption_balance_abs` and side share/delta metrics.
- Enrichment preserves bilateral defensive and control interpretability with tackles, interceptions, clearances, duels, shots faced, goalkeeper saves, possession, pass accuracy, and scoreline context.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_offside_frenzy`: closest goalkeeping-defense overlap on interruption style, but that signal isolates combined offsides only.
  - `sig_match_discipline_cards_stop_start_hell`: closest fragmented-play overlap, but it is discipline/cards family and uses card + foul + offside composition rather than a goalkeeping-defense interruption aggregate.
  - `sig_match_discipline_cards_battle_of_attrition`: high-foul overlap exists, but this signal intentionally adds offside volume to model broader stop-start fragmentation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_interruption_heavy.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_interruption_heavy`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_interruption_heavy
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
| `home_score` | Home full-time goals | Outcome context for fragmentation-heavy matches |
| `away_score` | Away full-time goals | Outcome context for fragmentation-heavy matches |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_fouls_and_offsides` | Configured interruption threshold baseline (`40`) | Explicit trigger provenance for QA and reproducibility |
| `match_total_fouls_and_offsides` | Combined interruption events (`fouls + offsides`) across both teams | Core fragmented-play trigger metric |
| `match_total_fouls_and_offsides_above_threshold` | Combined interruptions above threshold (`value - 40`) | Trigger severity beyond binary activation |
| `match_total_fouls_committed` | Combined fouls in match | Decomposes interruption source into contact-driven stoppages |
| `match_total_offsides` | Combined offsides in match | Decomposes interruption source into line-breaking/line-control stoppages |
| `match_interruption_balance_abs` | Absolute side gap in interruption events | Distinguishes balanced fragmentation from one-sided burden |
| `triggered_team_interruption_events` | Triggered-side fouls plus offsides | Side-level contribution to total fragmentation |
| `opponent_interruption_events` | Opponent fouls plus offsides | Bilateral interruption comparator |
| `interruption_events_delta` | Triggered minus opponent interruption events | Net fragmented-play burden differential |
| `triggered_team_interruption_events_share_pct` | Triggered-side share of total interruption events (%) | Normalized contribution context |
| `opponent_interruption_events_share_pct` | Opponent share of total interruption events (%) | Symmetric normalized comparator |
| `interruption_events_share_delta_pct` | Triggered minus opponent interruption share (pp) | Compact normalized fragmentation asymmetry |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Contact component of side-level fragmentation |
| `opponent_fouls_committed` | Fouls committed by opponent side | Bilateral foul comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net contact-driven interruption differential |
| `triggered_team_offsides_committed` | Offsides committed by triggered side | Timing/line-control component of side-level fragmentation |
| `opponent_offsides_committed` | Offsides committed by opponent side | Bilateral offside comparator |
| `offsides_committed_delta` | Triggered minus opponent offsides | Net offside-driven interruption differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Defensive engagement context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackle comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackle differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical contest context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line workload context |
| `opponent_keeper_saves` | Saves by opponent goalkeeper | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net shot-stopping workload differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context around fragmentation |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates interruption intensity from clean-sheet outcome |
