---
signal_id: sig_match_shooting_goals_end_to_end_drama
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "End-To-End Drama"
trigger: "Both teams score in both halves (FirstHalf and SecondHalf goals >= 1 for home and away)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_end_to_end_drama
  sql: clickhouse/gold/signal/sig_match_shooting_goals_end_to_end_drama.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_end_to_end_drama.py
---
# sig_match_shooting_goals_end_to_end_drama

## Purpose

Flag high-volatility matches where each side scores in both halves, then expose side-oriented half-by-half scoring plus shooting and control context to explain whether the bilateral goal flow came from sustained chance quality, shot volume, or finishing variance.

## Tactical And Statistical Logic

- Trigger condition:
  - `home_first_half_goals >= 1`
  - `away_first_half_goals >= 1`
  - `home_second_half_goals >= 1`
  - `away_second_half_goals >= 1`
- Half-goal counts are derived from `silver.shot` goal events with `period in {'FirstHalf', 'SecondHalf'}` and side attribution from `is_home_goal`.
- Emits two rows per triggered match (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment emphasizes half-level scoring symmetry and bilateral shooting context (`total_shots`, `shots_on_target`, `shot_accuracy_pct`, `xg`, `shot_conversion_pct`) with possession and pass-quality context for tactical interpretation.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_goal_fest` and `sig_match_shooting_goals_basketball_match`; this signal is distinct because trigger activation requires bilateral half-by-half scoring structure, not only aggregate goals or aggregate shot volume.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_end_to_end_drama.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_end_to_end_drama.py`
- Target table: `gold_signals.sig_match_shooting_goals_end_to_end_drama`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_end_to_end_drama.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and QA checks. |
| `match_date` | Match date | Supports reproducible backfills and temporal analysis. |
| `home_team_id` | Home team identifier | Preserves full fixture context for bilateral interpretation. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context for bilateral interpretation. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context around the bilateral half-scoring trigger. |
| `away_score` | Full-time away goals | Scoreline context around the bilateral half-scoring trigger. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key for downstream models. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_goals_per_team_per_half` | Configured minimum goals per team per half (`1`) | Explicit trigger provenance for explainability and QA. |
| `home_first_half_goals` | Home goals in first half | Raw trigger input transparency for first-half scoring condition. |
| `away_first_half_goals` | Away goals in first half | Raw trigger input transparency for first-half scoring condition. |
| `home_second_half_goals` | Home goals in second half | Raw trigger input transparency for second-half scoring condition. |
| `away_second_half_goals` | Away goals in second half | Raw trigger input transparency for second-half scoring condition. |
| `match_total_first_half_goals` | Combined first-half goals | Measures early-match goal intensity in triggered fixtures. |
| `match_total_second_half_goals` | Combined second-half goals | Measures late-match goal intensity in triggered fixtures. |
| `match_total_goals` | Combined goals across both halves | Aggregate scoring load for ranking end-to-end drama severity. |
| `half_goal_intensity_delta` | Second-half goals minus first-half goals | Shows whether scoring accelerated or cooled after halftime. |
| `triggered_team_first_half_goals` | Triggered-side first-half goals | Side-oriented first-half contribution context. |
| `opponent_first_half_goals` | Opponent first-half goals | Bilateral first-half contribution comparator. |
| `triggered_team_second_half_goals` | Triggered-side second-half goals | Side-oriented second-half contribution context. |
| `opponent_second_half_goals` | Opponent second-half goals | Bilateral second-half contribution comparator. |
| `triggered_team_both_halves_scored_flag` | 1 if triggered side scored in both halves | Explicit decomposition of the triggered-side half-scoring condition. |
| `opponent_both_halves_scored_flag` | 1 if opponent scored in both halves | Explicit bilateral decomposition of the match trigger condition. |
| `triggered_team_total_shots` | Triggered-side total shots (`period = 'All'`) | Shot-volume context behind bilateral half scoring. |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shot-volume comparator. |
| `total_shots_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Precision context for triggered side. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential for tactical diagnostics. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context for triggered side. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context behind goal-rich game states. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around scoring exchanges. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context for high-event matches. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for modeling and QA. |
