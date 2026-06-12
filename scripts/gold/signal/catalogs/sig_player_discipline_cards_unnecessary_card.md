---
signal_id: sig_player_discipline_cards_unnecessary_card
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Unnecessary Card"
trigger: "Player receives a yellow/red card while their team is leading by >= 3 goals."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_unnecessary_card
  sql: clickhouse/gold/signal/sig_player_discipline_cards_unnecessary_card.sql
  runner: scripts/gold/signal/runners/sig_player_discipline_cards_unnecessary_card.py
---
# sig_player_discipline_cards_unnecessary_card

## Purpose

Flags players who are booked despite holding a comfortable lead, surfacing avoidable discipline risk that can destabilize game management.

## Tactical And Statistical Logic

- Trigger condition:
  - `score_margin_at_card >= 3` for the carded player's side.
  - Card event must be yellow/red (`card_type` or `description` text matching).
- Event anchoring:
  - The signal stores first qualifying-card minute and type per player-match plus count of all qualifying "unnecessary" cards.
- Identity and side logic:
  - Player identity is preserved via `triggered_player_*`.
  - Team/opponent identity is preserved via `triggered_team_*` and `opponent_team_*`, with canonical `triggered_side`.
- Context enrichment:
  - Player context from `silver.player_match_stat` (fouls, was fouled, minutes).
  - Bilateral team context from `silver.period_stat` (`period = 'All'`) for fouls, cards, and possession.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_unnecessary_card.sql`
- Runner: `scripts/gold/signal/runners/sig_player_discipline_cards_unnecessary_card.py`
- Target table: `gold_signals.sig_player_discipline_cards_unnecessary_card`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_discipline_cards_unnecessary_card.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across Gold assets |
| `match_date` | Match date | Football developer: supports trend and temporal analysis |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context for card interpretation |
| `away_score` | Full-time away goals | Football developer: outcome context for card interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation key for downstream slicing |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: binds player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `trigger_threshold_min_score_margin_at_card` | Trigger score-margin threshold (`3`) | Football developer: explicit rule provenance for QA and reproducibility |
| `triggered_player_first_unnecessary_card_minute` | Minute of first qualifying unnecessary card | Football developer: timing anchor for state-aware analysis |
| `triggered_player_first_unnecessary_card_type` | Type of first qualifying card (`yellow`, `red`, `yellow_red`) | Football developer: severity context at first trigger |
| `triggered_player_unnecessary_cards_count` | Count of qualifying cards while leading by >=3 | Football developer: repeat-risk intensity beyond binary trigger |
| `triggered_player_yellow_cards_match` | Triggered player's total yellow cards in match | Football developer: complete caution load context |
| `triggered_player_red_cards_match` | Triggered player's total red cards in match | Football developer: dismissal-severity context |
| `triggered_player_total_cards_match` | Triggered player's total card events in match | Football developer: aggregate discipline burden at player grain |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: behavior profile around avoidable bookings |
| `triggered_player_was_fouled` | Fouls suffered by triggered player | Football developer: duel-friction context around incidents |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for card-volume interpretation |
| `triggered_team_score_at_first_unnecessary_card` | Triggered team score when first unnecessary card occurred | Football developer: precise game-state context at trigger time |
| `opponent_score_at_first_unnecessary_card` | Opponent score when first unnecessary card occurred | Football developer: bilateral game-state context at trigger time |
| `score_margin_at_first_unnecessary_card` | Triggered-side score margin at first unnecessary card | Football developer: core trigger-state metric retained in output |
| `max_score_margin_during_unnecessary_cards` | Maximum triggered-side lead across qualifying cards | Football developer: severity of game-control context during bookings |
| `triggered_team_total_fouls` | Total fouls by triggered side | Football developer: team discipline environment around trigger |
| `opponent_total_fouls` | Total fouls by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_yellow_cards_match` | Yellow-card count for triggered side | Football developer: team caution context for referee strictness |
| `opponent_yellow_cards_match` | Yellow-card count for opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Red-card count for triggered side | Football developer: team dismissal-pressure context |
| `opponent_red_cards_match` | Red-card count for opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_total_cards_match` | Total cards (yellow+red) for triggered side | Football developer: aggregate team discipline load |
| `opponent_total_cards_match` | Total cards (yellow+red) for opponent side | Football developer: bilateral aggregate discipline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context to interpret behavior while leading |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
