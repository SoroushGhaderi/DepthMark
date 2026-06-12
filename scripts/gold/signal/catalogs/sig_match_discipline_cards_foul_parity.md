---
signal_id: sig_match_discipline_cards_foul_parity
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Foul Parity"
trigger: "Both teams finish with exactly the same number of fouls (`fouls_home = fouls_away`) at full time (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_foul_parity
  sql: clickhouse/gold/signal/sig_match_discipline_cards_foul_parity.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_foul_parity.py
---
# sig_match_discipline_cards_foul_parity

## Purpose

Flags finished matches where foul volume is perfectly balanced between sides, then enriches that parity with cards, defensive workload, passing quality, and possession context.

## Tactical And Statistical Logic

- Trigger condition: `fouls_home = fouls_away` from `silver.period_stat` at `period = 'All'`.
- Emits one row for each side (`triggered_side in {'home','away'}`) so downstream team-oriented models can consume the parity event from either orientation.
- Keeps symmetric context fields and delta fields to separate low-contact parity from high-contact parity and to reveal whether equal fouls still produced asymmetric discipline outcomes.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_foul_parity.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_foul_parity.py`
- Target table: `gold_signals.sig_match_discipline_cards_foul_parity`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_foul_parity.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream modeling, QA, and lineage. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition-aware analysis. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time score | Football developer: match-state context for interpreting parity outcomes. |
| `away_score` | Away full-time score | Football developer: match-state context for interpreting parity outcomes. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side key at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable team identity for feature joins. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered entity label. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparator identity. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_abs_fouls_committed_delta` | Absolute foul-delta threshold used by trigger (`0`) | Football developer: explicit trigger provenance for governance and audits. |
| `match_total_fouls_committed` | Combined fouls from both teams | Football developer: separates low-volume parity from high-intensity parity. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: core trigger-side discipline load. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: symmetric trigger comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: parity sanity check and downstream invariant testing. |
| `abs_fouls_committed_delta` | Absolute foul difference between teams | Football developer: explicit equality-distance metric. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized foul allocation context. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: bilateral normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized parity gap feature. |
| `match_total_cards` | Combined yellow and red cards | Football developer: total sanction intensity context. |
| `match_total_yellow_cards` | Combined yellow cards | Football developer: caution-level composition context. |
| `match_total_red_cards` | Combined red cards | Football developer: dismissal-level composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution burden on the triggered side. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: caution asymmetry despite foul parity. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: severe sanction burden on triggered side. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral severe-sanction comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: dismissal asymmetry despite equal fouls. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: side-level sanction load for parity events. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral sanction-load comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary skew given equal fouls. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction conversion intensity for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: sanction conversion comparator for officiating asymmetry reads. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact sanction-efficiency imbalance metric. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context around foul parity. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive engagement context for parity matches. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation profile. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context for parity fixtures. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical execution context paired with discipline parity. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical edge/deficit under equal foul loads. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for parity situations. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net territorial control differential under the trigger. |
