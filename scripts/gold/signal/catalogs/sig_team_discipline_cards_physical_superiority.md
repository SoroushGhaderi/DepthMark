---
signal_id: sig_team_discipline_cards_physical_superiority
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Physical Superiority"
trigger: "Team wins >= 65% of duels and commits >= 15 fouls."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_physical_superiority
  sql: clickhouse/gold/signal/sig_team_discipline_cards_physical_superiority.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_physical_superiority.py
---
# sig_team_discipline_cards_physical_superiority

## Purpose

Flags team-match cases where a side controls the duel battle (at least 65% duel-win share) while also committing high foul volume (15 or more fouls), surfacing physically dominant but contact-heavy performances.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_duel_wins_share_pct >= 65.0`
  - `triggered_team_fouls_committed >= 15`
- Trigger is evaluated symmetrically for home and away teams using `silver.period_stat` with `period = 'All'`.
- Duel share is computed as team duels won divided by total match duels won (`home + away`), preserving bilateral duel-share, foul-share, card, defensive-action, and possession context for interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_physical_superiority.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_physical_superiority.py`
- Target table: `gold_signals.sig_team_discipline_cards_physical_superiority`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_physical_superiority.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal slicing and partition checks |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity identity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_duel_wins_share_pct` | Configured duel-win share threshold (`65.0`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_min_fouls_committed` | Configured foul threshold (`15`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: raw numerator behind duel-share trigger |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral raw duel comparator |
| `triggered_team_duels_total` | Total duels won by both sides in match | Football developer: denominator transparency for duel-share calculations |
| `triggered_team_duel_wins_share_pct` | Triggered-side duel-win share (%) | Football developer: core trigger metric for physical control |
| `opponent_duel_wins_share_pct` | Opponent duel-win share (%) | Football developer: bilateral duel-control comparator |
| `duel_wins_share_delta_pct` | Triggered minus opponent duel-win share (percentage points) | Football developer: compact physical-dominance asymmetry metric |
| `triggered_team_duel_wins_share_above_threshold_pct` | Triggered duel-win share above threshold (`share - 65.0`) | Football developer: trigger severity beyond binary hit |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: core trigger aggression metric |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-volume comparator |
| `fouls_committed_above_threshold` | Fouls above trigger threshold (`fouls - 15`) | Football developer: trigger severity beyond binary hit |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalizes aggression against total whistle volume |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: bilateral foul-share context |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net aggression imbalance metric |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution-load context around physical trigger |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal context for escalation interpretation |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator |
| `triggered_team_total_cards` | Triggered-side total cards (yellow+red) | Football developer: aggregate discipline burden for triggered side |
| `opponent_total_cards` | Opponent total cards (yellow+red) | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net discipline-pressure imbalance |
| `triggered_team_cards_per_foul_pct` | Cards per foul (%) for triggered side | Football developer: sanction conversion context on high-foul profile |
| `opponent_cards_per_foul_pct` | Cards per foul (%) for opponent side | Football developer: bilateral sanction conversion comparator |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact officiating/discipline asymmetry metric |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context around duel dominance |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for physicality interpretation |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger conditions |
