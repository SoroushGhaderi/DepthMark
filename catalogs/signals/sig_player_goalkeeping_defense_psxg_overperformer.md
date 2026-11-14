---
signal_id: sig_player_goalkeeping_defense_psxg_overperformer
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "PSxG Overperformer"
trigger: "Goalkeeper prevents >= 1.5 goals, measured as post-shot xG faced minus goals conceded, in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_goalkeeping_defense_psxg_overperformer
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_psxg_overperformer.sql
---
# sig_player_goalkeeping_defense_psxg_overperformer

## Purpose

Flags an elite shot-stopping match, a goalkeeper-form marker.

## Tactical And Statistical Logic

- Trigger: Goalkeeper prevents >= 1.5 goals, measured as post-shot xG faced minus goals conceded, in a finished match.
- Post-shot xG faced is the sum of `expected_goals_on_target` over the shots the keeper faced (on target or a goal, own goals excluded) in `fotmob_silver.shot`, matched by `keeper_id`. Goals conceded are the goal rows among them. The keeper must be marked `is_goalkeeper = 1` with minutes in `fotmob_silver.player_match_stat`.
- Similarity note: Closest: `sig_player_goalkeeping_defense_save_paralyzer` (a high-xG save late in a match) and `sig_team_goalkeeping_defense_keeper_reliance_index`. Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: post-shot xG minus goals conceded of at least 1.5 over the whole match. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_psxg_overperformer.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_goalkeeping_defense_psxg_overperformer`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_psxg_overperformer
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
| `trigger_threshold_min_goals_prevented` | Configured trigger floor (at least `1.5` goals prevented) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_goals_prevented` | Post-shot xG faced minus goals conceded | Core signal intensity variable. |
| `triggered_player_goals_prevented_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_post_shot_xg_faced` | Post-shot xG of the shots faced | Shot quality faced. |
| `triggered_player_goals_conceded` | Goals conceded | Outcome behind the gap. |
| `triggered_player_shots_faced` | Shots faced (on target or goals) | Workload context. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context. |
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
