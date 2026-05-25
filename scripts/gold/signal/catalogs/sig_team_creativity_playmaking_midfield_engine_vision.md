---
signal_id: sig_team_creativity_playmaking_midfield_engine_vision
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Midfield Engine Vision"
trigger: "Midfielders combine for >= 1.5 expected assists (xA) in one finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_creativity_playmaking_midfield_engine_vision
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_midfield_engine_vision.sql
  runner: scripts/gold/signal/runners/sig_team_creativity_playmaking_midfield_engine_vision.py
---
# sig_team_creativity_playmaking_midfield_engine_vision

## Purpose

Detect team-level midfield-led creativity spikes where midfield units alone generate at least 1.5 xA,
then preserve bilateral context for chance quality, passing execution, and attacking output.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_midfielder_expected_assists >= 1.5`
  - `trigger_threshold_required_usual_playing_position_id = 2` (midfielder)
  - `match_finished = 1`
- Midfielder eligibility comes from `silver.match_personnel` using `usual_playing_position_id = 2`
  with starter-priority role selection.
- Midfielder and team playmaking totals are aggregated from `silver.player_match_stat`
  (`expected_assists`, `chances_created`) at `match_id + team_id` grain.
- Bilateral context is sourced from `silver.period_stat` (`period = 'All'`) and `silver.match` for
  passing quality, shot pressure, xG, scoreline, and territory.
- Similarity gate note:
  - Closest active overlap is `sig_team_creativity_playmaking_chance_barrage`, which is team
    playmaking-volume based (`key_passes >= 15`) and not midfielder-role specific.
  - `sig_team_creativity_playmaking_total_fluidity` overlaps on team creativity breadth, but it is
    creator-distribution based (`distinct key-pass players >= 6`) rather than midfielder xA load.
  - Coexistence rationale: this signal isolates role-constrained midfield chance-quality engines,
    which neither closest signal models explicitly.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_midfield_engine_vision.sql`
- Runner: `scripts/gold/signal/runners/sig_team_creativity_playmaking_midfield_engine_vision.py`
- Target table: `gold.sig_team_creativity_playmaking_midfield_engine_vision`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_creativity_playmaking_midfield_engine_vision.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication key |
| `match_date` | Match date | Time slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered entity key for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral opponent context |
| `trigger_threshold_min_midfielder_expected_assists` | Trigger floor for midfielder xA (`1.5`) | Explicit trigger provenance for QA |
| `trigger_threshold_required_usual_playing_position_id` | Required usual playing position ID (`2`) | Explicit midfielder role-gate provenance |
| `triggered_team_midfielder_count` | Number of triggered-side midfielders | Midfield-unit denominator context |
| `opponent_midfielder_count` | Number of opponent midfielders | Bilateral denominator comparator |
| `midfielder_count_delta` | Triggered minus opponent midfielder count | Lineup-shape imbalance context |
| `triggered_team_midfielders_with_expected_assists` | Triggered-side midfielders with xA > 0 | Internal midfield contribution spread |
| `opponent_midfielders_with_expected_assists` | Opponent midfielders with xA > 0 | Bilateral contribution-spread comparator |
| `midfielders_with_expected_assists_delta` | Triggered minus opponent midfielders with xA > 0 | Net contributor-spread imbalance |
| `triggered_team_midfielder_expected_assists` | Triggered-side aggregate midfielder xA | Core trigger metric |
| `opponent_midfielder_expected_assists` | Opponent aggregate midfielder xA | Bilateral core-metric comparator |
| `midfielder_expected_assists_delta` | Triggered minus opponent midfielder xA | Net midfield chance-quality differential |
| `triggered_team_midfielder_expected_assists_above_threshold` | Triggered-side midfielder xA minus 1.5 | Trigger-severity context beyond binary activation |
| `triggered_team_midfielder_expected_assists_share_of_team_expected_assists_pct` | Triggered-side midfielder share of team xA (%) | Role-concentration context inside team creation |
| `opponent_midfielder_expected_assists_share_of_team_expected_assists_pct` | Opponent midfielder share of team xA (%) | Bilateral role-concentration comparator |
| `midfielder_expected_assists_share_of_team_expected_assists_delta_pct` | Triggered minus opponent midfielder xA share (%) | Net midfield-creation concentration gap |
| `triggered_team_midfielder_key_passes` | Triggered-side key passes by midfielders | Volume context behind midfielder xA |
| `opponent_midfielder_key_passes` | Opponent key passes by midfielders | Bilateral volume comparator |
| `midfielder_key_passes_delta` | Triggered minus opponent midfielder key passes | Net midfield chance-creation volume edge |
| `triggered_team_total_key_passes` | Triggered-side total key passes (all players) | Team creativity baseline for role normalization |
| `opponent_total_key_passes` | Opponent total key passes (all players) | Bilateral team creativity comparator |
| `total_key_passes_delta` | Triggered minus opponent total key passes | Net team creative-volume differential |
| `triggered_team_expected_assists` | Triggered-side total expected assists (all players) | Team chance-quality baseline |
| `opponent_expected_assists` | Opponent total expected assists (all players) | Bilateral team chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent total expected assists | Net team chance-quality differential |
| `triggered_team_goals` | Triggered-side goals | Scoreline conversion context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation workload context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume output context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Execution output context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net execution differential |
| `triggered_team_xg` | Triggered-side expected goals | Shot-quality output context |
| `opponent_xg` | Opponent expected goals | Bilateral shot-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Net shot-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
