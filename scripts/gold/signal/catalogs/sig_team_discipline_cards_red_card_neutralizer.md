---
signal_id: sig_team_discipline_cards_red_card_neutralizer
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Red Card Neutralizer"
trigger: "Team scores a goal within 5 minutes of being reduced to 10 men."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_red_card_neutralizer
  sql: clickhouse/gold/signal/sig_team_discipline_cards_red_card_neutralizer.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_red_card_neutralizer.py
---
# sig_team_discipline_cards_red_card_neutralizer

## Purpose

Flags team-match performances where a side scores within five effective minutes of its first red card, surfacing immediate attacking response after being reduced to 10 men.

## Tactical And Statistical Logic

- Trigger condition:
  - Team receives at least one red card.
  - The team's first credited goal after that first red card lands within five effective minutes.
  - The goal must increase the triggered team's score relative to the scoreboard at the red card.
- The first qualifying post-red goal is retained as the neutralizing event.
- Output combines the red-card-to-goal timing, scoreboard swing, scorer context, discipline burden, attacking production, possession, passing, and defensive resistance metrics.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_red_card_neutralizer.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_red_card_neutralizer.py`
- Target table: `gold_signals.sig_team_discipline_cards_red_card_neutralizer`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_red_card_neutralizer.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and release QA |
| `match_date` | Match date | Football developer: supports temporal analysis and partition-aligned checks |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: final scoreline context for post-red response interpretation |
| `away_score` | Away full-time goals | Football developer: final scoreline context for post-red response interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_minutes_after_red` | Configured response-window threshold (`5`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_first_red_card_minute` | Minute of triggered team's first red card | Football developer: adversity onset anchor |
| `triggered_team_first_red_card_added_time` | Added time attached to the first red card | Football developer: preserves stoppage-time timing precision |
| `triggered_team_first_red_card_effective_minute` | Red-card minute plus added time | Football developer: normalized timing for the five-minute response window |
| `triggered_team_neutralizing_goal_minute` | Minute of the first qualifying same-team goal | Football developer: response event anchor |
| `triggered_team_neutralizing_goal_added_time` | Added time attached to the qualifying goal | Football developer: preserves stoppage-time timing precision |
| `triggered_team_neutralizing_goal_effective_minute` | Goal minute plus added time | Football developer: normalized timing for red-to-goal interval checks |
| `minutes_from_red_to_goal` | Effective minutes between first red and qualifying goal | Football developer: core immediacy metric for the signal |
| `triggered_team_score_at_first_red` | Triggered-side score at the first red card | Football developer: scoreboard state at adversity onset |
| `opponent_score_at_first_red` | Opponent score at the first red card | Football developer: bilateral scoreboard state at adversity onset |
| `score_margin_at_first_red` | Triggered minus opponent score at first red | Football developer: game-state leverage before the response |
| `triggered_team_score_after_neutralizing_goal` | Triggered-side score after the qualifying goal | Football developer: confirms score-state movement after the red |
| `opponent_score_after_neutralizing_goal` | Opponent score after the qualifying goal | Football developer: bilateral scoreboard state after the response |
| `score_margin_after_neutralizing_goal` | Triggered minus opponent score after the qualifying goal | Football developer: post-response game-state leverage |
| `score_margin_swing_after_goal` | Score-margin change from red card to qualifying goal | Football developer: direct impact of the neutralizing response |
| `triggered_team_neutralizing_goal_scorer_id` | Scorer identifier for the qualifying goal | Football developer: player attribution for downstream narratives and joins |
| `triggered_team_neutralizing_goal_scorer_name` | Scorer name for the qualifying goal | Football developer: readable player attribution |
| `triggered_team_neutralizing_goal_is_own_goal` | Whether the qualifying credited goal is recorded as an own goal | Football developer: distinguishes forced scoreboard response from direct finishing |
| `triggered_team_red_cards_match` | Triggered-side full-match red cards | Football developer: total dismissal burden |
| `opponent_red_cards_match` | Opponent full-match red cards | Football developer: bilateral dismissal comparator |
| `red_cards_match_delta` | Triggered minus opponent full-match red cards | Football developer: net dismissal imbalance |
| `triggered_team_yellow_cards_match` | Triggered-side full-match yellow cards | Football developer: caution-level context |
| `opponent_yellow_cards_match` | Opponent full-match yellow cards | Football developer: bilateral caution comparator |
| `triggered_team_total_cards_match` | Triggered-side full-match total cards | Football developer: aggregate discipline burden |
| `opponent_total_cards_match` | Opponent full-match total cards | Football developer: bilateral aggregate discipline comparator |
| `card_count_match_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load around the dismissal context |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure imbalance |
| `triggered_team_total_shots` | Triggered-side full-match shots | Football developer: attacking volume context for the response |
| `opponent_total_shots` | Opponent full-match shots | Football developer: bilateral attacking volume comparator |
| `shot_delta` | Triggered minus opponent shots | Football developer: net chance-volume context |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality context for resilience interpretation |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-quality context |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context under man-down conditions |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential after adversity |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: possession volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral possession volume comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: ball-security context while reduced |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral ball-security comparator |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest response context |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive engagement context while undermanned |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive engagement comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context during adversity |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context after dismissal |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
