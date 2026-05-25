---
signal_id: sig_team_creativity_playmaking_wide_play_monopoly
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Wide Play Monopoly"
trigger: ">= 70% of team-created chances come from wide-play crossing actions (cross-derived chance proxy)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_creativity_playmaking_wide_play_monopoly
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_wide_play_monopoly.sql
  runner: scripts/gold/signal/runners/sig_team_creativity_playmaking_wide_play_monopoly.py
---
# sig_team_creativity_playmaking_wide_play_monopoly

## Purpose

Detect team-level matches where chance creation is heavily concentrated into wide crossing routes,
with at least 70% of created chances attributed to a cross-derived wide-play proxy.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_wide_play_chance_share_pct >= 70.0`
- Wide-play chance proxy:
  - `triggered_team_cross_derived_chances_proxy = least(team_accurate_crosses, team_key_passes)`
  - `triggered_team_wide_play_chance_share_pct = 100 * triggered_team_cross_derived_chances_proxy / team_key_passes`
- Trigger source:
  - Team `chances_created`, `accurate_crosses`, `cross_attempts`, and `expected_assists` are aggregated from `silver.player_match_stat` by `match_id + team_id`.
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row per triggered side (`home` / `away`) with bilateral context (`triggered_team_*` vs `opponent_*`).
- Similarity gate note:
  - `sig_team_creativity_playmaking_crossing_clinic` is the nearest active sibling (crossing-heavy creativity), but it triggers on successful-cross volume (`>= 10`) rather than dominance of chance-creation mix.
  - `sig_team_possession_passing_cross_spam` overlaps on crossing style but is a possession-family attempts-volume signal, not a creativity-family chance-share monopoly signal.
  - Coexistence rationale: this signal captures cross-route concentration of chance creation, not absolute crossing volume.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_wide_play_monopoly.sql`
- Runner: `scripts/gold/signal/runners/sig_team_creativity_playmaking_wide_play_monopoly.py`
- Target table: `gold.sig_team_creativity_playmaking_wide_play_monopoly`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_creativity_playmaking_wide_play_monopoly.py
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
| `trigger_threshold_min_wide_play_chance_share_pct` | Trigger floor for wide-play chance-share proxy (`70.0`) | Explicit threshold provenance and governance traceability |
| `triggered_team_key_passes` | Triggered-team chances created (`key passes`) | Core chance-creation denominator for the monopoly trigger |
| `opponent_key_passes` | Opponent chances created (`key passes`) | Bilateral denominator comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume edge |
| `triggered_team_accurate_crosses` | Triggered-team accurate crosses | Wide-route execution numerator input |
| `opponent_accurate_crosses` | Opponent accurate crosses | Bilateral wide-route execution comparator |
| `accurate_crosses_delta` | Triggered minus opponent accurate crosses | Net wide-delivery execution differential |
| `triggered_team_cross_attempts` | Triggered-team cross attempts | Wide-route volume context for delivery precision |
| `opponent_cross_attempts` | Opponent cross attempts | Bilateral wide-volume comparator |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Net crossing-load differential |
| `triggered_team_cross_accuracy_pct` | Triggered-team cross accuracy (%) | Crossing execution quality context |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Bilateral crossing execution comparator |
| `cross_accuracy_delta_pct` | Triggered minus opponent cross accuracy (%) | Net crossing-precision differential |
| `triggered_team_cross_derived_chances_proxy` | Triggered-team cross-derived chance proxy (`least(accurate_crosses, key_passes)`) | Conservative estimate of chance creation attributable to wide crossing |
| `opponent_cross_derived_chances_proxy` | Opponent cross-derived chance proxy | Bilateral proxy comparator |
| `cross_derived_chances_proxy_delta` | Triggered minus opponent cross-derived chance proxy | Net cross-attributed chance-creation edge |
| `triggered_team_wide_play_chance_share_pct` | Triggered-team share of created chances attributed to wide-play crossing proxy (%) | Core monopoly trigger metric |
| `opponent_wide_play_chance_share_pct` | Opponent share of created chances attributed to wide-play crossing proxy (%) | Bilateral style-share comparator |
| `wide_play_chance_share_delta_pct` | Triggered minus opponent wide-play chance-share proxy (%) | Net tactical concentration differential |
| `triggered_team_expected_assists` | Triggered-team expected assists | Chance-quality context for the chance-creation profile |
| `opponent_expected_assists` | Opponent expected assists | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net chance-quality differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_cross_share_of_passes_pct` | Triggered-team cross attempts as share of pass attempts (%) | Style-intensity context for wide dependency |
| `opponent_cross_share_of_passes_pct` | Opponent cross attempts as share of pass attempts (%) | Bilateral style-intensity comparator |
| `cross_share_of_passes_delta_pct` | Triggered minus opponent cross share of passes (%) | Net stylistic imbalance toward crossing |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure edge |
| `triggered_team_total_shots` | Triggered-team total shots | Shooting-output volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Finishing-threat execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `triggered_team_expected_goals` | Triggered-team expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net chance-quality edge in shot outcomes |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Match-control context around wide-play dependence |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
| `triggered_team_goals` | Triggered-team goals | Scoreline output context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Compact match-outcome differential |
