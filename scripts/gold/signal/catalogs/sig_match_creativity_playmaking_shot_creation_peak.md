---
signal_id: sig_match_creativity_playmaking_shot_creation_peak
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Shot Creation Peak"
trigger: "Match averages at least one shot every 3 minutes (`match_total_shots >= 30` over a 90-minute reference window)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_shot_creation_peak
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_shot_creation_peak.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_shot_creation_peak

## Purpose

Detect finished matches with extreme shot-creation tempo (one shot every 3 minutes or faster),
then preserve bilateral playmaking and execution context per side.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_total_shots >= 30` over a 90-minute reference window.
  - Equivalent expression: `match_minutes_per_shot <= 3.0`.
- Trigger source:
  - Shot volume and match execution context come from `silver.period_stat` (`period = 'All'`).
  - Team key passes and expected assists are aggregated from `silver.player_match_stat`.
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row for `home` and one row for `away` (`match_team` grain).
- Similarity gate note:
  - `sig_match_creativity_playmaking_big_chance_fest` is chance-value-volume driven (`big chances > 8`), while this signal is pure shot-creation tempo.
  - `sig_match_creativity_playmaking_unproductive_beauty` blends dribbles + key passes + no-goal outcome, while this signal is shot-frequency focused regardless of outcome.
  - `sig_match_shooting_goals_shot_efficiency_parity` is finishing-balance logic, while this signal focuses on creation pace.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_shot_creation_peak.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_shot_creation_peak`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_shot_creation_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and join anchor |
| `match_date` | Match date | Time slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side identity for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_max_minutes_per_shot` | Maximum allowed minutes per shot threshold (`3.0`) | Makes trigger boundary explicit for QA |
| `trigger_threshold_min_match_total_shots` | Minimum combined shots threshold (`30`) | Equivalent trigger provenance over 90 minutes |
| `match_reference_minutes` | Reference duration used for pace calculation (`90`) | Ensures deterministic tempo interpretation |
| `match_total_shots` | Combined shots by both teams | Core trigger metric |
| `match_minutes_per_shot` | Minutes per shot across the match | Direct pace interpretability metric |
| `match_shots_per_90_minutes` | Shot rate normalized to 90 minutes | Normalized intensity comparator |
| `match_total_goals` | Combined goals in the match | Outcome context vs creation pace |
| `triggered_team_total_shots` | Triggered-side total shots | Side-level shot volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential |
| `triggered_team_shot_share_pct` | Triggered-side share of match shots (%) | Normalized shot contribution |
| `opponent_shot_share_pct` | Opponent share of match shots (%) | Bilateral normalized comparator |
| `shot_share_delta_pct` | Triggered minus opponent shot share (%) | Directional shot-control differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target pressure differential |
| `triggered_team_shot_accuracy_pct` | Triggered-side shot accuracy (%) | Finishing execution quality context |
| `opponent_shot_accuracy_pct` | Opponent shot accuracy (%) | Bilateral finishing comparator |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (%) | Net finishing execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_expected_goals_per_shot` | Triggered-side xG per shot | Average chance quality per attempt |
| `opponent_expected_goals_per_shot` | Opponent xG per shot | Bilateral per-shot quality comparator |
| `expected_goals_per_shot_delta` | Triggered minus opponent xG per shot | Net per-shot quality differential |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity-volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-construction differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity-quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Outcome context |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution-quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
