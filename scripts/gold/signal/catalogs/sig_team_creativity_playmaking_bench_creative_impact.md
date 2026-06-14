---
signal_id: sig_team_creativity_playmaking_bench_creative_impact
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Bench Creative Impact"
trigger: "Substitutes provide >= 2 key passes and >= 1 assist for a team in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_bench_creative_impact
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_bench_creative_impact.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_bench_creative_impact

## Purpose

Detect team matches where substitute players jointly deliver meaningful creative production (at least two key passes and at least one assist), highlighting bench-driven chance creation and conversion impact.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_substitute_key_passes >= 2`
  - `triggered_team_substitute_assists >= 1`
  - `match_finished = 1`
- Substitute identity is sourced from `silver.match_personnel` (`role = 'substitute'`, `substitution_time > 0`) and joined to `silver.player_match_stat` to aggregate substitute playmaking outputs.
- Trigger is evaluated independently for home and away sides, so both sides can trigger in the same match.
- Bilateral context includes substitute and full-team key-pass/assist volume, substitute-share rates, plus passing, territory, and shooting context from `silver.period_stat` (`period = 'All'`).
- Similarity gate note: closest active team-creativity signals are `sig_team_creativity_playmaking_chance_barrage` and `sig_team_creativity_playmaking_total_fluidity`. This signal coexists as the substitute-specific variant: it requires bench-originated key-passing plus direct assisted-goal output, while the existing signals capture overall team chance-creation volume and creator spread regardless of starter/substitute split.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_bench_creative_impact.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_bench_creative_impact`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_bench_creative_impact
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and downstream join anchor |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Triggered entity key for joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_substitute_key_passes` | Minimum substitute key-pass threshold (`2`) | Explicit trigger governance |
| `trigger_threshold_min_substitute_assists` | Minimum substitute assist threshold (`1`) | Explicit trigger governance |
| `triggered_team_substitute_key_passes` | Triggered-team substitute key passes | Core creative-volume trigger input |
| `opponent_substitute_key_passes` | Opponent substitute key passes | Bilateral bench-creation comparator |
| `substitute_key_passes_delta` | Triggered minus opponent substitute key passes | Side-relative bench-creation edge |
| `triggered_team_substitute_assists` | Triggered-team substitute assists | Core direct-output trigger input |
| `opponent_substitute_assists` | Opponent substitute assists | Bilateral bench-output comparator |
| `substitute_assists_delta` | Triggered minus opponent substitute assists | Side-relative bench-assist edge |
| `triggered_team_substitute_expected_assists` | Triggered-team substitute expected assists | Bench chance-quality context |
| `opponent_substitute_expected_assists` | Opponent substitute expected assists | Bilateral bench chance-quality comparator |
| `substitute_expected_assists_delta` | Triggered minus opponent substitute expected assists | Net bench chance-quality edge |
| `triggered_team_distinct_substitute_key_pass_creators` | Number of triggered-team substitutes with at least one key pass | Bench creator breadth diagnostic |
| `opponent_distinct_substitute_key_pass_creators` | Number of opponent substitutes with at least one key pass | Bilateral creator breadth comparator |
| `distinct_substitute_key_pass_creators_delta` | Triggered minus opponent distinct substitute key-pass creators | Side-relative creator-distribution edge |
| `triggered_team_distinct_substitute_assist_providers` | Number of triggered-team substitutes with at least one assist | Bench assist-provider spread |
| `opponent_distinct_substitute_assist_providers` | Number of opponent substitutes with at least one assist | Bilateral assist-provider spread comparator |
| `distinct_substitute_assist_providers_delta` | Triggered minus opponent distinct substitute assist providers | Side-relative assist-provider distribution edge |
| `triggered_team_top_substitute_key_passes` | Max key passes by one triggered-team substitute | Bench-creation concentration signal |
| `opponent_top_substitute_key_passes` | Max key passes by one opponent substitute | Bilateral concentration comparator |
| `top_substitute_key_passes_delta` | Triggered minus opponent top substitute key passes | Concentration edge around primary bench creator |
| `triggered_team_total_key_passes` | Triggered-team total key passes | Full-team creativity baseline |
| `opponent_total_key_passes` | Opponent total key passes | Bilateral creativity baseline comparator |
| `total_key_passes_delta` | Triggered minus opponent total key passes | Net team creativity edge |
| `triggered_team_total_assists` | Triggered-team total assists | Full-team direct-creation baseline |
| `opponent_total_assists` | Opponent total assists | Bilateral direct-creation comparator |
| `total_assists_delta` | Triggered minus opponent total assists | Net direct-output edge |
| `triggered_team_total_expected_assists` | Triggered-team total expected assists | Team chance-quality baseline |
| `opponent_total_expected_assists` | Opponent total expected assists | Bilateral chance-quality baseline comparator |
| `total_expected_assists_delta` | Triggered minus opponent total expected assists | Net team chance-quality edge |
| `triggered_team_substitute_key_pass_share_pct` | Share of triggered-team key passes produced by substitutes (%) | Normalized bench creativity dependence |
| `opponent_substitute_key_pass_share_pct` | Share of opponent key passes produced by substitutes (%) | Bilateral normalized comparator |
| `substitute_key_pass_share_delta_pct` | Triggered minus opponent substitute key-pass share (percentage points) | Compact dependence differential |
| `triggered_team_substitute_assist_share_pct` | Share of triggered-team assists supplied by substitutes (%) | Normalized bench direct-output dependence |
| `opponent_substitute_assist_share_pct` | Share of opponent assists supplied by substitutes (%) | Bilateral normalized comparator |
| `substitute_assist_share_delta_pct` | Triggered minus opponent substitute assist share (percentage points) | Compact bench-assist dependence differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Passing-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Passing-execution context |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing-execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team passing-quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net passing-quality edge |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure edge |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality edge |
| `triggered_team_goals` | Triggered-team full-time goals | Outcome context |
| `opponent_goals` | Opponent full-time goals | Bilateral outcome comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Net scoreline edge |
