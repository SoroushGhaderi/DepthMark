---
signal_id: sig_team_creativity_playmaking_final_third_siege
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Final Third Siege"
trigger: "Team records >= 150 successful passes in the final third."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_final_third_siege
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_final_third_siege.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_final_third_siege

## Purpose

Detect team-level playmaking sieges where a side completes at least 150 successful passes in the
final third in a single finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_successful_final_third_passes >= 150`
- Trigger source:
  - Team aggregate of `silver.player_match_stat.passes_final_third` (sum across players by
    `match_id, team_id`).
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - one row per triggered side (`home` / `away`), with explicit opponent mapping.
- Similarity gate note:
  - `sig_team_possession_passing_pass_marathon` overlaps on high team passing volume but uses
    total completed passes (`>= 800`) rather than final-third-specific completion volume.
  - `sig_team_possession_passing_siege_mode` overlaps on territorial dominance framing but
    triggers on possession share (`> 80%`) rather than successful final-third passing load.
  - `sig_player_creativity_playmaking_final_third_monopoly` overlaps on final-third passing metric
    but is player-grain (`match_player`) and uses player-level thresholding (`>= 30`).
  - Coexistence rationale: this signal is the team-grain creativity/playmaking variant focused on
    extreme final-third circulation concentration at aggregate team level (`>= 150`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_final_third_siege.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_final_third_siege`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_final_third_siege
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and downstream join key |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture context for bilateral interpretation |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture context for bilateral interpretation |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match-outcome context |
| `away_score` | Away full-time goals | Match-outcome context |
| `triggered_side` | Triggered orientation (`home` or `away`) | Canonical side anchor at match-team grain |
| `triggered_team_id` | Triggered team identifier | Primary triggered-entity key |
| `triggered_team_name` | Triggered team name | Human-readable triggered entity |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator anchor |
| `opponent_team_name` | Opponent team name | Human-readable bilateral comparator |
| `trigger_threshold_min_successful_final_third_passes` | Trigger floor (`150`) | Explicit threshold provenance for QA and audits |
| `triggered_team_successful_final_third_passes` | Triggered team successful final-third passes | Core trigger metric |
| `opponent_successful_final_third_passes` | Opponent successful final-third passes | Bilateral comparator on same metric |
| `successful_final_third_passes_delta` | Triggered minus opponent successful final-third passes | Net territorial circulation advantage context |
| `triggered_team_final_third_pass_share_pct` | Triggered share of both teams' successful final-third passes (%) | Normalized dominance indicator beyond raw count |
| `opponent_final_third_pass_share_pct` | Opponent share of both teams' successful final-third passes (%) | Bilateral normalization pair |
| `triggered_team_key_passes` | Triggered team aggregated key passes (`chances_created`) | Playmaking-output context around the trigger |
| `opponent_key_passes` | Opponent aggregated key passes | Bilateral playmaking comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Indicates whether final-third volume translated into chance creation edge |
| `triggered_team_expected_assists` | Triggered team aggregated expected assists | Chance-quality context around playmaking volume |
| `opponent_expected_assists` | Opponent aggregated expected assists | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creative-quality differential |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Team passing workload denominator context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral workload comparator |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Team completion quality numerator |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Quality context for heavy final-third circulation |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral quality baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net completion-quality differential |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match-control context around territorial siege |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control advantage signal |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Penetration context behind final-third passing load |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third penetration differential |
| `triggered_team_total_shots` | Triggered team total shots | Shot-volume outcome context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered team shots on target | Shot-accuracy outcome context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-accuracy comparator |
| `triggered_team_expected_goals` | Triggered team expected goals | Shot-quality outcome context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
