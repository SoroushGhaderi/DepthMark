---
signal_id: sig_match_creativity_playmaking_playmaker_to_striker_connection
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Playmaker To Striker Connection"
trigger: "Proxy trigger: at least one player records >= 5 key passes and has a direct goal-assist link to the same teammate in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_playmaker_to_striker_connection
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_playmaker_to_striker_connection.sql
  runner: scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_to_striker_connection.py
---
# sig_match_creativity_playmaking_playmaker_to_striker_connection

## Purpose

Detect match-level creator-finisher partnerships where elite key-pass volume by one player aligns
with repeated direct goal-link connection to a specific teammate.

## Tactical And Statistical Logic

- Requested trigger intent:
  - one player provides `>= 5` key passes to the same teammate.
- Source limitation and proxy contract:
  - receiver-level key-pass destinations are not available in current Silver player stats,
  - so the signal uses a deterministic proxy:
    - creator key-pass volume from `silver.player_match_stat.chances_created` (`>= 5`), plus
    - creator -> finisher connection from `silver.shot` goal assist links
      (`assist_player_id -> player_id`, with at least one linked goal).
- Match scope:
  - `match_finished = 1`, `period = 'All'`, `match_id > 0`.
- Top connection per team is selected deterministically by:
  - creator key passes desc,
  - assisted goals to same finisher desc,
  - creator expected assists desc,
  - creator and finisher IDs as stable tie-breakers.
- Output emits two side-oriented rows (`home`, `away`) for canonical `match_team` grain.
- Similarity gate note:
  - `sig_match_creativity_playmaking_playmaker_showdown` is the closest sibling on `>= 5` key-pass creators, but it does not model creator->finisher linkage.
  - `sig_match_creativity_playmaking_assist_provider_battle` tracks multi-player assist concentration (`2+ assists`) rather than same-pair connection shape.
  - `sig_player_creativity_playmaking_chance_machine` models player creation via shot-assist traces at player grain, not bilateral match-team connection output.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_playmaker_to_striker_connection.sql`
- Runner: `scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_to_striker_connection.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_playmaker_to_striker_connection`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_creativity_playmaking_playmaker_to_striker_connection.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and join key |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team ID | Fixture context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home score | Outcome context |
| `away_score` | Away score | Outcome context |
| `triggered_side` | Triggered row side (`home`/`away`) | Canonical match-team row identity |
| `triggered_team_id` | Triggered team ID | Side-specific downstream key |
| `triggered_team_name` | Triggered team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_creator_key_passes` | Creator key-pass threshold (`5`) | Explicit trigger provenance |
| `trigger_threshold_min_assisted_goals_to_same_teammate_proxy` | Minimum linked goals in receiver proxy (`1`) | Makes proxy floor auditable |
| `trigger_connection_proxy_source` | Proxy source label | Governance and interpretability for source constraints |
| `match_players_meeting_connection_proxy_threshold` | Match-wide count of creators meeting proxy threshold | Match intensity of qualifying creator links |
| `triggered_team_players_meeting_connection_proxy_threshold` | Triggered-team count of qualifying creators | Side-level depth of qualifying creator links |
| `opponent_players_meeting_connection_proxy_threshold` | Opponent count of qualifying creators | Bilateral depth comparator |
| `players_meeting_connection_proxy_threshold_delta` | Triggered minus opponent qualifying-creator count | Net creator-link depth differential |
| `triggered_team_connection_creator_player_id` | Triggered-side top connection creator ID | Deterministic creator identity |
| `triggered_team_connection_creator_player_name` | Triggered-side top connection creator name | Readable creator context |
| `opponent_connection_creator_player_id` | Opponent top connection creator ID | Bilateral creator comparator identity |
| `opponent_connection_creator_player_name` | Opponent top connection creator name | Readable bilateral creator comparator |
| `triggered_team_connection_finisher_player_id` | Triggered-side linked finisher ID | Deterministic finisher identity in connection |
| `triggered_team_connection_finisher_player_name` | Triggered-side linked finisher name | Readable finisher context |
| `opponent_connection_finisher_player_id` | Opponent linked finisher ID | Bilateral finisher comparator identity |
| `opponent_connection_finisher_player_name` | Opponent linked finisher name | Readable bilateral finisher comparator |
| `triggered_team_creator_key_passes` | Key passes by triggered-side connection creator | Core creator-volume metric |
| `opponent_creator_key_passes` | Key passes by opponent connection creator | Bilateral core comparator |
| `creator_key_passes_delta` | Triggered minus opponent creator key passes | Net creator-volume differential |
| `triggered_team_creator_expected_assists` | xA by triggered-side connection creator | Creator chance-quality context |
| `opponent_creator_expected_assists` | xA by opponent connection creator | Bilateral creator quality comparator |
| `creator_expected_assists_delta` | Triggered minus opponent creator xA | Net creator quality differential |
| `triggered_team_assisted_goals_to_connection_finisher_proxy` | Linked goal assists from triggered-side creator to selected finisher | Direct creator->finisher connection-strength proxy |
| `opponent_assisted_goals_to_connection_finisher_proxy` | Linked goal assists from opponent creator to selected finisher | Bilateral connection-strength comparator |
| `assisted_goals_to_connection_finisher_proxy_delta` | Triggered minus opponent linked-goal proxy | Net creator->finisher link differential |
| `triggered_team_connection_creator_share_of_team_key_passes_pct` | Creator share of triggered-team key passes (%) | Concentration of team creation in the connection creator |
| `opponent_connection_creator_share_of_team_key_passes_pct` | Creator share of opponent key passes (%) | Bilateral concentration comparator |
| `connection_creator_share_of_team_key_passes_delta_pct` | Triggered minus opponent creator key-pass share (%) | Net creator-concentration differential |
| `triggered_team_key_passes` | Triggered-team total key passes | Team creativity baseline |
| `opponent_key_passes` | Opponent total key passes | Bilateral team creativity comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_expected_assists` | Triggered-team total xA | Team chance-quality baseline |
| `opponent_expected_assists` | Opponent total xA | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent xA | Net chance-quality differential |
| `triggered_team_assists` | Triggered-team assists | Team realized creation output |
| `opponent_assists` | Opponent assists | Bilateral realized-output comparator |
| `assists_delta` | Triggered minus opponent assists | Net realized creator-output differential |
| `triggered_team_goals` | Triggered-team goals | Scoreline context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Net outcome differential |
| `triggered_team_chance_conversion_pct` | Triggered-team goals per key pass (%) | Finishing realization over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral realization comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net finishing-efficiency differential |
| `triggered_team_total_shots` | Triggered-team shots | Shot-volume context |
| `opponent_total_shots` | Opponent shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-team xG | Shot-quality context |
| `opponent_expected_goals` | Opponent xG | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent xG | Net shot-quality differential |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Passing quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
