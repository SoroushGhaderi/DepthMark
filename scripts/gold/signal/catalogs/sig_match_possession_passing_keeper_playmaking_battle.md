---
signal_id: sig_match_possession_passing_keeper_playmaking_battle
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Keeper Playmaking Battle"
trigger: "Both goalkeepers record >40 passes each in a single finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_keeper_playmaking_battle
  sql: clickhouse/gold/dml/signals/match/sig_match_possession_passing_keeper_playmaking_battle.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_keeper_playmaking_battle

## Purpose

Triggers when both sides’ goalkeepers exceed high pass volume in the same match, surfacing goalkeeper-driven circulation battles where build-up is heavily routed through the last line.

## Tactical And Statistical Logic

- Trigger condition: home goalkeeper pass attempts `> 40` and away goalkeeper pass attempts `> 40`.
- Goalkeeper identity per team is selected as the goalkeeper with the maximum `total_passes` in that match.
- Emits one row per side (`triggered_side` = `home` and `away`) so the same match trigger can be consumed in team-oriented downstream models.
- Enriches with bilateral goalkeeper efficiency and share-of-team-passing, plus team pass/possession/own-half/long-ball context to separate controlled build-up duels from forced recycling.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_possession_passing_keeper_playmaking_battle.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_keeper_playmaking_battle`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_keeper_playmaking_battle
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across gold signals, scenarios, and serving layers. |
| `match_date` | Match calendar date | Football developer: supports temporal slicing and backtests. |
| `home_team_id` | Home team numeric ID | Football developer: fixture orientation and identity recovery. |
| `home_team_name` | Home team display name | Football developer: analyst-readable fixture context. |
| `away_team_id` | Away team numeric ID | Football developer: fixture orientation and identity recovery. |
| `away_team_name` | Away team display name | Football developer: analyst-readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for keeper-led build-up matches. |
| `away_score` | Full-time away goals | Football developer: outcome context for keeper-led build-up matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain signals. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-specific key for downstream team features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral matchup context. |
| `triggered_goalkeeper_player_id` | Triggered-side goalkeeper player ID | Football developer: keeper identity behind the trigger. |
| `triggered_goalkeeper_player_name` | Triggered-side goalkeeper name | Football developer: readable keeper identity for tactical interpretation. |
| `opponent_goalkeeper_player_id` | Opponent goalkeeper player ID | Football developer: bilateral keeper identity comparator. |
| `opponent_goalkeeper_player_name` | Opponent goalkeeper name | Football developer: bilateral keeper identity comparator. |
| `triggered_goalkeeper_pass_attempts` | Triggered-side goalkeeper total passes | Football developer: direct trigger input for keeper playmaking volume. |
| `opponent_goalkeeper_pass_attempts` | Opponent goalkeeper total passes | Football developer: bilateral trigger confirmation and comparator. |
| `triggered_goalkeeper_accurate_passes` | Triggered-side goalkeeper accurate passes | Football developer: execution-quality context for keeper volume. |
| `opponent_goalkeeper_accurate_passes` | Opponent goalkeeper accurate passes | Football developer: bilateral execution-quality comparator. |
| `triggered_goalkeeper_pass_accuracy_pct` | Triggered-side goalkeeper pass accuracy (%) | Football developer: keeps trigger interpretation quality-aware, not volume-only. |
| `opponent_goalkeeper_pass_accuracy_pct` | Opponent goalkeeper pass accuracy (%) | Football developer: bilateral quality comparator across both keepers. |
| `triggered_goalkeeper_share_of_team_passes_pct` | Triggered-side goalkeeper share of team pass attempts (%) | Football developer: quantifies how central the keeper was to team circulation. |
| `opponent_goalkeeper_share_of_team_passes_pct` | Opponent goalkeeper share of opponent team pass attempts (%) | Football developer: bilateral share-of-build-up comparator. |
| `match_total_goalkeeper_pass_attempts` | Combined pass attempts by both goalkeepers | Football developer: compact match-level intensity metric for keeper involvement. |
| `match_total_goalkeeper_accurate_passes` | Combined accurate passes by both goalkeepers | Football developer: quality-adjusted total keeper circulation output. |
| `match_goalkeeper_pass_accuracy_pct` | Combined goalkeeper pass accuracy in the match (%) | Football developer: match-level execution lens for keeper playmaking battles. |
| `goalkeeper_pass_attempt_delta` | Triggered goalkeeper passes minus opponent goalkeeper passes | Football developer: net keeper involvement advantage/disadvantage indicator. |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: team circulation baseline around keeper passing load. |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral team-volume comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: team-level passing quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral team-level quality comparator. |
| `triggered_team_own_half_passes` | Triggered-side own-half passes | Football developer: depth of build-up context for keeper involvement. |
| `opponent_own_half_passes` | Opponent own-half passes | Football developer: bilateral depth-of-build-up comparator. |
| `triggered_team_long_ball_attempts` | Triggered-side long-ball attempts | Football developer: helps distinguish short build-up from direct release patterns. |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Football developer: bilateral directness comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context around keeper-centric playmaking. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
