---
signal_id: sig_match_creativity_playmaking_big_chance_fest
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Big Chance Fest"
trigger: "Combined big chances in the match exceed 8 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_big_chance_fest
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_big_chance_fest.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_big_chance_fest

## Purpose

Detect finished matches with very high combined big-chance volume (>8), highlighting bilateral
playmaking-heavy games where both sides repeatedly generate high-value opportunities.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_total_big_chances > 8`, where
  - `match_total_big_chances = coalesce(big_chances_home, 0) + coalesce(big_chances_away, 0)`.
- Trigger source:
  - Big-chance and match context metrics are sourced from `silver.period_stat` at `period = 'All'`.
  - Team key passes and expected assists are aggregated from `silver.player_match_stat`.
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row per side (`triggered_side = 'home'` and `'away'`) with bilateral context.
- Similarity gate note:
  - `sig_match_creativity_playmaking_the_creativity_clash` is the closest match-level creativity sibling; it triggers on bilateral xA floors (`>= 1.5` each), while this signal is event-volume driven on combined big chances.
  - `sig_team_creativity_playmaking_big_chance_monopoly` overlaps on big-chance domain, but it is team-level monopoly logic (`triggered >= 5` and `opponent = 0`) rather than match-level bilateral high volume.
  - `sig_match_shooting_goals_goal_fest` is outcome-goal-volume focused, whereas this signal is chance-creation-value focused.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_big_chance_fest.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_big_chance_fest`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_big_chance_fest
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
| `triggered_side` | Triggered row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_match_total_big_chances` | Trigger floor for match total big chances (`8`) | Explicit trigger provenance and QA traceability |
| `match_total_big_chances` | Combined big chances from both teams | Core match-level trigger metric |
| `triggered_team_big_chances` | Big chances by triggered side | Side-level high-value chance volume |
| `opponent_big_chances` | Big chances by opponent side | Bilateral high-value chance comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net big-chance volume differential |
| `triggered_team_big_chance_share_pct` | Triggered-side share of total match big chances (%) | Normalized side contribution to the high-event trigger |
| `opponent_big_chance_share_pct` | Opponent share of total match big chances (%) | Bilateral normalized comparator |
| `big_chance_share_delta_pct` | Triggered minus opponent big-chance share (%) | Directional share differential |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context for side-level conversion |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net wastefulness differential |
| `triggered_team_big_chances_converted` | Triggered-side converted big chances proxy (`big_chances - big_chances_missed`) | Output realization context behind big-chance volume |
| `opponent_big_chances_converted` | Opponent converted big chances proxy | Bilateral realization comparator |
| `big_chances_converted_delta` | Triggered minus opponent converted big chances proxy | Net high-value chance realization differential |
| `triggered_team_big_chance_conversion_pct` | Triggered-side big-chance conversion (%) | Finishing efficiency on high-value opportunities |
| `opponent_big_chance_conversion_pct` | Opponent big-chance conversion (%) | Bilateral efficiency comparator |
| `big_chance_conversion_delta_pct` | Triggered minus opponent big-chance conversion (%) | Net finishing-efficiency differential |
| `match_total_expected_assists` | Combined expected assists from both teams | Match-level creativity intensity context |
| `triggered_team_expected_assists` | Triggered-side expected assists | Side-level creativity quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_key_passes` | Triggered-side key passes | Side-level chance-creation volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral chance-creation comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_goals` | Triggered-side goals | Outcome context for big-chance exploitation |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net chance-quality differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
