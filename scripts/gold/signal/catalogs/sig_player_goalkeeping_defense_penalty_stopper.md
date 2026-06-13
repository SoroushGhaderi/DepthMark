---
signal_id: sig_player_goalkeeping_defense_penalty_stopper
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Penalty Stopper"
trigger: "Goalkeeper saves at least one penalty kick in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_penalty_stopper
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_penalty_stopper.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_penalty_stopper

## Purpose

Flags goalkeepers who save at least one penalty in a finished match, then enriches each row with bilateral penalty-flow and shot-pressure context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_penalties_saved >= 1`
  - `is_goalkeeper = 1`
- Penalty attempts are identified from `silver.shot` when `situation` or `shot_type` contains `"penalty"` (case-insensitive).
- A penalty save is defined as:
  - penalty attempt has a goalkeeper identifier,
  - shot is on target,
  - event is not a goal,
  - and not `is_saved_off_line`.
- Signal stores keeper-level penalty severity context:
  - saves volume,
  - total penalty shots faced,
  - penalty goals conceded,
  - and saved expected-goals-on-target totals/averages.
- Bilateral context is sourced from `silver.period_stat` (`period = 'All'`) plus match-level penalty shot aggregates to preserve symmetric triggered-team/opponent interpretation.
- Similarity gate note: closest active player signals are `sig_player_discipline_cards_penalty_conceder` and `sig_player_discipline_cards_keeper_reckless`; this signal remains distinct because it is goalkeeper-shot-stopping specific and trigger logic is based on saved penalty shots, not card events.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_penalty_stopper.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_penalty_stopper`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_penalty_stopper
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for player, match, and team context |
| `match_date` | Match date | Football developer: supports temporal slicing and backfill verification |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home score | Football developer: outcome context around penalty save events |
| `away_score` | Full-time away score | Football developer: outcome context around penalty save events |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered goalkeeper ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered goalkeeper name | Football developer: readable player attribution |
| `triggered_team_id` | Triggered goalkeeper team ID | Football developer: team linkage for tactical context joins |
| `triggered_team_name` | Triggered goalkeeper team name | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_penalties_saved` | Trigger threshold for saved penalties (`1`) | Football developer: explicit trigger provenance for QA |
| `triggered_player_penalties_saved` | Saved penalty count by triggered goalkeeper | Football developer: primary trigger metric |
| `triggered_player_first_penalty_save_minute` | Minute of first saved penalty | Football developer: game-phase and pressure-timing context |
| `triggered_player_total_penalty_shots_faced` | Total penalty shots faced by triggered goalkeeper | Football developer: denominator for save-rate interpretation |
| `triggered_player_penalty_goals_conceded` | Penalty goals conceded by triggered goalkeeper | Football developer: severity context around penalty duels |
| `triggered_player_penalty_save_success_pct` | Penalty save rate (%) for triggered goalkeeper | Football developer: normalized shot-stopping quality indicator |
| `triggered_player_penalty_saved_expected_goals_on_target_total` | Sum of expected-goals-on-target denied on saved penalties | Football developer: quality-adjusted impact of penalty saves |
| `triggered_player_penalty_saved_expected_goals_on_target_avg` | Mean expected-goals-on-target denied per saved penalty | Football developer: per-event save difficulty context |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: exposure context for interpreting event volume |
| `triggered_team_score_at_first_penalty_save` | Triggered-team score at first saved penalty | Football developer: scoreboard context at trigger moment |
| `opponent_score_at_first_penalty_save` | Opponent score at first saved penalty | Football developer: bilateral scoreboard context at trigger moment |
| `score_margin_at_first_penalty_save` | Triggered-team score margin at first saved penalty | Football developer: pressure-state interpretation (trailing/level/leading) |
| `triggered_team_penalties_faced` | Penalty attempts taken against triggered side | Football developer: side-level penalty pressure context |
| `opponent_penalties_faced` | Penalty attempts taken against opponent side | Football developer: bilateral penalty-pressure comparator |
| `triggered_team_penalty_goals_conceded` | Penalty goals conceded by triggered side | Football developer: side-level concession severity context |
| `opponent_penalty_goals_conceded` | Penalty goals conceded by opponent side | Football developer: bilateral concession comparator |
| `triggered_team_penalty_saves` | Penalties saved by triggered side keepers | Football developer: side-level penalty shot-stopping comparator |
| `opponent_penalty_saves` | Penalties saved by opponent side keepers | Football developer: bilateral shot-stopping comparator |
| `triggered_team_keeper_saves` | Total keeper saves by triggered side | Football developer: aggregate defensive workload context |
| `opponent_keeper_saves` | Total keeper saves by opponent side | Football developer: bilateral defensive workload comparator |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Football developer: overall shot-pressure context around penalty events |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Football developer: bilateral shot-pressure comparator |
| `triggered_team_expected_goals_on_target_faced` | Expected goals on target faced by triggered side | Football developer: quality-weighted shot-pressure context |
| `opponent_expected_goals_on_target_faced` | Expected goals on target faced by opponent side | Football developer: bilateral quality-weighted pressure comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-style context around goalkeeper penalty events |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
