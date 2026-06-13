---
signal_id: sig_match_creativity_playmaking_set_piece_creative_duel
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Set-Piece Creative Duel"
trigger: "Both teams record at least one goal assist from set-piece situations in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_set_piece_creative_duel
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_set_piece_creative_duel.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_set_piece_creative_duel

## Purpose

Detect finished matches where both teams convert set-piece delivery into direct goal creation
(via assisted set-piece goals), isolating bilateral dead-ball creativity duels.

## Tactical And Statistical Logic

- Trigger condition:
  - `home_set_piece_assists >= 1`
  - `away_set_piece_assists >= 1`
- Set-piece scope for assisted shots/goals uses `silver.shot.situation IN`
  `('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece')`.
- A set-piece assist is counted when:
  - `assist_player_id > 0`
  - `is_goal = 1`
  - `is_own_goal = 0`
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - `silver.period_stat.period = 'All'`
- Side orientation:
  - Emits one row for `home` and one for `away` (`match_team` grain symmetry).
- Similarity gate note:
  - `sig_team_creativity_playmaking_set_piece_threat_volume` is the closest set-piece creativity sibling, but it is unilateral team-triggered on dead-ball chance volume (`>= 8`) rather than bilateral assisted-goal creation.
  - `sig_match_creativity_playmaking_the_creativity_clash` is bilateral match-level creativity, but xA-threshold-driven instead of set-piece-assisted-goal-driven.
  - `sig_match_creativity_playmaking_big_chance_fest` is high-event match-level playmaking volume, while this signal is dead-ball assist realization specific.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_set_piece_creative_duel.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_set_piece_creative_duel`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_set_piece_creative_duel
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
| `trigger_threshold_min_team_set_piece_assists` | Per-team minimum set-piece assist threshold (`1`) | Explicit trigger provenance for QA and governance |
| `match_total_set_piece_assists` | Combined set-piece assists by both teams | Core bilateral trigger intensity metric |
| `triggered_team_set_piece_assists` | Triggered-side set-piece assists | Side-level trigger component |
| `opponent_set_piece_assists` | Opponent set-piece assists | Bilateral trigger comparator |
| `set_piece_assists_delta` | Triggered minus opponent set-piece assists | Net dead-ball assist differential |
| `triggered_team_set_piece_assist_share_pct` | Triggered-side share of match total set-piece assists (%) | Normalized side contribution to trigger intensity |
| `opponent_set_piece_assist_share_pct` | Opponent share of match total set-piece assists (%) | Bilateral normalized comparator |
| `set_piece_assist_share_delta_pct` | Triggered minus opponent set-piece assist share (%) | Directional set-piece influence differential |
| `triggered_team_set_piece_assisted_shots` | Triggered-side set-piece shots with an assist | Assisted set-piece creation volume context |
| `opponent_set_piece_assisted_shots` | Opponent set-piece assisted shots | Bilateral assisted creation comparator |
| `set_piece_assisted_shots_delta` | Triggered minus opponent set-piece assisted shots | Net assisted dead-ball shot volume differential |
| `triggered_team_set_piece_assisted_shots_on_target` | Triggered-side on-target set-piece assisted shots | Set-piece assisted execution quality context |
| `opponent_set_piece_assisted_shots_on_target` | Opponent on-target set-piece assisted shots | Bilateral execution comparator |
| `set_piece_assisted_shots_on_target_delta` | Triggered minus opponent on-target set-piece assisted shots | Net assisted shot execution differential |
| `triggered_team_set_piece_assisted_shot_accuracy_pct` | Triggered-side on-target rate for set-piece assisted shots (%) | Accuracy quality on assisted dead-ball shots |
| `opponent_set_piece_assisted_shot_accuracy_pct` | Opponent on-target rate for set-piece assisted shots (%) | Bilateral accuracy comparator |
| `set_piece_assisted_shot_accuracy_delta_pct` | Triggered minus opponent set-piece assisted shot accuracy (%) | Net assisted shot-accuracy differential |
| `triggered_team_set_piece_assisted_shot_expected_goals` | Triggered-side xG from set-piece assisted shots | Assisted dead-ball chance quality context |
| `opponent_set_piece_assisted_shot_expected_goals` | Opponent xG from set-piece assisted shots | Bilateral chance-quality comparator |
| `set_piece_assisted_shot_expected_goals_delta` | Triggered minus opponent xG from set-piece assisted shots | Net assisted dead-ball chance-quality differential |
| `match_total_expected_assists` | Combined expected assists from both teams | Match-level creativity intensity context |
| `triggered_team_expected_assists` | Triggered-side expected assists | Side-level creativity-quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net open-play and set-piece creativity differential |
| `triggered_team_key_passes` | Triggered-side key passes | Side-level chance-creation volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral chance-creation comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_goals` | Triggered-side goals | Outcome realization context |
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
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_big_chances` | Triggered-side big chances | High-value opportunity context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
