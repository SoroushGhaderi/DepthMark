---
signal_id: sig_team_shooting_goals_sustained_barrage
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Sustained Barrage"
trigger: "Team records >= 10 shots in a single 15-minute window."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_sustained_barrage
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_sustained_barrage.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_sustained_barrage

## Purpose

Detect team-level shot barrages where one side compresses high attempt volume into a short 15-minute match window.

## Tactical And Statistical Logic

- Trigger condition: triggered side reaches `>= 10` shots inside a 15-minute effective-minute window.
- Window timing uses effective minute (`goal_time + goal_overload_time`, fallback `minute + minute_added`) so stoppage-time shots remain ordered consistently.
- Trigger search is rolling and side-symmetric: for each team, every shot minute is treated as a potential 15-minute window start.
- If multiple windows satisfy the trigger, the signal keeps the highest-shot window, then earliest start minute as deterministic tie-break.
- Enrichment keeps bilateral context for match-level translation checks: window quality (on-target/xG), full-match shot quality, and control/circulation metrics.
- Similarity gate note: closest active signal is `sig_team_shooting_goals_shooting_gallery`; this signal intentionally coexists because it is tempo-concentration-first (10 shots in 15 minutes) rather than full-match volume-first (25+ shots overall).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_sustained_barrage.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_sustained_barrage`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_sustained_barrage
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: analyst-readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: analyst-readable away-side attribution |
| `home_score` | Home final goals | Football developer: scoreline context for barrage interpretation |
| `away_score` | Away final goals | Football developer: scoreline context for barrage interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: primary triggered entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_window_shots` | Trigger threshold for shots in window (`10`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_window_minutes` | Trigger window size in minutes (`15`) | Football developer: explicit rolling-window duration contract |
| `triggered_team_shots_in_trigger_window` | Triggered-team shots inside the selected 15-minute window | Football developer: core trigger metric and burst severity anchor |
| `opponent_shots_in_trigger_window` | Opponent shots inside the same trigger window | Football developer: bilateral tempo comparator for window dominance |
| `shots_in_trigger_window_delta` | Triggered minus opponent shots in trigger window | Football developer: compact net barrage dominance indicator |
| `trigger_window_start_effective_minute` | Effective start minute of selected trigger window | Football developer: deterministic temporal anchor for replay and QA |
| `trigger_window_end_effective_minute` | Effective end minute of selected trigger window | Football developer: explicit window boundary for auditing shot inclusion |
| `triggered_team_first_shot_in_trigger_window_effective_minute` | Earliest triggered-team shot minute inside the selected window | Football developer: verifies where burst shot sequence begins |
| `triggered_team_last_shot_in_trigger_window_effective_minute` | Latest triggered-team shot minute inside the selected window | Football developer: measures burst span tightness and closure |
| `triggered_team_shots_on_target_in_trigger_window` | Triggered-team on-target shots within trigger window | Football developer: window-level execution-quality context |
| `opponent_shots_on_target_in_trigger_window` | Opponent on-target shots within trigger window | Football developer: bilateral execution baseline in same phase |
| `triggered_team_on_target_ratio_in_trigger_window_pct` | Triggered-team on-target ratio (%) within trigger window | Football developer: precision diagnostic for the barrage phase |
| `opponent_on_target_ratio_in_trigger_window_pct` | Opponent on-target ratio (%) within trigger window | Football developer: bilateral precision comparator during burst window |
| `on_target_ratio_in_trigger_window_delta_pct` | Triggered minus opponent on-target ratio (%) in trigger window | Football developer: net window-level shot execution differential |
| `triggered_team_xg_in_trigger_window` | Triggered-team xG accumulated inside trigger window | Football developer: chance-quality total behind burst volume |
| `opponent_xg_in_trigger_window` | Opponent xG accumulated in same trigger window | Football developer: bilateral chance-quality comparator in same phase |
| `xg_in_trigger_window_delta` | Triggered minus opponent xG in trigger window | Football developer: net quality edge during concentrated barrage |
| `triggered_team_total_shots` | Triggered-team full-match total shots | Football developer: links short-window burst to match-level volume profile |
| `opponent_total_shots` | Opponent full-match total shots | Football developer: bilateral full-match shot baseline |
| `total_shots_delta` | Triggered minus opponent full-match total shots | Football developer: net shot dominance beyond the trigger window |
| `triggered_team_shots_on_target` | Triggered-team full-match shots on target | Football developer: full-match shot precision context |
| `opponent_shots_on_target` | Opponent full-match shots on target | Football developer: bilateral full-match precision baseline |
| `triggered_team_on_target_ratio_pct` | Triggered-team full-match on-target ratio (%) | Football developer: full-match execution-quality context |
| `opponent_on_target_ratio_pct` | Opponent full-match on-target ratio (%) | Football developer: bilateral full-match execution comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent full-match on-target ratio (%) | Football developer: net full-match precision differential |
| `triggered_team_xg` | Triggered-team full-match expected goals | Football developer: full-match chance-quality output |
| `opponent_xg` | Opponent full-match expected goals | Football developer: bilateral full-match xG baseline |
| `xg_delta` | Triggered minus opponent full-match expected goals | Football developer: net chance-quality edge at match level |
| `triggered_team_xg_per_shot` | Triggered-team full-match xG per shot | Football developer: average shot quality for triggered side |
| `opponent_xg_per_shot` | Opponent full-match xG per shot | Football developer: bilateral average shot-quality comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context around barrage style |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Football developer: control-profile context for concentrated pressure |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume baseline behind attacking phases |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: passing execution context for pressure sustainability |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net circulation-execution differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: sustained pressure proxy complementary to burst shots |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure baseline |
