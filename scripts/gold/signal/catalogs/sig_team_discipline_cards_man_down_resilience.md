---
signal_id: sig_team_discipline_cards_man_down_resilience
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Man-Down Resilience"
trigger: "Team wins the match despite receiving a red card before the 60th minute."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_discipline_cards_man_down_resilience
  sql: clickhouse/gold/signal/sig_team_discipline_cards_man_down_resilience.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_man_down_resilience.py
---
# sig_team_discipline_cards_man_down_resilience

## Purpose

Flags team-match performances where a side suffers an early red card (minute <= 59) but still wins, surfacing resilience under man-down conditions with bilateral tactical context.

## Tactical And Statistical Logic

- Trigger condition:
  - Team receives at least one red card with `card_minute` between `1` and `59`.
  - The same team finishes with a winning scoreline.
- Earliest early-red event is captured as the reference point for scoreboard state and post-red goal swing.
- Signal output preserves both early-red intensity and full-match discipline/control context to support tactical interpretation and robustness modeling.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_man_down_resilience.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_man_down_resilience.py`
- Target table: `gold.sig_team_discipline_cards_man_down_resilience`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_man_down_resilience.py
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
| `home_score` | Home full-time goals | Football developer: scoreline context for resilience interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for resilience interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_max_red_card_minute` | Configured red-card threshold minute (`59`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_first_red_card_minute` | Earliest triggered-side red-card minute before 60 | Football developer: temporal anchor for adversity onset |
| `triggered_team_red_cards_before_60` | Triggered-side red cards before 60 | Football developer: intensity of early dismissal pressure |
| `opponent_red_cards_before_60` | Opponent red cards before 60 | Football developer: bilateral early-dismissal comparator |
| `red_cards_before_60_delta` | Triggered minus opponent early red cards | Football developer: net early-dismissal imbalance |
| `triggered_team_score_at_first_red` | Triggered-side score at first early red event | Football developer: adversity-state context at trigger time |
| `opponent_score_at_first_red` | Opponent score at first early red event | Football developer: bilateral adversity-state context |
| `score_margin_at_first_red` | Triggered minus opponent score at first early red | Football developer: game-state leverage at adversity onset |
| `triggered_team_goals_after_first_red` | Triggered-side goals scored after first early red | Football developer: recovery/output after adversity |
| `opponent_goals_after_first_red` | Opponent goals scored after first early red | Football developer: bilateral post-red output comparator |
| `goals_after_first_red_delta` | Triggered minus opponent goals after first red | Football developer: net post-red performance swing |
| `triggered_team_win_margin` | Final winning margin for triggered side | Football developer: magnitude of resilient result |
| `triggered_team_red_cards_match` | Triggered-side full-match red cards | Football developer: total dismissal burden beyond trigger window |
| `opponent_red_cards_match` | Opponent full-match red cards | Football developer: bilateral dismissal comparator |
| `red_cards_match_delta` | Triggered minus opponent full-match red cards | Football developer: net dismissal imbalance at match horizon |
| `triggered_team_yellow_cards_match` | Triggered-side full-match yellow cards | Football developer: caution-level context |
| `opponent_yellow_cards_match` | Opponent full-match yellow cards | Football developer: bilateral caution comparator |
| `triggered_team_total_cards_match` | Triggered-side full-match total cards | Football developer: aggregate discipline burden |
| `opponent_total_cards_match` | Opponent full-match total cards | Football developer: bilateral aggregate discipline comparator |
| `card_count_match_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load under adversity |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest resilience context |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive engagement context while undermanned |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive engagement comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context during adversity |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context after dismissal |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context under man-down conditions |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential for resilient wins |
