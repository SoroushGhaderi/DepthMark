---
signal_id: sig_team_shooting_goals_defensive_scoring_unit
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Defensive Scoring Unit"
trigger: "Team has >= 2 different defenders score non-own goals in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_defensive_scoring_unit
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_defensive_scoring_unit.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_defensive_scoring_unit

## Purpose

Detect team-level matches where defensive players provide distributed scoring output (at least two distinct defender scorers), highlighting dead-ball and back-line attacking contribution patterns.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_distinct_defender_goal_scorers >= 2`
- Defender identity is derived from `silver.match_personnel` via `usual_playing_position_id = 1` with starter-preferred role precedence.
- Scoring events are non-own goals from `silver.shot`; trigger is evaluated separately for home and away sides in finished matches.
- Bilateral output pairs defender-scoring metrics and broader shooting context as `triggered_team_*` versus `opponent_*` columns.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shared_scoring` and `sig_player_shooting_goals_defensive_scorer`; this signal is intentionally distinct because it is team-triggered and requires multi-defender scorer diversity (`>= 2`) rather than all-player spread or single-player defensive scoring.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_defensive_scoring_unit.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_defensive_scoring_unit`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_defensive_scoring_unit
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for deterministic joins and deduplication |
| `match_date` | Match date | Football developer: supports temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity anchor for triggered rows |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_distinct_defender_goal_scorers` | Minimum distinct defender scorers required by trigger (`2`) | Football developer: explicit trigger provenance for governance and QA |
| `triggered_team_distinct_defender_goal_scorers` | Distinct triggered-team defender scorers (non-own goals) | Football developer: core trigger metric |
| `opponent_distinct_defender_goal_scorers` | Distinct opponent defender scorers (non-own goals) | Football developer: bilateral defender-scoring comparator |
| `distinct_defender_goal_scorers_delta` | Triggered minus opponent distinct defender scorers | Football developer: compact side-relative defender-diversity edge |
| `triggered_team_defender_non_own_goals` | Triggered-team non-own goals scored by defenders | Football developer: direct defender-output volume |
| `opponent_defender_non_own_goals` | Opponent non-own goals scored by defenders | Football developer: bilateral defender-output comparator |
| `defender_non_own_goals_delta` | Triggered minus opponent defender non-own goals | Football developer: side-level defender-goal differential |
| `triggered_team_top_defender_scorer_goals` | Max non-own goals by one triggered-team defender scorer | Football developer: concentration diagnostic among defender scorers |
| `opponent_top_defender_scorer_goals` | Max non-own goals by one opponent defender scorer | Football developer: bilateral concentration comparator |
| `top_defender_scorer_goals_delta` | Triggered minus opponent top-defender scorer goals | Football developer: peak defender-scorer imbalance metric |
| `triggered_team_non_own_goals` | Triggered-team total non-own goals | Football developer: denominator context for defender contribution share |
| `opponent_non_own_goals` | Opponent total non-own goals | Football developer: bilateral baseline comparator |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Football developer: side-level goal-output balance |
| `triggered_team_defender_goal_share_pct` | Share of triggered-team non-own goals scored by defenders (%) | Football developer: defender contribution intensity |
| `opponent_defender_goal_share_pct` | Share of opponent non-own goals scored by defenders (%) | Football developer: bilateral defender-share comparator |
| `defender_goal_share_delta_pct` | Triggered minus opponent defender-goal share (percentage points) | Football developer: compact contribution-share differential |
| `triggered_team_goals` | Triggered-team official full-time goals | Football developer: official outcome anchor for scoring analysis |
| `opponent_goals` | Opponent official full-time goals | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: winning-margin context |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: attacking-volume context around defender scoring |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution-quality baseline |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation edge |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
