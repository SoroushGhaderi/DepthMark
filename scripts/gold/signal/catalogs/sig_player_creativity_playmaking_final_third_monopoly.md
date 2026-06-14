---
signal_id: sig_player_creativity_playmaking_final_third_monopoly
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Final Third Monopoly"
trigger: "Player records >= 30 successful passes in the final third in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_final_third_monopoly
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_final_third_monopoly.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_final_third_monopoly

## Purpose

Detect player-level playmakers who dominate final-third ball progression through very high completed
volume (`>= 30`) in a single finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_successful_final_third_passes >= 30`
- Trigger source:
  - `silver.player_match_stat.passes_final_third` (interpreted as successful final-third passes)
- Finished-match scope and valid side mapping are enforced:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - player team must map to home/away side.
- Bilateral passing, territorial, and control context is retained from `silver.period_stat`
  (`period = 'All'`) for tactical interpretation.
- Similarity gate note:
  - `sig_player_creativity_playmaking_line_breaker` is the closest active creativity/playmaking
    neighbor on `passes_final_third`, but it triggers at a much lower directional proxy threshold
    (`>= 10`) and may fire from team long-ball proxy rather than strict player final-third volume.
  - `sig_player_possession_passing_final_third_engine` has the same core metric family but lower
    threshold (`>= 20`) and possession/passing taxonomy.
  - Coexistence rationale: this signal is a stricter creativity/playmaking concentration variant
    focused on monopoly-grade final-third passing load (`>= 30`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_final_third_monopoly.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_final_third_monopoly`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_final_third_monopoly
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream enrichment and deduplication |
| `match_date` | Match date | Time slicing for trend and backfill analysis |
| `home_team_id` | Home team identifier | Bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Match-outcome context |
| `away_score` | Away full-time goals | Match-outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Human-readable attribution |
| `triggered_team_id` | Triggered player team ID | Player-team linkage for joins |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable opponent context |
| `trigger_threshold_min_successful_final_third_passes` | Trigger floor (`30`) | Explicit trigger provenance and QA visibility |
| `triggered_player_successful_final_third_passes` | Player successful passes into final third | Core monopoly trigger metric |
| `triggered_player_successful_final_third_passes_above_threshold` | Margin above trigger floor (`value - 30`) | Severity context beyond binary trigger |
| `triggered_player_total_passes` | Triggered player total pass attempts | Passing workload denominator context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Execution-quality numerator context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context around high progression load |
| `triggered_player_minutes_played` | Triggered player minutes | Exposure context for interpreting raw volume |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_player_chances_created` | Triggered player chances created | Creative-output context around progression dominance |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Advanced-territory involvement context |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Team circulation baseline for player-share interpretation |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Team passing-quality baseline |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_opposition_half_passes` | Triggered team opposition-half passes | Territorial progression context around the player trigger |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral territorial progression comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Role centrality in overall team circulation |
| `player_share_of_team_opposition_half_passes_pct` | Triggered player final-third passes as % of team opposition-half passes | Concentration context for monopoly framing |
