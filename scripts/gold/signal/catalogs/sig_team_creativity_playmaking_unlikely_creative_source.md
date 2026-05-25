---
signal_id: sig_team_creativity_playmaking_unlikely_creative_source
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Unlikely Creative Source"
trigger: "Center backs provide >= 2 assists in one finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_creativity_playmaking_unlikely_creative_source
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_unlikely_creative_source.sql
  runner: scripts/gold/signal/runners/sig_team_creativity_playmaking_unlikely_creative_source.py
---
# sig_team_creativity_playmaking_unlikely_creative_source

## Purpose

Detect team-level matches where center backs become an unusually strong direct creative source by
combining for at least two assists in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_center_back_assists >= 2`
  - `trigger_threshold_required_usual_playing_position_id = 1`
  - `trigger_center_back_position_ids = '3,4'`
  - `match_finished = 1`
- Center-back role gate is resolved from `silver.match_personnel` with starter-priority position
  resolution per player (`argMax(..., if(role='starter', 2, 1))`).
- Center-back creative output is aggregated from `silver.player_match_stat` at team-match grain:
  - assists, key passes (`chances_created`), expected assists, and creator concentration metrics.
- Bilateral team context is retained from `silver.period_stat` (`period = 'All'`) and `silver.match`
  for passing control, shot output, xG, possession, and scoreline.
- Similarity gate note:
  - Closest active team-playmaking overlap is `sig_team_creativity_playmaking_bench_creative_impact`, which is role-scoped and assist-aware, but it models substitute impact rather than defensive-line creators.
  - `sig_team_creativity_playmaking_midfield_engine_vision` is role-scoped creativity at team grain, but it targets midfielder xA concentration rather than center-back direct assists.
  - Player-grain analogs (`sig_player_creativity_playmaking_fullback_playmaker`, `sig_player_creativity_playmaking_the_quarterback`) are individual-role signals, while this signal is team-grain aggregation of center-back assist production.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_unlikely_creative_source.sql`
- Runner: `scripts/gold/signal/runners/sig_team_creativity_playmaking_unlikely_creative_source.py`
- Target table: `gold.sig_team_creativity_playmaking_unlikely_creative_source`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_creativity_playmaking_unlikely_creative_source.py
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
| `trigger_threshold_min_center_back_assists` | Trigger floor for center-back assists (`2`) | Explicit trigger provenance |
| `trigger_threshold_required_usual_playing_position_id` | Required usual-playing-position ID (`1`) | Deterministic defender role-gate provenance |
| `trigger_center_back_position_ids` | Position proxy list for center backs (`3,4`) | Deterministic center-back scope provenance |
| `triggered_team_center_back_count` | Triggered-team center-back count in role scope | Role denominator context |
| `opponent_center_back_count` | Opponent center-back count in role scope | Bilateral role-denominator comparator |
| `center_back_count_delta` | Triggered minus opponent center-back count | Side-relative role-availability context |
| `triggered_team_center_backs_with_assists` | Triggered-team center backs with at least one assist | Creative spread across center-back unit |
| `opponent_center_backs_with_assists` | Opponent center backs with at least one assist | Bilateral creative-spread comparator |
| `center_backs_with_assists_delta` | Triggered minus opponent center backs with assists | Net center-back creator-spread edge |
| `triggered_team_center_back_assists` | Triggered-team assists by center backs | Core trigger metric |
| `opponent_center_back_assists` | Opponent assists by center backs | Bilateral trigger-metric comparator |
| `center_back_assists_delta` | Triggered minus opponent center-back assists | Net direct-creation edge from center backs |
| `triggered_team_top_center_back_assists` | Max assists by one triggered-team center back | Creator concentration context |
| `opponent_top_center_back_assists` | Max assists by one opponent center back | Bilateral concentration comparator |
| `top_center_back_assists_delta` | Triggered minus opponent top center-back assists | Net single-creator concentration edge |
| `triggered_team_center_back_key_passes` | Triggered-team key passes by center backs | Chance-creation volume context behind assists |
| `opponent_center_back_key_passes` | Opponent key passes by center backs | Bilateral chance-creation comparator |
| `center_back_key_passes_delta` | Triggered minus opponent center-back key passes | Net center-back chance-creation volume edge |
| `triggered_team_center_back_expected_assists` | Triggered-team center-back expected assists | Center-back chance-quality context |
| `opponent_center_back_expected_assists` | Opponent center-back expected assists | Bilateral center-back chance-quality comparator |
| `center_back_expected_assists_delta` | Triggered minus opponent center-back expected assists | Net center-back chance-quality edge |
| `triggered_team_total_assists` | Triggered-team total assists | Team baseline for normalization |
| `opponent_total_assists` | Opponent total assists | Bilateral team baseline comparator |
| `total_assists_delta` | Triggered minus opponent total assists | Net team direct-output edge |
| `triggered_team_total_key_passes` | Triggered-team total key passes | Team creativity baseline |
| `opponent_total_key_passes` | Opponent total key passes | Bilateral creativity comparator |
| `total_key_passes_delta` | Triggered minus opponent total key passes | Net team creativity edge |
| `triggered_team_total_expected_assists` | Triggered-team total expected assists | Team chance-quality baseline |
| `opponent_total_expected_assists` | Opponent total expected assists | Bilateral chance-quality comparator |
| `total_expected_assists_delta` | Triggered minus opponent total expected assists | Net team chance-quality edge |
| `triggered_team_center_back_assist_share_pct` | Triggered-team share of assists from center backs (%) | Dependence on unlikely defensive creators |
| `opponent_center_back_assist_share_pct` | Opponent share of assists from center backs (%) | Bilateral dependence comparator |
| `center_back_assist_share_delta_pct` | Triggered minus opponent center-back assist share (%) | Net style differential in assist source |
| `triggered_team_center_back_key_pass_share_pct` | Triggered-team share of key passes from center backs (%) | Center-back creative load share |
| `opponent_center_back_key_pass_share_pct` | Opponent share of key passes from center backs (%) | Bilateral creative-load comparator |
| `center_back_key_pass_share_delta_pct` | Triggered minus opponent center-back key-pass share (%) | Net center-back creative-load edge |
| `triggered_team_goals` | Triggered-team goals | Outcome conversion context |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Net scoreline edge |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Passing execution baseline |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team passing quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality edge |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure edge |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume edge |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution edge |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality edge |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control edge |
