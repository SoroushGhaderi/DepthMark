---
signal_id: sig_team_creativity_playmaking_set_piece_threat_volume
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Set-Piece Threat Volume"
trigger: "Team creates >= 8 chances from dead-ball situations in a single finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_set_piece_threat_volume
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_set_piece_threat_volume.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_creativity_playmaking_set_piece_threat_volume

## Purpose

Detect team-level dead-ball chance-creation surges where a side generates at least eight
set-piece chances in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_dead_ball_chances >= 8`
  - `match_finished = 1`
  - Match-team rows are emitted per triggered side (`home`, `away`), so both teams can trigger in one match.
- Dead-ball chances are derived from `silver.shot` rows with dead-ball situations:
  - `situation IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece')`
- The signal pairs dead-ball volume with outcome/quality diagnostics:
  - dead-ball xG (`triggered_team_dead_ball_expected_goals`)
  - dead-ball on-target accuracy (`triggered_team_dead_ball_shot_accuracy_pct`)
  - dead-ball conversion (`triggered_team_dead_ball_chance_conversion_pct`)
- Team creativity context is retained with `triggered_team_key_passes` and
  `triggered_team_expected_assists`, plus bilateral match control context from `silver.period_stat`.
- Similarity gate note:
  - `sig_team_possession_passing_set_piece_focus` is the closest dead-ball-volume sibling, but its trigger is corner count (`>= 15`) and it is possession/passing scoped.
  - `sig_team_creativity_playmaking_chance_barrage` is the closest creativity/playmaking team-volume sibling, but it triggers on overall key-pass volume (`>= 15`) rather than dead-ball chance volume.
  - `sig_team_shooting_goals_dead_ball_specialists` focuses on dead-ball goal outcomes (`>= 2` goals), while this signal is chance-creation volume first.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_set_piece_threat_volume.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_set_piece_threat_volume`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_set_piece_threat_volume
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Time-series slicing and reproducible backfills |
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
| `trigger_threshold_min_dead_ball_chances` | Trigger floor for dead-ball chances (`8`) | Explicit threshold provenance |
| `triggered_team_dead_ball_chances` | Triggered-team dead-ball chances | Core trigger metric |
| `opponent_dead_ball_chances` | Opponent dead-ball chances | Bilateral trigger-metric comparator |
| `dead_ball_chances_delta` | Triggered minus opponent dead-ball chances | Net dead-ball chance-volume edge |
| `triggered_team_dead_ball_expected_goals` | Triggered-team dead-ball xG | Dead-ball chance-quality context |
| `opponent_dead_ball_expected_goals` | Opponent dead-ball xG | Bilateral dead-ball chance-quality comparator |
| `dead_ball_expected_goals_delta` | Triggered minus opponent dead-ball xG | Net dead-ball chance-quality edge |
| `triggered_team_dead_ball_shots_on_target` | Triggered-team dead-ball shots on target | Dead-ball execution volume context |
| `opponent_dead_ball_shots_on_target` | Opponent dead-ball shots on target | Bilateral dead-ball execution comparator |
| `dead_ball_shots_on_target_delta` | Triggered minus opponent dead-ball shots on target | Net dead-ball execution-volume edge |
| `triggered_team_dead_ball_shot_accuracy_pct` | Triggered-team dead-ball on-target rate (%) | Dead-ball shot execution quality |
| `opponent_dead_ball_shot_accuracy_pct` | Opponent dead-ball on-target rate (%) | Bilateral dead-ball execution-quality comparator |
| `dead_ball_shot_accuracy_delta_pct` | Triggered minus opponent dead-ball on-target rate (%) | Net dead-ball execution-quality edge |
| `triggered_team_dead_ball_goals` | Triggered-team goals from dead-ball situations | Dead-ball finishing output context |
| `opponent_dead_ball_goals` | Opponent goals from dead-ball situations | Bilateral dead-ball finishing comparator |
| `dead_ball_goals_delta` | Triggered minus opponent dead-ball goals | Net dead-ball finishing edge |
| `triggered_team_dead_ball_chance_conversion_pct` | Triggered-team dead-ball goals per dead-ball chance (%) | Dead-ball conversion efficiency |
| `opponent_dead_ball_chance_conversion_pct` | Opponent dead-ball goals per dead-ball chance (%) | Bilateral dead-ball conversion comparator |
| `dead_ball_chance_conversion_delta_pct` | Triggered minus opponent dead-ball conversion rate (%) | Net dead-ball conversion edge |
| `triggered_team_set_play_expected_goals` | Triggered-team set-play xG from period stats | Aggregate set-play quality corroboration |
| `opponent_set_play_expected_goals` | Opponent set-play xG from period stats | Bilateral set-play-quality comparator |
| `set_play_expected_goals_delta` | Triggered minus opponent set-play xG | Net aggregate set-play quality edge |
| `triggered_team_key_passes` | Triggered-team key passes | Team creativity volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net creativity-volume edge |
| `triggered_team_expected_assists` | Triggered-team expected assists (xA) | Team chance-creation quality context |
| `opponent_expected_assists` | Opponent expected assists (xA) | Bilateral chance-creation-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net chance-creation quality edge |
| `triggered_team_total_shots` | Triggered-team total shots | Overall attacking-volume baseline |
| `opponent_total_shots` | Opponent total shots | Bilateral attacking-volume comparator |
| `triggered_team_dead_ball_chance_share_of_total_shots_pct` | Triggered-team dead-ball chances as % of total shots | Dependence on dead-ball chance channel |
| `opponent_dead_ball_chance_share_of_total_shots_pct` | Opponent dead-ball chances as % of total shots | Bilateral dependence comparator |
| `dead_ball_chance_share_of_total_shots_delta_pct` | Triggered minus opponent dead-ball chance share (%) | Net style differential in chance channel usage |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure edge |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Passing execution baseline |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team passing quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality edge |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control edge |
