---
signal_id: sig_player_creativity_playmaking_box_entry_monopoly
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Box Entry Monopoly"
trigger: "Player accounts for more than 60% of his team's passes into the final third (the project's box-entry proxy), with at least 5 such passes."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_creativity_playmaking_box_entry_monopoly
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_box_entry_monopoly.sql
---
# sig_player_creativity_playmaking_box_entry_monopoly

## Purpose

Flags a sole progression outlet, a key-playmaker-dependence marker.

## Tactical And Statistical Logic

- Trigger: Player accounts for more than 60% of his team's passes into the final third (the project's box-entry proxy), with at least 5 such passes.
- The project proxies passes into the box with `passes_final_third` in `fotmob_silver.player_match_stat`. The player's share is his value divided by the sum over his team's players, and he needs at least 5.
- Similarity note: Closest: `sig_player_creativity_playmaking_box_penetrator` (>= 5 such passes) and `sig_player_creativity_playmaking_final_third_monopoly` (>= 30). Related creativity signals: `sig_player_creativity_playmaking_maestro_output`, `sig_player_creativity_playmaking_isolated_creativity` and `sig_player_creativity_playmaking_clutch_vision`. Different logic: more than 60% of the team's total. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_box_entry_monopoly.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_creativity_playmaking_box_entry_monopoly`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_creativity_playmaking_box_entry_monopoly
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match key for joins and QA. |
| `match_date` | Match date | Temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Fixture orientation anchor. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Fixture orientation anchor. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for the streak match. |
| `away_score` | Full-time away goals | Outcome context for the streak match. |
| `triggered_side` | Side of the player's team (`home` or `away`) | Canonical side identity. |
| `triggered_player_id` | Triggered player identifier | Player attribution key (row identity). |
| `triggered_player_name` | Triggered player name | Readable player context. |
| `triggered_team_id` | Player's team identifier | Team context key (row identity). |
| `triggered_team_name` | Player's team name | Readable team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_team_share_pct` | Configured trigger floor (more than `60` % of the team's final-third passes) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_final_third_pass_share_pct` | Share of the team's final-third passes (%) | Core signal intensity variable. |
| `triggered_player_final_third_pass_share_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_final_third_passes` | Final-third passes by the player | Volume behind the share. |
| `triggered_team_final_third_passes` | Final-third passes by the team | Team total behind the share. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context for the trigger. |
| `triggered_team_goals` | Triggered-side goals in the match | Result context for the streak match. |
| `opponent_goals` | Opponent goals in the match | Bilateral result comparator. |
| `triggered_team_xg` | Triggered-side expected goals (xG) | Chance-quality and control context behind the streak result. |
| `opponent_xg` | Opponent expected goals (xG) | Bilateral comparator for the same match. |
| `triggered_team_total_shots` | Triggered-side total shots | Chance-quality and control context behind the streak result. |
| `opponent_total_shots` | Opponent total shots | Bilateral comparator for the same match. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Chance-quality and control context behind the streak result. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral comparator for the same match. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Chance-quality and control context behind the streak result. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral comparator for the same match. |
