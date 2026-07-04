---
signal_id: sig_team_creativity_playmaking_one_sided_vision
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "One-Sided Vision"
trigger: "Team creates >= 10 key passes while opponent creates 0 in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_one_sided_vision
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_one_sided_vision.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_creativity_playmaking_one_sided_vision

## Purpose

Detect team-level matches where one side monopolizes chance creation through key passing by
producing at least 10 key passes while the opponent produces none.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_key_passes >= 10`
  - `opponent_key_passes = 0`
- Trigger source:
  - Team key passes and expected assists are aggregated from `silver.player_match_stat`
    (`sum(chances_created)`, `sum(expected_assists)`) by `match_id + team_id`.
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row per triggered side (`home` / `away`) with bilateral context (`triggered_team_*`
    vs `opponent_*`) so both teams can trigger in different matches with the same contract.
- Similarity gate note:
  - `sig_team_creativity_playmaking_chance_barrage` is the closest key-pass sibling, but it only
    enforces high volume (`>= 15`) and does not require opponent suppression to zero.
  - `sig_team_creativity_playmaking_big_chance_monopoly` shares the monopoly structure
    (`triggered >= threshold`, `opponent = 0`) but applies it to big chances rather than key passes.
  - Coexistence rationale: this signal is specifically the key-pass monopoly variant at
    creativity/playmaking team grain.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_one_sided_vision.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_one_sided_vision`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_one_sided_vision
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and downstream join key |
| `match_date` | Match date | Time slicing and replay reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered team identity for joins and features |
| `triggered_team_name` | Triggered team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_key_passes` | Minimum key-pass threshold (`10`) | Explicit trigger provenance and QA traceability |
| `trigger_threshold_max_opponent_key_passes` | Maximum opponent key-pass threshold (`0`) | Explicit monopoly-suppression boundary provenance |
| `triggered_team_key_passes` | Triggered-team key passes | Core trigger metric |
| `opponent_key_passes` | Opponent key passes | Bilateral trigger comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume edge |
| `triggered_team_expected_assists` | Triggered-team expected assists | Chance-quality context for key-pass volume |
| `opponent_expected_assists` | Opponent expected assists | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creative-quality differential |
| `triggered_team_goals` | Triggered-team goals | Outcome conversion context |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_chance_conversion_pct` | Triggered-team goals per key pass (%) | Finishing efficiency over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral finishing-efficiency comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net conversion-efficiency differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shooting-volume differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net chance-quality differential |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential |
