---
signal_id: sig_team_discipline_cards_card_heavy_defeat
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Card-Heavy Defeat"
trigger: "Team loses by at least 3 goals and receives at least one red card."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_card_heavy_defeat
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_card_heavy_defeat.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_discipline_cards_card_heavy_defeat

## Purpose

Flags team-match performances where a side receives a red card and still loses by 3+ goals, isolating high-severity discipline-linked collapses.

## Tactical And Statistical Logic

- Trigger condition:
  - Team loses by at least three goals.
  - Team receives at least one red card in the same match.
- Earliest triggered-side red-card event is used as a timing anchor for score-state and post-dismissal goal swing.
- Output preserves bilateral discipline, foul load, defensive action profile, and possession context to separate pure scoreline noise from structural collapse patterns.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_card_heavy_defeat.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_discipline_cards_card_heavy_defeat`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_card_heavy_defeat
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA and downstream feature use |
| `match_date` | Match date | Football developer: temporal grouping and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: final scoreline context |
| `away_score` | Away full-time goals | Football developer: final scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation and row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered entity identity for attribution |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_loss_margin_goals` | Configured minimum losing margin (`3`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_min_red_cards_match` | Configured minimum triggered-side red cards (`1`) | Football developer: explicit discipline-threshold provenance |
| `triggered_team_loss_margin` | Final losing margin for triggered side | Football developer: collapse severity measure |
| `triggered_team_first_red_card_minute` | Earliest triggered-side red-card minute | Football developer: timing anchor for dismissal onset |
| `opponent_first_red_card_minute` | Earliest opponent red-card minute (`0` if none) | Football developer: bilateral dismissal timing comparator |
| `triggered_team_score_at_first_red` | Triggered-side score at own first red card | Football developer: game-state context at trigger anchor |
| `opponent_score_at_first_red` | Opponent score at triggered-side first red card | Football developer: bilateral game-state context at trigger anchor |
| `score_margin_at_first_red` | Triggered minus opponent score at first red | Football developer: leverage state before collapse window |
| `triggered_team_goals_after_first_red` | Triggered-side goals after own first red | Football developer: post-dismissal attacking output |
| `opponent_goals_after_first_red` | Opponent goals after triggered-side first red | Football developer: post-dismissal concession burden |
| `goals_after_first_red_delta` | Triggered minus opponent goals after first red | Football developer: net post-dismissal performance swing |
| `triggered_team_red_cards_match` | Triggered-side red cards in match | Football developer: dismissal burden magnitude |
| `opponent_red_cards_match` | Opponent red cards in match | Football developer: bilateral dismissal comparator |
| `red_cards_match_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance |
| `triggered_team_yellow_cards_match` | Triggered-side yellow cards in match | Football developer: caution-pressure context |
| `opponent_yellow_cards_match` | Opponent yellow cards in match | Football developer: bilateral caution comparator |
| `triggered_team_total_cards_match` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden |
| `opponent_total_cards_match` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator |
| `card_count_match_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression/load context |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential |
| `triggered_team_fouls_per_card` | Triggered-side fouls per total card | Football developer: discipline efficiency and conversion proxy |
| `opponent_fouls_per_card` | Opponent fouls per total card | Football developer: bilateral discipline-efficiency comparator |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest profile under collapse |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive engagement profile |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive engagement comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: anticipation and defensive read profile |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management signal during heavy defeat |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context for collapse diagnosis |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential linked to defeat profile |
