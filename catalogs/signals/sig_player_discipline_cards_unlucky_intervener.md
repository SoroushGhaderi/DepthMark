---
signal_id: sig_player_discipline_cards_unlucky_intervener
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Unlucky Intervener"
trigger: "Player receives a card even though he committed only one foul in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_discipline_cards_unlucky_intervener
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_unlucky_intervener.sql
---
# sig_player_discipline_cards_unlucky_intervener

## Purpose

Flags a card for a one-off foul, a referee-strictness and harsh-booking marker.

## Tactical And Statistical Logic

- Trigger: Player receives a card even though he committed only one foul in a finished match.
- The player has `fouls_committed = 1` in `fotmob_silver.player_match_stat` and at least one row in `fotmob_silver.card`. The card may be for something other than the foul, so this is a proxy. Card counts come from `fotmob_silver.card`; the captain flag and position group come from `fotmob_silver.match_personnel`. Only players with `minutes_played > 0` are considered.
- Similarity note: Closest: `sig_player_discipline_cards_walking_tightrope` (a yellow before minute 20) and `sig_player_discipline_cards_unnecessary_card`. Related player discipline signals: `sig_player_discipline_cards_dirty_half_dozen`, `sig_player_discipline_cards_foul_magnet` and `sig_player_discipline_cards_heavy_hitter`. Different logic: a card with only one foul committed. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_unlucky_intervener.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_discipline_cards_unlucky_intervener`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_discipline_cards_unlucky_intervener
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
| `trigger_threshold_exact_fouls_committed` | Configured trigger floor (exactly `1` foul committed and a card received) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_fouls_committed` | Fouls committed by the player | Core signal intensity variable. |
| `triggered_player_fouls_committed_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_cards` | Cards received by the player | The booking behind the trigger. |
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
