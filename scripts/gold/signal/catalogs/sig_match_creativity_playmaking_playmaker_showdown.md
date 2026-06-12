---
signal_id: sig_match_creativity_playmaking_playmaker_showdown
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Playmaker Showdown"
trigger: "Both teams have a player with >= 5 key passes (chances created) in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_playmaker_showdown
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_playmaker_showdown.sql
  runner: scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_showdown.py
---
# sig_match_creativity_playmaking_playmaker_showdown

## Purpose

Detect bilateral creator duels where each team has at least one player producing high-volume key passes (`>= 5`) in the same finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `home_top_playmaker_key_passes >= 5`
  - `away_top_playmaker_key_passes >= 5`
  - `match_finished = 1`, `period = 'All'`, `match_id > 0`
- Player key passes are sourced from `silver.player_match_stat.chances_created` and aggregated at `match_id + team_id + player_id` grain.
- A deterministic top playmaker per team is selected with `argMax` ordered by:
  - `player_key_passes` desc
  - `player_expected_assists` desc
  - `player_assists` desc
  - `player_id` asc tie-break
- Output emits two rows per qualified match (`triggered_side = home|away`) to preserve canonical `match_team` grain with symmetric `triggered_team_*` vs `opponent_*` metrics.
- Similarity gate note:
  - `sig_match_creativity_playmaking_the_creativity_clash` is closest match-level sibling but triggers on bilateral team xA floors (`>= 1.5`) rather than player-level key-pass floors.
  - `sig_match_creativity_playmaking_big_chance_fest` is match-event-volume driven (combined big chances), not specific to top individual creators.
  - `sig_player_creativity_playmaking_maestro_output` shares the same key-pass floor (`>= 5`) but is single-player output, not bilateral team-vs-team showdown logic.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_playmaker_showdown.sql`
- Runner: `scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_showdown.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_playmaker_showdown`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_showdown.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and join anchor |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Side-specific key for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_player_key_passes` | Player key-pass floor (`5`) | Explicit trigger provenance and QA guard |
| `match_players_meeting_key_pass_threshold` | Total players across both teams with `>= 5` key passes | Match-level intensity of elite creators |
| `triggered_team_players_meeting_key_pass_threshold` | Count of triggered-team players with `>= 5` key passes | Intra-team creator depth beyond top playmaker |
| `opponent_players_meeting_key_pass_threshold` | Count of opponent players with `>= 5` key passes | Bilateral creator-depth comparator |
| `players_meeting_key_pass_threshold_delta` | Triggered minus opponent threshold-meeting players | Net creator-depth edge |
| `triggered_team_top_playmaker_id` | Triggered-team top playmaker ID | Deterministic identity of primary creator |
| `triggered_team_top_playmaker_name` | Triggered-team top playmaker name | Readable primary creator context |
| `opponent_top_playmaker_id` | Opponent top playmaker ID | Bilateral primary creator identity |
| `opponent_top_playmaker_name` | Opponent top playmaker name | Readable bilateral creator comparator |
| `triggered_team_top_playmaker_key_passes` | Key passes by triggered-team top playmaker | Core trigger-side creator output |
| `opponent_top_playmaker_key_passes` | Key passes by opponent top playmaker | Bilateral core comparator |
| `top_playmaker_key_passes_delta` | Triggered minus opponent top-playmaker key passes | Net creator-volume differential |
| `triggered_team_top_playmaker_expected_assists` | Triggered-side top playmaker xA | Chance-quality context for creator output |
| `opponent_top_playmaker_expected_assists` | Opponent top playmaker xA | Bilateral creator chance-quality comparator |
| `top_playmaker_expected_assists_delta` | Triggered minus opponent top-playmaker xA | Net creator chance-quality edge |
| `triggered_team_top_playmaker_assists` | Assists by triggered-side top playmaker | Realized direct-output context |
| `opponent_top_playmaker_assists` | Assists by opponent top playmaker | Bilateral direct-output comparator |
| `top_playmaker_assists_delta` | Triggered minus opponent top-playmaker assists | Net realized creator-output edge |
| `triggered_team_top_playmaker_passes_final_third` | Final-third passes by triggered-side top playmaker | Territorial progression context of creator |
| `opponent_top_playmaker_passes_final_third` | Final-third passes by opponent top playmaker | Bilateral progression comparator |
| `top_playmaker_passes_final_third_delta` | Triggered minus opponent top-playmaker final-third passes | Net progression involvement edge |
| `triggered_team_key_passes` | Triggered-team total key passes | Team creativity baseline |
| `opponent_key_passes` | Opponent total key passes | Bilateral creativity baseline comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net team creativity differential |
| `triggered_team_expected_assists` | Triggered-team expected assists | Team chance-quality baseline |
| `opponent_expected_assists` | Opponent expected assists | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net chance-quality differential |
| `triggered_team_assists` | Triggered-team assists | Team realized creative output baseline |
| `opponent_assists` | Opponent assists | Bilateral realized-output comparator |
| `assists_delta` | Triggered minus opponent assists | Net realized creative-output differential |
| `triggered_team_top_playmaker_share_of_team_key_passes_pct` | Triggered top playmaker share of team key passes (%) | Concentration of team creativity in one player |
| `opponent_top_playmaker_share_of_team_key_passes_pct` | Opponent top playmaker share of team key passes (%) | Bilateral concentration comparator |
| `top_playmaker_share_of_team_key_passes_delta_pct` | Triggered minus opponent top-playmaker share (%) | Net creator-concentration edge |
| `triggered_team_goals` | Triggered-team goals | Scoreline context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Net outcome differential |
| `triggered_team_chance_conversion_pct` | Triggered-team goals per key pass (%) | Finishing realization over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral realization comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net finishing-efficiency differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Team circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third pressure differential |
