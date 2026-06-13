---
signal_id: sig_team_discipline_cards_man_advantage_collapse
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Man-Advantage Collapse"
trigger: "Team loses the match despite the opposition having a red card."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_man_advantage_collapse
  sql: clickhouse/gold/signal/sig_team_discipline_cards_man_advantage_collapse.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_man_advantage_collapse

## Purpose

Flags team-match performances where a side loses even though the opponent is sent off at least once, surfacing failures to convert numerical advantage into result.

## Tactical And Statistical Logic

- Trigger condition:
  - Team loses the match.
  - Opponent receives at least one red card.
- Earliest opponent red-card event is captured as a temporal anchor for score-state and post-dismissal goal swing.
- Output preserves bilateral discipline, defensive load, and possession context to separate tactical collapse from isolated scoreline variance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_man_advantage_collapse.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_man_advantage_collapse`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_man_advantage_collapse
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA and downstream features |
| `match_date` | Match date | Football developer: temporal analysis and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: final result context |
| `away_score` | Away full-time goals | Football developer: final result context |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_opponent_red_cards` | Configured minimum opponent red cards (`1`) | Football developer: explicit trigger provenance for reproducibility |
| `opponent_first_red_card_minute` | Earliest opponent red-card minute | Football developer: timing anchor for man-advantage onset |
| `triggered_team_score_at_opponent_first_red` | Triggered-side score at opponent first red | Football developer: game-state context at advantage start |
| `opponent_score_at_opponent_first_red` | Opponent score at their first red | Football developer: bilateral game-state context at trigger anchor |
| `score_margin_at_opponent_first_red` | Triggered minus opponent score at opponent first red | Football developer: leverage state before collapse window |
| `triggered_team_estimated_minutes_with_man_advantage` | Estimated minutes remaining after opponent first red (`90 - minute`) | Football developer: rough exposure duration to numerical advantage |
| `triggered_team_goals_after_opponent_first_red` | Triggered-side goals after opponent first red | Football developer: attacking conversion after advantage begins |
| `opponent_goals_after_opponent_first_red` | Opponent goals after their first red | Football developer: concession burden despite opposition dismissal |
| `goals_after_opponent_first_red_delta` | Triggered minus opponent goals after opponent first red | Football developer: net post-red performance swing |
| `triggered_team_loss_margin` | Final loss margin for triggered side | Football developer: severity of collapse outcome |
| `triggered_team_red_cards_match` | Triggered-side full-match red cards | Football developer: own-dismissal confounder context |
| `opponent_red_cards_match` | Opponent full-match red cards | Football developer: intensity of opposition numerical disadvantage |
| `red_cards_match_delta` | Triggered minus opponent full-match red cards | Football developer: net dismissal imbalance |
| `triggered_team_yellow_cards_match` | Triggered-side full-match yellow cards | Football developer: caution-pressure context |
| `opponent_yellow_cards_match` | Opponent full-match yellow cards | Football developer: bilateral caution comparator |
| `triggered_team_total_cards_match` | Triggered-side full-match total cards | Football developer: aggregate discipline burden on triggered side |
| `opponent_total_cards_match` | Opponent full-match total cards | Football developer: aggregate discipline burden on opposition |
| `card_count_match_delta` | Triggered minus opponent full-match total cards | Football developer: net discipline-pressure imbalance |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression/load context for collapse interpretation |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest control under advantage |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive engagement profile |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive engagement comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: anticipation and control profile |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context despite advantage |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context for conversion failure |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential linked to outcome collapse |
