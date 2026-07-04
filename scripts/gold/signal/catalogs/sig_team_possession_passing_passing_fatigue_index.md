---
signal_id: sig_team_possession_passing_passing_fatigue_index
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Passing Fatigue Index"
trigger: "second_half_passes <= 70% of first_half_passes for home or away, excluding carded triggered teams"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_passing_fatigue_index
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_passing_fatigue_index.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_passing_fatigue_index

## Purpose

Triggers when a team's second-half pass volume is at least 30% lower than its first-half pass volume, after excluding triggered teams that received cards.

## Tactical And Statistical Logic

- Trigger condition: `second_half_passes <= 0.70 * first_half_passes` for home or away.
- Card exclusion: triggered team must have `yellow_cards + red_cards = 0` across first and second halves.
- Includes symmetric opponent context for pass volume, pass quality, possession, and xG swing to separate fatigue-like drop-off from game-state trade-offs.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_passing_fatigue_index.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_passing_fatigue_index`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_passing_fatigue_index
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for match-level enrichment and downstream feature assembly |
| `match_date` | Calendar date of the match | Football developer: partition and chronological analysis anchor |
| `home_team_id` | Home team numeric ID | Football developer: preserves canonical match context |
| `home_team_name` | Home team display name | Football developer: human-readable context for QA and analyst inspection |
| `away_team_id` | Away team numeric ID | Football developer: preserves canonical match context |
| `away_team_name` | Away team display name | Football developer: human-readable context for QA and analyst inspection |
| `home_score` | Full-time home goals | Football developer: outcome context for interpreting 2H passing behavior |
| `away_score` | Full-time away goals | Football developer: outcome context for interpreting 2H passing behavior |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: row orientation field for downstream side-aware analytics |
| `triggered_team_id` | Triggered team ID | Football developer: primary team identity for triggered pattern analysis |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered identity for debugging and reports |
| `opponent_team_id` | Opponent team ID | Football developer: required bilateral context for tactical interpretation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context for analyst workflows |
| `trigger_threshold_second_half_pass_drop_pct` | Hard threshold used by the trigger (30.0) | Football developer: explicit trace of rule version for reproducibility |
| `triggered_team_passes_first_half` | Triggered team passes in first half | Football developer: baseline pass volume for fatigue-style drop computation |
| `triggered_team_passes_second_half` | Triggered team passes in second half | Football developer: post-halftime pass volume used by trigger |
| `triggered_team_pass_drop_pct` | Percent drop in triggered-team passes from first half to second half | Football developer: core signal value quantifying drop severity |
| `opponent_passes_first_half` | Opponent passes in first half | Football developer: symmetric control baseline for contextual diagnostics |
| `opponent_passes_second_half` | Opponent passes in second half | Football developer: symmetric control for game-state comparison |
| `opponent_pass_drop_pct` | Percent drop in opponent passes from first half to second half | Football developer: bilateral comparator to avoid one-sided misreads |
| `triggered_team_pass_attempts_first_half` | Triggered team pass attempts in first half | Football developer: denominator for quality/accuracy interpretation |
| `triggered_team_pass_attempts_second_half` | Triggered team pass attempts in second half | Football developer: denominator for second-half quality interpretation |
| `opponent_pass_attempts_first_half` | Opponent pass attempts in first half | Football developer: symmetric denominator for bilateral diagnostics |
| `opponent_pass_attempts_second_half` | Opponent pass attempts in second half | Football developer: symmetric denominator for bilateral diagnostics |
| `triggered_team_pass_accuracy_first_half_pct` | Triggered-team pass accuracy % in first half | Football developer: indicates whether volume drop came with quality decline |
| `triggered_team_pass_accuracy_second_half_pct` | Triggered-team pass accuracy % in second half | Football developer: helps separate fatigue from intentional tempo control |
| `opponent_pass_accuracy_first_half_pct` | Opponent pass accuracy % in first half | Football developer: symmetric quality context field |
| `opponent_pass_accuracy_second_half_pct` | Opponent pass accuracy % in second half | Football developer: symmetric quality context field |
| `triggered_team_possession_first_half_pct` | Triggered-team first-half possession % | Football developer: contextualizes whether high-volume first half drove trigger |
| `triggered_team_possession_second_half_pct` | Triggered-team second-half possession % | Football developer: indicates whether pass drop aligns with possession drop |
| `opponent_possession_first_half_pct` | Opponent first-half possession % | Football developer: bilateral possession context for tactical interpretation |
| `opponent_possession_second_half_pct` | Opponent second-half possession % | Football developer: bilateral possession context for tactical interpretation |
| `triggered_team_total_cards` | Triggered-team total yellow+red cards across halves | Football developer: validates card-exclusion logic at row level |
| `opponent_total_cards` | Opponent total yellow+red cards across halves | Football developer: contextual discipline pressure for match dynamics |
| `triggered_team_red_cards` | Triggered-team red cards across halves | Football developer: high-impact discipline context that can alter tempo |
| `opponent_red_cards` | Opponent red cards across halves | Football developer: bilateral discipline context for causal interpretation |
| `triggered_team_xg_first_half` | Triggered-team xG in first half | Football developer: checks whether first-half passing translated into threat |
| `triggered_team_xg_second_half` | Triggered-team xG in second half | Football developer: reveals whether pass drop reduced chance creation |
| `opponent_xg_first_half` | Opponent xG in first half | Football developer: symmetric attacking output baseline |
| `opponent_xg_second_half` | Opponent xG in second half | Football developer: symmetric attacking output follow-up |
| `xg_swing_delta` | Net xG swing from first half to second half for triggered side | Football developer: summarizes whether momentum shifted with passing fatigue pattern |
