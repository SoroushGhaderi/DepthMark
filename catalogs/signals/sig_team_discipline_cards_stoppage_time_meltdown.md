---
signal_id: sig_team_discipline_cards_stoppage_time_meltdown
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Stoppage Time Meltdown"
trigger: "Team receives a red card after minute 90 in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_stoppage_time_meltdown
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_stoppage_time_meltdown.sql
---
# sig_team_discipline_cards_stoppage_time_meltdown

## Purpose

Flags a late sending-off, a late-frustration marker.

## Tactical And Statistical Logic

- Trigger: Team receives a red card after minute 90 in a finished match.
- A red card is a row in `fotmob_silver.card` whose `card_type` or `description` contains `red`, with `card_minute > 90`, for the team's side.
- Similarity note: Closest: `sig_match_discipline_cards_chaos_90_plus` (two reds in added time in one match) and `sig_player_discipline_cards_late_red_drama` (a red after minute 85, per player). Different logic: a team-level red in stoppage time. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_stoppage_time_meltdown.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_stoppage_time_meltdown`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_stoppage_time_meltdown
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
| `trigger_threshold_min_red_card_minute` | Configured trigger floor (red card after minute `90`) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_late_red_cards` | Red cards after minute 90 | Core signal intensity variable. |
| `triggered_team_late_red_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
