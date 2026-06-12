---
signal_id: sig_team_shooting_goals_rapid_double_salvo
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Rapid Double Salvo"
trigger: "Team scores two non-own goals within 120 seconds of each other (effective-minute proxy: gap <= 2) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_rapid_double_salvo
  sql: clickhouse/gold/signal/sig_team_shooting_goals_rapid_double_salvo.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_rapid_double_salvo.py
---
# sig_team_shooting_goals_rapid_double_salvo

## Purpose

Detect team-level explosive scoring bursts where the same side scores twice in rapid succession,
capturing momentum spikes and conversion surges.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goals from `silver.shot` (`is_goal = 1`, `is_own_goal = 0`).
  - For each side, adjacent goals in that side's own goal sequence have effective-minute gap `<= 2`.
  - At least one qualifying pair is required (`triggered_team_rapid_double_salvo_pairs >= 1`).
- Timing logic:
  - Effective minute uses `goal_time + goal_overload_time` (fallback `minute + minute_added`).
  - The requested 120-second window is implemented as a minute-granularity proxy (`<= 2` effective minutes).
  - First and last qualifying salvo timings plus gap summaries are retained for sequence diagnostics.
- Match-context enrichment:
  - Bilateral team metrics come from `silver.period_stat` (`period = 'All'`) and final score context from `silver.match`.
  - Output stays side-oriented at `match_team` grain and allows both sides to trigger in one match.
- Similarity gate note:
  - Closest active signals are `sig_team_shooting_goals_rapid_response_goal` and `sig_team_shooting_goals_early_blitz`.
  - This signal is distinct because it tracks same-team consecutive-goal burst speed anywhere in match time, not concession-response behavior or first-15-window volume.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_rapid_double_salvo.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_rapid_double_salvo.py`
- Target table: `gold_signals.sig_team_shooting_goals_rapid_double_salvo`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_rapid_double_salvo.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join and deduplication key |
| `match_date` | Match date | Football developer: temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time score | Football developer: final-score context around trigger |
| `away_score` | Away full-time score | Football developer: final-score context around trigger |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: side-oriented identity anchor |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_max_double_salvo_window_minutes` | Maximum allowed gap between two team goals (`2`) | Football developer: explicit trigger boundary and 120-second proxy |
| `trigger_threshold_min_rapid_double_salvo_pairs` | Minimum qualifying pair count (`1`) | Football developer: explicit activation threshold |
| `triggered_team_rapid_double_salvo_pairs` | Number of qualifying same-team rapid goal pairs | Football developer: core trigger intensity metric |
| `opponent_rapid_double_salvo_pairs` | Opponent qualifying rapid-goal pair count | Football developer: bilateral comparator |
| `rapid_double_salvo_pairs_delta` | Triggered minus opponent rapid-goal pair count | Football developer: net burst edge diagnostic |
| `triggered_team_first_salvo_first_goal_minute` | Base minute of first goal in earliest qualifying salvo | Football developer: first burst sequence anchor |
| `triggered_team_first_salvo_first_goal_added_time` | Added-time component of first goal in earliest salvo | Football developer: stoppage-time precision |
| `triggered_team_first_salvo_first_goal_effective_minute` | Effective minute of first goal in earliest qualifying salvo | Football developer: normalized chronology key |
| `triggered_team_first_salvo_second_goal_minute` | Base minute of second goal in earliest qualifying salvo | Football developer: trigger completion timing anchor |
| `triggered_team_first_salvo_second_goal_added_time` | Added-time component of second goal in earliest salvo | Football developer: stoppage-time precision |
| `triggered_team_first_salvo_second_goal_effective_minute` | Effective minute of second goal in earliest qualifying salvo | Football developer: deterministic trigger timestamp |
| `minutes_between_first_salvo_goals` | Effective-minute gap between goals in earliest qualifying salvo | Football developer: primary burst-speed measure |
| `triggered_team_smallest_salvo_gap_minutes` | Smallest qualifying salvo gap for triggered side | Football developer: best-case burst intensity |
| `triggered_team_average_salvo_gap_minutes` | Average gap across triggered-side qualifying salvos | Football developer: stable side-level burst-speed baseline |
| `opponent_average_salvo_gap_minutes` | Opponent average qualifying salvo gap | Football developer: bilateral burst-speed benchmark |
| `average_salvo_gap_delta_minutes` | Triggered minus opponent average salvo gap | Football developer: net burst-speed differential |
| `triggered_team_last_salvo_second_goal_effective_minute` | Effective minute of second goal in latest qualifying salvo | Football developer: persistence of rapid-burst behavior |
| `rapid_double_salvo_window_margin_minutes` | Margin to threshold (`2 - earliest salvo gap`) | Football developer: closeness/severity diagnostic |
| `triggered_team_rapid_double_salvo_pairs_above_threshold` | Pair count above minimum (`count - 1`) | Football developer: intensity grading beyond binary activation |
| `triggered_team_goals_final` | Triggered team full-time goals | Football developer: outcome context for rapid-burst events |
| `opponent_goals_final` | Opponent full-time goals | Football developer: bilateral scoreline comparator |
| `goal_delta_final` | Triggered minus opponent full-time goals | Football developer: side-relative outcome edge |
| `triggered_team_total_shots` | Triggered team total shots | Football developer: shooting-volume context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net pressure indicator |
| `triggered_team_shots_on_target` | Triggered team shots on target | Football developer: execution context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_on_target_ratio_pct` | Triggered team shots-on-target ratio (%) | Football developer: finishing precision proxy |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio (%) | Football developer: bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Football developer: compact precision differential |
| `triggered_team_xg` | Triggered team expected goals | Football developer: chance-quality production context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation edge |
| `triggered_team_big_chances` | Triggered team big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Triggered team big chances missed | Football developer: wastefulness context around burst events |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral wastefulness comparator |
| `triggered_team_possession_pct` | Triggered team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Football developer: circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Football developer: retention/execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact retention differential |
| `triggered_team_corners` | Triggered team corners | Football developer: sustained pressure proxy |
| `opponent_corners` | Opponent corners | Football developer: bilateral pressure comparator |
