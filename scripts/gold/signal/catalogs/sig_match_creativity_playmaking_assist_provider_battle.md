---
signal_id: sig_match_creativity_playmaking_assist_provider_battle
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Assist Provider Battle"
trigger: "Match features at least 2 different players with 2+ assists each in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_assist_provider_battle
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_assist_provider_battle.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_assist_provider_battle

## Purpose

Detect finished matches where creator output is concentrated in multiple elite assist providers,
requiring at least two distinct players across the match to each record `2+` assists.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_players_with_two_plus_assists >= 2`
  - where player-level assists are aggregated from `silver.player_match_stat` at
    `match_id + team_id + player_id` grain.
- Match scope:
  - `silver.match.match_finished = 1`
  - `silver.period_stat.period = 'All'`
  - `match_id > 0`
- Distinct-player requirement:
  - only valid player IDs (`player_id > 0`) are counted,
  - and the threshold is applied on count of distinct players meeting `assists >= 2`.
- Side orientation:
  - emits one row per side (`triggered_side = 'home'` and `'away'`) with symmetric
    `triggered_team_*` vs `opponent_*` context.
- Similarity gate note:
  - `sig_match_creativity_playmaking_playmaker_showdown` is the closest match-level creativity sibling, but it triggers on bilateral key-pass floor (`>= 5`) rather than multi-player assist braces.
  - `sig_player_creativity_playmaking_assist_brace` overlaps on individual threshold (`2+ assists`) but is player-grain, not match-level bilateral output.
  - `sig_match_creativity_playmaking_the_creativity_clash` is bilateral team xA-threshold logic, not direct realized-assist concentration.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_assist_provider_battle.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_assist_provider_battle`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_assist_provider_battle
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication key |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Row side orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-specific downstream join key |
| `triggered_team_name` | Triggered-side team name | Readable triggered attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_players_with_two_plus_assists` | Minimum number of players meeting assist-brace condition (`2`) | Explicit trigger provenance and QA guard |
| `trigger_threshold_min_assists_per_player` | Minimum assists per qualifying player (`2`) | Makes per-player threshold explicit for governance |
| `match_players_with_two_plus_assists` | Count of players in match with `2+` assists | Core trigger metric |
| `triggered_team_players_with_two_plus_assists` | Triggered-side players with `2+` assists | Side-level creator-depth context |
| `opponent_players_with_two_plus_assists` | Opponent players with `2+` assists | Bilateral creator-depth comparator |
| `players_with_two_plus_assists_delta` | Triggered minus opponent qualifying-player count | Net creator-depth differential |
| `triggered_team_players_with_two_plus_assists_share_pct` | Triggered-side share of qualifying players (%) | Normalized contribution to trigger condition |
| `opponent_players_with_two_plus_assists_share_pct` | Opponent share of qualifying players (%) | Bilateral normalized comparator |
| `players_with_two_plus_assists_share_delta_pct` | Triggered minus opponent qualifying-player share (%) | Directional share differential |
| `match_total_assists` | Combined assists by both teams | Match-level creative realization intensity |
| `triggered_team_assists` | Triggered-side assists | Side-level realized creation output |
| `opponent_assists` | Opponent assists | Bilateral realized creation comparator |
| `assists_delta` | Triggered minus opponent assists | Net realized creator output differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creative volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral creative-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_expected_assists` | Triggered-side xA | Creative quality context |
| `opponent_expected_assists` | Opponent xA | Bilateral creative-quality comparator |
| `expected_assists_delta` | Triggered minus opponent xA | Net creative-quality differential |
| `triggered_team_top_assist_provider_id` | Triggered-side top assist provider player ID | Deterministic identity of lead assister |
| `triggered_team_top_assist_provider_name` | Triggered-side top assist provider name | Readable lead-assister context |
| `opponent_top_assist_provider_id` | Opponent top assist provider player ID | Bilateral lead-assister comparator identity |
| `opponent_top_assist_provider_name` | Opponent top assist provider name | Readable bilateral lead-assister comparator |
| `triggered_team_top_assist_provider_assists` | Assists by triggered-side top assist provider | Direct lead-assister production context |
| `opponent_top_assist_provider_assists` | Assists by opponent top assist provider | Bilateral lead-assister production comparator |
| `top_assist_provider_assists_delta` | Triggered minus opponent top-provider assists | Net lead-assister output differential |
| `triggered_team_top_assist_provider_key_passes` | Key passes by triggered-side top assist provider | Lead-assister underlying creation volume |
| `opponent_top_assist_provider_key_passes` | Key passes by opponent top assist provider | Bilateral lead-assister creation comparator |
| `top_assist_provider_key_passes_delta` | Triggered minus opponent top-provider key passes | Net lead-assister creation-volume differential |
| `triggered_team_top_assist_provider_expected_assists` | xA by triggered-side top assist provider | Lead-assister chance-quality context |
| `opponent_top_assist_provider_expected_assists` | xA by opponent top assist provider | Bilateral lead-assister chance-quality comparator |
| `top_assist_provider_expected_assists_delta` | Triggered minus opponent top-provider xA | Net lead-assister chance-quality differential |
| `triggered_team_goals` | Triggered-side goals | Scoreline context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Net outcome differential |
| `triggered_team_chance_conversion_pct` | Triggered-side goals per key pass (%) | Finishing realization over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral finishing-realization comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net finishing-efficiency differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation baseline context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
