---
signal_id: sig_match_goalkeeping_defense_offside_frenzy
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Offside Frenzy"
trigger: "Combined match offsides exceed 10."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_goalkeeping_defense_offside_frenzy
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_offside_frenzy.sql
  runner: scripts/gold/signal/runners/sig_match_goalkeeping_defense_offside_frenzy.py
---
# sig_match_goalkeeping_defense_offside_frenzy

## Purpose

Detects finished matches with extreme combined offside volume and emits side-oriented rows so
offside burden, defensive workload, control context, and outcomes remain symmetric for analysis.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(offsides_home, 0) + coalesce(offsides_away, 0)) > 10` from `silver.period_stat` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `triggered_side = 'away'`) to preserve canonical `match_team` orientation.
- Severity is exposed via `match_total_offsides_above_threshold = match_total_offsides - 10`, and side balance is exposed via `match_offside_balance_abs`.
- Offside context is bilateral using both committed and caught perspectives (`triggered_team_offsides_committed` and `triggered_team_offsides_caught`) plus share/delta fields.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_tackle_war`: same entity/family/subfamily and match-level framing, but trigger axis is combined tackles, not offsides.
  - `sig_team_goalkeeping_defense_offside_trap_mastery`: same offside-trap intent dimension, but that signal is team-triggered (`triggered_team_offsides_caught >= 6`) rather than match-triggered on combined offsides.
  - `sig_match_discipline_cards_stop_start_hell`: includes offsides in a whistle-chaos composite trigger, while this signal isolates offside intensity itself.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_offside_frenzy.sql`
- Runner: `scripts/gold/signal/runners/sig_match_goalkeeping_defense_offside_frenzy.py`
- Target table: `gold.sig_match_goalkeeping_defense_offside_frenzy`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_goalkeeping_defense_offside_frenzy.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal analysis and backfill reproducibility |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home goals at full time | Outcome context |
| `away_score` | Away goals at full time | Outcome context |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_combined_offsides` | Combined offside threshold baseline (`10`) | Explicit trigger provenance |
| `match_total_offsides` | Combined offsides (`home + away`) | Core trigger metric |
| `match_total_offsides_above_threshold` | Combined offsides above threshold | Trigger severity context |
| `match_offside_balance_abs` | Absolute offside gap between sides | Distinguishes balanced frenzy from one-sided burden |
| `triggered_team_offsides_committed` | Offsides committed by triggered side | Side-level offside burden |
| `opponent_offsides_committed` | Offsides committed by opponent side | Bilateral burden comparator |
| `offsides_committed_delta` | Triggered minus opponent offsides committed | Net burden differential |
| `triggered_team_offsides_share_pct` | Triggered-side share of combined offsides (%) | Normalized contribution context |
| `opponent_offsides_share_pct` | Opponent share of combined offsides (%) | Symmetric normalized comparator |
| `offsides_share_delta_pct` | Triggered minus opponent offside share (pp) | Net normalized burden differential |
| `triggered_team_offsides_caught` | Opponent offsides drawn against triggered side | Defensive-line/offside-trap output context |
| `opponent_offsides_caught` | Opponent's offsides drawn against triggered side | Bilateral offside-trap comparator |
| `offsides_caught_delta` | Triggered minus opponent offsides caught | Net offside-trap differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line workload context |
| `opponent_keeper_saves` | Saves by opponent goalkeeper | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net shot-stopping workload differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-defensive activity context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral duel comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial differential |
| `triggered_team_fouls_committed` | Fouls by triggered side | Discipline and aggression context |
| `opponent_fouls_committed` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Control-state context |
| `opponent_possession_pct` | Possession share of opponent side (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates offside frenzy from clean-sheet outcome |
