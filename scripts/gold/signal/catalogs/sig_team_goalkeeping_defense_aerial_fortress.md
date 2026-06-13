---
signal_id: sig_team_goalkeeping_defense_aerial_fortress
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Aerial Fortress"
trigger: "Team wins > 75% of all aerial duels in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_aerial_fortress
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_aerial_fortress.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_aerial_fortress

## Purpose

Detect team-level defensive structures that dominate aerial control by winning more than 75% of all
match aerial duels, then preserve bilateral defensive-pressure, control, and outcome context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_aerial_duels_won_share_pct > 75.0`
  - `match_total_aerial_duels_won > 0`
  - finished-match scope (`match_finished = 1`) with full-match context (`period = 'All'`)
- Aerial share is computed as:
  - `triggered_team_aerials_won / match_total_aerial_duels_won`
  - where `match_total_aerial_duels_won = aerials_won_home + aerials_won_away`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both teams can trigger
  in different matches when they clear the same aerial-dominance threshold.
- Trigger severity is preserved with `triggered_team_aerial_duels_won_share_above_threshold_pct`.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_aerial_battleground`: closest aerial-theme overlap, but that signal
    is match-level and triggered by high *combined* aerial-duel volume, not side-level aerial share.
  - `sig_team_goalkeeping_defense_unbroken_structure`: same family and defensive framing, but trigger
    is low opponent inside-box shots allowed, not aerial-control dominance.
  - `sig_team_goalkeeping_defense_shot_blocking_unit`: same family and bilateral defensive context,
    but trigger axis is shot blocks, not aerial share.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_aerial_fortress.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_aerial_fortress`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_aerial_fortress
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture attribution |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture attribution |
| `home_score` | Home full-time goals | Outcome context for aerial-dominance interpretation |
| `away_score` | Away full-time goals | Outcome context for aerial-dominance interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identifier |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_aerial_duels_won_share_pct` | Minimum aerial-duel share threshold (`75.0%`) | Explicit trigger-rule provenance |
| `match_total_aerial_duels_won` | Total aerial duels won by both sides | Trigger denominator and match-level aerial environment baseline |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Trigger numerator and core aerial-control metric |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial duels won | Net aerial-control differential |
| `triggered_team_aerial_duels_won_share_pct` | Triggered-side share of all aerial duels won (%) | Core trigger metric at team-match grain |
| `opponent_aerial_duels_won_share_pct` | Opponent share of all aerial duels won (%) | Bilateral share comparator |
| `aerial_duels_won_share_delta_pct` | Triggered minus opponent aerial-duel win share (pp) | Net share dominance differential |
| `triggered_team_aerial_duels_won_share_above_threshold_pct` | Triggered-side aerial share above threshold (`share - 75.0`) | Trigger severity beyond activation boundary |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context beyond aerial duels |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net physical-control differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-defense action context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection workload context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure baseline |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net defensive exposure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Triggered-side goalkeeper saves | Last-line defensive workload context |
| `opponent_keeper_saves` | Opponent-side goalkeeper saves | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net goalkeeper workload differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Full-match chance-quality-against baseline |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Compact match-result differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates aerial dominance from clean-sheet outcome |
