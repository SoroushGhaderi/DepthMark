---
signal_id: sig_team_goalkeeping_defense_defensive_pressure_peak
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Defensive Pressure Peak"
trigger: "Team forces >= 20 opposition turnovers in a single half of a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_defensive_pressure_peak
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_defensive_pressure_peak.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_defensive_pressure_peak

## Purpose

Detect team-level defensive pressure spells where one side forces very high opposition possession losses in a single half, then preserve bilateral defensive, control, and result context.

## Tactical And Statistical Logic

- Trigger condition:
  - finished match (`match_finished = 1`)
  - complete half coverage (`FirstHalf` and `SecondHalf` period rows both present)
  - `triggered_team_turnovers_forced_first_half >= 20` OR `triggered_team_turnovers_forced_second_half >= 20`
- Turnovers-forced proxy is derived from opposition losses: `failed_passes + failed_dribbles`, where failed values are computed as `attempts - successful` with floor at `0`.
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both sides can trigger in the same match.
- `triggered_half_with_turnovers_forced_peak` identifies `FirstHalf`, `SecondHalf`, or `BothHalves` when both pass threshold.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_recovery_dominance`: same family and defensive-intensity intent, but trigger uses full-match recoveries (`>= 60`) rather than half-level forced turnovers.
  - `sig_team_goalkeeping_defense_recovery_marathon`: same axis but stricter full-match recoveries (`>= 80`) instead of a per-half forcing condition.
  - `sig_team_goalkeeping_defense_tackle_volume_surge`: same family and pressure framing, but trigger is full-match tackles won (`>= 25`) rather than opposition turnover forcing in a half.
  - `sig_team_goalkeeping_defense_early_lockdown`: shared phase-specific defensive lens, but trigger is opening shot suppression, not possession-loss forcing.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_defensive_pressure_peak.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_defensive_pressure_peak`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_defensive_pressure_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication key |
| `match_date` | Match date | Temporal slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture attribution |
| `away_team_id` | Away team ID | Bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture attribution |
| `home_score` | Home goals at full time | Scoreline context |
| `away_score` | Away goals at full time | Scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical team-row identity |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identity |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_opposition_turnovers_in_half` | Trigger threshold (`20`) | Explicit trigger provenance |
| `trigger_threshold_required_half_minutes` | Required half duration (`45`) | Makes trigger scope explicit |
| `triggered_half_with_turnovers_forced_peak` | Half label where trigger peaks (`FirstHalf`, `SecondHalf`, `BothHalves`) | Direct tactical timing interpretation |
| `has_first_half_period_row_flag` | 1 when first-half period row exists | Data completeness guard for half trigger |
| `has_second_half_period_row_flag` | 1 when second-half period row exists | Data completeness guard for half trigger |
| `triggered_team_turnovers_forced_first_half` | Opposition turnovers forced by triggered side in first half | Core first-half trigger component |
| `triggered_team_turnovers_forced_second_half` | Opposition turnovers forced by triggered side in second half | Core second-half trigger component |
| `opponent_turnovers_forced_first_half` | Opposition turnovers forced by opponent in first half | Bilateral first-half pressure comparator |
| `opponent_turnovers_forced_second_half` | Opposition turnovers forced by opponent in second half | Bilateral second-half pressure comparator |
| `turnovers_forced_first_half_delta` | Triggered minus opponent first-half turnovers forced | Net first-half pressure differential |
| `turnovers_forced_second_half_delta` | Triggered minus opponent second-half turnovers forced | Net second-half pressure differential |
| `triggered_team_peak_turnovers_forced_in_half` | Triggered-side max turnovers forced across halves | Trigger severity metric |
| `opponent_peak_turnovers_forced_in_half` | Opponent max turnovers forced across halves | Bilateral severity comparator |
| `peak_turnovers_forced_in_half_delta` | Triggered minus opponent peak half turnovers forced | Net peak-pressure differential |
| `triggered_team_turnovers_forced_above_threshold` | Peak turnovers-forced amount above threshold (`value - 20`) | Quantifies trigger margin |
| `triggered_team_turnovers_forced_full_match` | Full-match opposition turnovers forced by triggered side | Full-match pressure context |
| `opponent_turnovers_forced_full_match` | Full-match opposition turnovers forced by opponent side | Bilateral full-match comparator |
| `turnovers_forced_full_match_delta` | Triggered minus opponent full-match turnovers forced | Net full-match pressure differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel pressure output |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral ground-duel comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Contest-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-contest context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive workload denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral workload comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net exposure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Last-line workload context |
| `opponent_keeper_saves` | Keeper saves by opponent side | Bilateral keeper comparator |
| `keeper_saves_delta` | Triggered minus opponent keeper saves | Net keeper workload differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent possession percentage | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control-share differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | On-ball execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Outcome translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 | Separates pressure peak from clean-sheet outcome |
