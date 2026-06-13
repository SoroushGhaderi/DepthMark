---
signal_id: sig_team_creativity_playmaking_chance_barrage
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Chance Barrage"
trigger: "Team creates >= 15 key passes in a single finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_chance_barrage
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_chance_barrage.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_chance_barrage

## Purpose

Detects team-level playmaking barrages where a side creates at least 15 key passes in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_key_passes >= 15`
  - `match_finished = 1`
  - Match-team rows are emitted per triggered side (`home`, `away`), so both teams can trigger in one match.
- Key-pass and xA volume are aggregated from `silver.player_match_stat` per `match_id + team_id`.
- Bilateral team context is retained from `silver.period_stat` (`period = 'All'`) and `silver.match` to evaluate whether creative overload translated into goals, shot volume, and territorial control.
- Similarity gate note:
  - `sig_team_possession_passing_death_by_passes`: team territorial-dominance signal; this one is explicitly key-pass-volume driven.
  - `sig_team_possession_passing_final_third_efficiency`: team attacking-efficiency signal; this one focuses on raw chance-creation barrage volume.
  - `sig_player_creativity_playmaking_maestro_output`: player-level key-pass volume signal; this one is team-grain aggregation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_chance_barrage.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_chance_barrage`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_chance_barrage
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Time-series slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Team identity for downstream joins |
| `triggered_team_name` | Triggered team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_key_passes` | Trigger floor for key passes (`15`) | Explicit threshold provenance |
| `triggered_team_key_passes` | Triggered team key passes | Core trigger metric |
| `opponent_key_passes` | Opponent team key passes | Bilateral trigger-metric comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net creative-volume edge |
| `triggered_team_expected_assists` | Triggered team aggregated expected assists (xA) | Chance-quality context around key-pass volume |
| `opponent_expected_assists` | Opponent team aggregated expected assists (xA) | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net chance-quality edge from created chances |
| `triggered_team_goals` | Triggered-team full-time goals | Outcome conversion context |
| `opponent_goals` | Opponent full-time goals | Bilateral outcome comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Net scoreline edge |
| `triggered_team_chance_conversion_pct` | Triggered team goals per key pass (%) | Finishing efficiency over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral finishing-efficiency comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net conversion advantage from created chances |
| `triggered_team_total_shots` | Triggered team total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `triggered_team_expected_goals` | Triggered team xG | Shot-quality context |
| `opponent_expected_goals` | Opponent team xG | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent xG | Net shot-quality edge |
| `triggered_team_big_chances` | Triggered team big chances | High-value chance context |
| `opponent_big_chances` | Opponent team big chances | Bilateral high-value chance comparator |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Passing-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Passing-execution baseline |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing-execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team passing quality context |
| `opponent_pass_accuracy_pct` | Opponent team pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality edge |
| `triggered_team_possession_pct` | Triggered team possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control edge |
| `triggered_team_touches_opposition_box` | Triggered team opposition-box touches | Territorial-pressure context |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial-pressure comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure edge |
