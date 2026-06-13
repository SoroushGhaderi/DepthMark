---
signal_id: sig_match_discipline_cards_referee_strictness
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Referee Strictness"
trigger: "First yellow card in the match is issued within minute 1-5 (inclusive)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_referee_strictness
  sql: clickhouse/gold/signal/sig_match_discipline_cards_referee_strictness.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_referee_strictness

## Purpose

Flags matches where a yellow card arrives very early, a practical proxy for strict early refereeing and low tolerance in opening duels.

## Tactical And Statistical Logic

- Trigger condition: minimum yellow-card minute in `silver.card` is between `1` and `5` (inclusive).
- Yellow-card detection accepts card events where `card_type` or `description` contains `yellow`/`booked`.
- Trigger is match-level, then emitted as two side-oriented rows (`triggered_side = home` and `away`) for team-centric downstream use.
- Output includes first-yellow attribution plus bilateral discipline and physical-intensity context from full-match period stats.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_referee_strictness.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_referee_strictness`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_referee_strictness
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity key for joins and QA. |
| `match_date` | Match date | Football developer: supports period slicing and partition-aware checks. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: human-readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: human-readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for early-card strictness events. |
| `away_score` | Full-time away goals | Football developer: outcome context for early-card strictness events. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for team-feature consumers. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: team-level feature ownership key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent name | Football developer: readable bilateral context. |
| `trigger_threshold_first_yellow_card_minute_inclusive` | Inclusive first-yellow threshold (`5`) | Football developer: explicit trigger provenance for explainability and QA. |
| `match_first_yellow_card_minute` | Minute of the first yellow in the match | Football developer: core strictness trigger metric. |
| `match_first_yellow_card_team_side` | Side receiving the first yellow (`home` or `away`) | Football developer: identifies who was first sanctioned. |
| `match_first_yellow_card_team_id` | Team ID of first-yellow recipient | Football developer: stable first-booking attribution key. |
| `match_first_yellow_card_team_name` | Team name of first-yellow recipient | Football developer: human-readable first-booking attribution. |
| `match_first_yellow_card_player_id` | Player ID receiving first yellow (if known) | Football developer: player attribution for replay and investigation. |
| `match_first_yellow_card_player_name` | Player name receiving first yellow | Football developer: analyst-readable first-booking context. |
| `triggered_team_early_yellow_cards` | Triggered-side yellow cards in minutes 1-5 | Football developer: side-level contribution to early strictness profile. |
| `opponent_early_yellow_cards` | Opponent yellow cards in minutes 1-5 | Football developer: bilateral early-card pressure comparator. |
| `early_yellow_cards_delta` | Triggered minus opponent early yellow cards | Football developer: net early-discipline imbalance. |
| `match_total_early_yellow_cards` | Total yellow cards in minutes 1-5 | Football developer: intensity of opening-phase sanctions. |
| `triggered_team_yellow_cards` | Triggered-side full-match yellow cards | Football developer: whether early strictness continued through the match. |
| `opponent_yellow_cards` | Opponent full-match yellow cards | Football developer: bilateral full-match caution comparator. |
| `triggered_team_red_cards` | Triggered-side full-match red cards | Football developer: escalation severity context. |
| `opponent_red_cards` | Opponent full-match red cards | Football developer: bilateral dismissal comparator. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden for triggered orientation. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: physical aggression context around early bookings. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending intensity context. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral contest comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive action profile near strict officiating matches. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral defensive action comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: control/quality context under strict early control. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical edge alongside discipline pressure. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for strict-match interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with strictness signal. |
