---
signal_id: sig_match_physical_workrate_aerial_heavy_play
status: active
entity: match
family: physical
subfamily: workrate
grain: match_team
headline: "Aerial Heavy Play"
trigger: "More than 40% of all contested duels in a finished match are aerial duels."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_physical_workrate_aerial_heavy_play
  sql: clickhouse/gold/dml/signals/match/sig_match_physical_workrate_aerial_heavy_play.sql
---
# sig_match_physical_workrate_aerial_heavy_play

## Purpose

Flags an aerial, direct match, a long-ball and header-heavy marker.

## Tactical And Statistical Logic

- Trigger: More than 40% of all contested duels in a finished match are aerial duels.
- The share is `(aerial_attempts_home + aerial_attempts_away) / (aerial attempts + ground_duel_attempts)` over both teams, with at least 40 duels in total. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_possession_passing_wing_play_extravaganza` and `sig_match_creativity_playmaking_long_ball_duel`. Different logic: a duel mix with over 40% aerial. Related physical signals use the same duel statistics; the closest existing signals are `sig_match_discipline_cards_blood_and_thunder`, `sig_match_discipline_cards_battle_of_attrition` and `sig_match_goalkeeping_defense_tackle_and_interception_fest`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_physical_workrate_aerial_heavy_play.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_physical_workrate_aerial_heavy_play`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_physical_workrate_aerial_heavy_play
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
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_aerial_duel_share_pct` | Configured trigger floor (more than `40` % of duels are aerial) | Explicit trigger provenance for explainability and QA. |
| `match_aerial_duel_share_pct` | Aerial duels as a share of all duels (%) | Core signal intensity variable. |
| `match_aerial_duel_share_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_aerial_duels` | Aerial duels contested | Volume behind the share. |
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
