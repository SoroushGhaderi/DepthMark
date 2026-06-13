---
signal_id: sig_team_creativity_playmaking_unproductive_flair
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Unproductive Flair"
trigger: "Team completes >= 25 successful dribbles and scores 0 goals in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_unproductive_flair
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_unproductive_flair.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_unproductive_flair

## Purpose

Detect team-level matches where dribbling volume is very high but end-product is absent: the side
completes at least 25 successful dribbles while finishing with zero goals.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_successful_dribbles >= 25`
  - `triggered_team_goals = 0`
  - `match_finished = 1`
- Trigger source:
  - `silver.period_stat.dribbles_succeeded_home` / `silver.period_stat.dribbles_succeeded_away`
    for `period = 'All'`.
- Side orientation:
  - one row per triggered side (`home` / `away`), with explicit opponent mapping.
- Creativity context:
  - key passes and expected assists are enriched via team aggregates from `silver.player_match_stat`
    (`sum(chances_created)`, `sum(expected_assists)`).
- Similarity gate note:
  - `sig_team_creativity_playmaking_dribbling_exhibition` is the closest overlap (successful-dribble
    trigger in the same taxonomy), but this signal adds scoreline failure (`0` goals) and a stricter
    dribble threshold (`25` vs `20`).
  - `sig_team_possession_passing_dribble_heavy_attack` overlaps on dribbling profile but triggers by
    dribble attempts, not successful dribbles with a zero-goal outcome condition.
  - Coexistence rationale: this signal isolates the "high flair, no finishing output" tactical
    profile rather than generic dribbling dominance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_unproductive_flair.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_unproductive_flair`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_unproductive_flair
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and downstream join key |
| `match_date` | Match date | Time slicing and replay reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered team identity for joins and features |
| `triggered_team_name` | Triggered team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_successful_dribbles` | Trigger floor for successful dribbles (`25`) | Explicit threshold provenance and QA traceability |
| `trigger_threshold_max_goals` | Trigger ceiling for triggered-side goals (`0`) | Explicit score-output suppression rule provenance |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered team | Core trigger metric |
| `opponent_successful_dribbles` | Successful dribbles by opponent | Bilateral core-metric comparator |
| `successful_dribbles_delta` | Triggered minus opponent successful dribbles | Net ball-carrying execution edge |
| `triggered_team_dribble_attempts` | Triggered-team dribble attempts | Volume denominator for successful dribble interpretation |
| `opponent_dribble_attempts` | Opponent dribble attempts | Bilateral volume comparator |
| `dribble_attempts_delta` | Triggered minus opponent dribble attempts | Net carry-volume pressure indicator |
| `triggered_team_dribble_success_pct` | Triggered-team dribble success rate (%) | Execution quality around high dribble output |
| `opponent_dribble_success_pct` | Opponent dribble success rate (%) | Bilateral execution-quality comparator |
| `dribble_success_delta_pct` | Triggered minus opponent dribble success rate (%) | Net dribbling-efficiency edge |
| `triggered_team_successful_dribble_share_pct` | Triggered share of both teams' successful dribbles (%) | Normalized dominance indicator beyond raw count |
| `opponent_successful_dribble_share_pct` | Opponent share of both teams' successful dribbles (%) | Bilateral normalization pair |
| `triggered_team_key_passes` | Triggered-team aggregated key passes (`chances_created`) | Creative-output context around dribbling trigger |
| `opponent_key_passes` | Opponent aggregated key passes | Bilateral playmaking comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Indicates whether carries translated into chance creation edge |
| `triggered_team_expected_assists` | Triggered-team aggregated expected assists | Chance-quality context for playmaking outcomes |
| `opponent_expected_assists` | Opponent aggregated expected assists | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creative-quality differential |
| `triggered_team_goals` | Triggered-side goals | Core trigger outcome condition and scoreline context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Net scoreline differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Possession-circulation baseline context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Passing execution numerator context |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Passing-quality context around dribble-led build-up |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-execution differential |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Match-control context around dribbling profile |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control advantage indicator |
| `triggered_team_opposition_half_passes` | Triggered-team completed passes in opposition half | Territorial progression context tied to advanced-phase carries |
| `opponent_opposition_half_passes` | Opponent completed passes in opposition half | Bilateral territorial progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Penetration context behind dribble volume |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third penetration differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume outcome context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-accuracy outcome context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-accuracy comparator |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality outcome context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
