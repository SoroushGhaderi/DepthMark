---
signal_id: sig_match_discipline_cards_discipline_dominance
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Discipline Dominance"
trigger: "One team wins fouls, duels, and the match, but loses on cards (more bookings)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_discipline_cards_discipline_dominance
  sql: clickhouse/gold/signal/sig_match_discipline_cards_discipline_dominance.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_discipline_dominance.py
---
# sig_match_discipline_cards_discipline_dominance

## Purpose

Flags match-team rows where the winning side also leads the physical battle (fouls and duels won) but still receives more bookings, surfacing a specific discipline trade-off between control and sanction cost.

## Tactical And Statistical Logic

- Trigger condition:
  - `win_margin >= 1`
  - `fouls_committed_delta >= 1`
  - `duels_won_delta >= 1`
  - `card_count_delta >= 1`
- Trigger orientation (`triggered_side`) is the match winner (`home` or `away`) and the row is emitted only when all four edges hold together.
- Signal keeps bilateral foul/card conversion, duel share, defensive workload, passing quality, and possession context for tactical interpretation.
- Similarity note: this differs from `sig_match_discipline_cards_asymmetric_aggression` by requiring a winning scoreline and duel superiority, not only foul/card asymmetry.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_discipline_dominance.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_discipline_dominance.py`
- Target table: `gold.sig_match_discipline_cards_discipline_dominance`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_discipline_dominance.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA and downstream features. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: result context for dominance interpretation. |
| `away_score` | Away full-time goals | Football developer: result context for dominance interpretation. |
| `triggered_side` | Winning side that satisfies all trigger edges (`home` or `away`) | Football developer: canonical row identity orientation at match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_win_margin` | Configured minimum win-margin threshold (`1`) | Football developer: explicit trigger provenance for governance and audits. |
| `trigger_threshold_min_fouls_committed_delta` | Configured minimum foul-delta threshold (`1`) | Football developer: explicit trigger provenance for governance and audits. |
| `trigger_threshold_min_duels_won_delta` | Configured minimum duel-delta threshold (`1`) | Football developer: explicit trigger provenance for governance and audits. |
| `trigger_threshold_min_card_count_delta` | Configured minimum card-delta threshold (`1`) | Football developer: explicit trigger provenance for governance and audits. |
| `triggered_team_goals` | Goals scored by triggered side | Football developer: direct winning-output numerator. |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoring comparator. |
| `win_margin` | Triggered minus opponent goals | Football developer: compact winning-intensity measure behind trigger. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: core physicality trigger component. |
| `opponent_fouls_committed` | Fouls committed by opponent | Football developer: bilateral physicality comparator. |
| `match_total_fouls_committed` | Combined match fouls | Football developer: total whistle-load context. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact dominance measure. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized physicality contribution. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized foul asymmetry metric. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: core duel-control trigger component. |
| `opponent_duels_won` | Duels won by opponent | Football developer: bilateral duel-control comparator. |
| `match_total_duels_won` | Combined match duels won (home + away) | Football developer: denominator transparency for duel-share calculations. |
| `duels_won_delta` | Triggered minus opponent duels won | Football developer: net duel dominance magnitude. |
| `triggered_team_duel_wins_share_pct` | Triggered-side share of total duels won (%) | Football developer: normalized duel-control intensity. |
| `opponent_duel_wins_share_pct` | Opponent share of total duels won (%) | Football developer: symmetric normalized comparator. |
| `duel_wins_share_delta_pct` | Triggered minus opponent duel-win share (percentage points) | Football developer: compact normalized duel asymmetry metric. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: core disciplinary-cost trigger component. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: confirms the "loses on cards" side of the trigger. |
| `match_total_cards` | Combined match cards (yellow + red) | Football developer: aggregate sanction intensity context. |
| `match_total_yellow_cards` | Combined yellow cards | Football developer: caution composition context. |
| `match_total_red_cards` | Combined red cards | Football developer: dismissal composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution-level contribution to booking burden. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance detail. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal-level contribution to sanction burden. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance detail. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion profile for dominant winning side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary metric. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defensive engagement context around physical dominance. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context for winning side. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical quality context for the winning profile. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact technical differential alongside discipline trade-off. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context around dominance pattern. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger components. |
