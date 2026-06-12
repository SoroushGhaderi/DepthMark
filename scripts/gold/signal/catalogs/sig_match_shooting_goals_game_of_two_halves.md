---
signal_id: sig_match_shooting_goals_game_of_two_halves
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Game Of Two Halves"
trigger: "0 goals in FirstHalf; >= 4 goals in SecondHalf."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_game_of_two_halves
  sql: clickhouse/gold/signal/sig_match_shooting_goals_game_of_two_halves.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_game_of_two_halves.py
---
# sig_match_shooting_goals_game_of_two_halves

## Purpose

Flag matches that are scoreless before halftime but turn into high-scoring second-half contests, then expose side-oriented goal-flow, shooting efficiency, and control context for tactical interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_total_first_half_goals = 0`
  - `match_total_second_half_goals >= 4`
- Half-goal counts come from `silver.shot` goal events with `period in {'FirstHalf', 'SecondHalf'}` and home/away attribution via `is_home_goal`.
- Triggered matches emit two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment combines half-level scoring decomposition (`second_half_goals_above_threshold`, second-half side shares) with bilateral shooting and possession context for explainability.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_end_to_end_drama` and `sig_match_shooting_goals_goal_fest`; this signal is distinct because it requires a strict half-split structure (goalless first half plus second-half surge), not bilateral scoring in each half or only high aggregate goals.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_game_of_two_halves.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_game_of_two_halves.py`
- Target table: `gold_signals.sig_match_shooting_goals_game_of_two_halves`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_game_of_two_halves.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and release QA. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Final score context around the halftime-to-fulltime swing. |
| `away_score` | Full-time away goals | Final score context around the halftime-to-fulltime swing. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key for downstream analysis. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_max_first_half_goals` | Maximum allowed first-half total goals (`0`) | Explicit trigger provenance for reproducibility and QA. |
| `trigger_threshold_min_second_half_goals` | Minimum required second-half total goals (`4`) | Explicit trigger provenance for reproducibility and QA. |
| `home_first_half_goals` | Home goals in first half | Raw trigger-input transparency for first-half condition. |
| `away_first_half_goals` | Away goals in first half | Raw trigger-input transparency for first-half condition. |
| `home_second_half_goals` | Home goals in second half | Raw trigger-input transparency for second-half surge condition. |
| `away_second_half_goals` | Away goals in second half | Raw trigger-input transparency for second-half surge condition. |
| `match_total_first_half_goals` | Combined first-half goals | Trigger axis confirming pre-halftime scorelessness. |
| `match_total_second_half_goals` | Combined second-half goals | Trigger axis quantifying post-halftime scoring burst. |
| `match_total_goals` | Combined goals across both halves | Overall match scoring load for ranking and filtering. |
| `half_goal_intensity_delta` | Second-half goals minus first-half goals | Compact measure of halftime-to-fulltime scoring acceleration. |
| `second_half_goals_above_threshold` | Surplus above second-half trigger minimum (`second_half_goals - 4`) | Severity ranking beyond binary trigger activation. |
| `triggered_team_first_half_goals` | Triggered-side first-half goals | Side-oriented first-half contribution context. |
| `opponent_first_half_goals` | Opponent first-half goals | Bilateral first-half comparator context. |
| `triggered_team_second_half_goals` | Triggered-side second-half goals | Side-oriented contribution to the post-halftime surge. |
| `opponent_second_half_goals` | Opponent second-half goals | Bilateral comparator for second-half contribution. |
| `triggered_team_second_half_goal_share_pct` | Triggered-side share of second-half goals (%) | Normalized side contribution to surge intensity. |
| `opponent_second_half_goal_share_pct` | Opponent share of second-half goals (%) | Symmetric normalized comparator. |
| `second_half_goal_share_delta_pct` | Triggered minus opponent second-half goal share (percentage points) | Compact balance diagnostic for second-half scoring ownership. |
| `triggered_team_total_shots` | Triggered-side total shots (`period = 'All'`) | Shot-volume context behind surge matches. |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shot-volume comparator. |
| `total_shots_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shooting precision context for triggered side. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Tactical diagnostic for precision edge. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-creation differential. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context for triggered side. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context in high-event second halves. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context for match-state interpretation. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential for tactical profiling. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical ball-progression quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Execution-quality differential for diagnostics and modeling. |
