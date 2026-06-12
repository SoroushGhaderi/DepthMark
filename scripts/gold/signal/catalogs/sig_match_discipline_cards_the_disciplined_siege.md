---
signal_id: sig_match_discipline_cards_the_disciplined_siege
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "The Disciplined Siege"
trigger: "One team has >= 75% possession while the opponent commits >= 25 fouls in the same match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_the_disciplined_siege
  sql: clickhouse/gold/signal/sig_match_discipline_cards_the_disciplined_siege.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_the_disciplined_siege.py
---
# sig_match_discipline_cards_the_disciplined_siege

## Purpose

Flags match-team cases where one side dominates the ball (at least 75% possession) while the opponent repeatedly interrupts play with very high foul volume (at least 25 fouls).

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_possession_pct >= 75`
  - `opponent_fouls_committed >= 25`
- Trigger orientation (`triggered_side`) is assigned to the side with higher full-match possession (`period = 'All'`), with home-side precedence on equal possession.
- Possession, foul, card, and defensive context are retained bilaterally to evaluate whether the siege was productive or mainly neutralized by tactical fouling.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_the_disciplined_siege.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_the_disciplined_siege.py`
- Target table: `gold_signals.sig_match_discipline_cards_the_disciplined_siege`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_the_disciplined_siege.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context for siege interpretation. |
| `away_score` | Away full-time goals | Football developer: scoreline context for siege interpretation. |
| `triggered_side` | Side that owns the possession siege (`home` or `away`) | Football developer: canonical orientation key at match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_triggered_team_possession_pct` | Configured minimum possession threshold (`75`) | Football developer: explicit trigger governance and provenance. |
| `trigger_threshold_min_opponent_fouls_committed` | Configured minimum opponent fouls threshold (`25`) | Football developer: explicit tactical-fouling gate for audits. |
| `triggered_team_possession_pct` | Triggered-side full-match possession (%) | Football developer: core control-share trigger metric. |
| `opponent_possession_pct` | Opponent full-match possession (%) | Football developer: bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact dominance magnitude summary. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: checks whether dominant side also engaged physically. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: core disruption trigger metric. |
| `match_total_fouls_committed` | Combined fouls in match | Football developer: match-level contact intensity anchor. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net aggression differential around siege conditions. |
| `opponent_fouls_above_threshold` | Opponent foul count above trigger floor (`opponent_fouls_committed - 25`) | Football developer: trigger intensity grading beyond qualification. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized aggression contribution for dominant side. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: normalized disruption burden on defending side. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact foul asymmetry summary paired with possession skew. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: sanction load on possession-dominant side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: sanction load on disruptive side. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance detail. |
| `match_total_cards` | Combined match cards (yellow + red) | Football developer: global sanction intensity context. |
| `match_total_yellow_cards` | Combined match yellow cards | Football developer: caution composition context. |
| `match_total_red_cards` | Combined match red cards | Football developer: dismissal composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution decomposition for dominant side. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance metric. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal decomposition for dominant side. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance metric. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction conversion intensity for dominant side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: sanction conversion of tactical-fouling side. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context alongside possession control. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive engagement context for dominant side. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: anticipation profile of possession-dominant side. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context when controlling territory. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical quality of the siege circulation. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: technical comparator under sustained pressure. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical differential paired with disruption profile. |
