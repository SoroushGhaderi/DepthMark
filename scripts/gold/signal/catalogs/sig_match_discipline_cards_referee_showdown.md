---
signal_id: sig_match_discipline_cards_referee_showdown
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Referee Showdown"
trigger: "Referee issues at least one card to both match captains."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_referee_showdown
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_referee_showdown.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_discipline_cards_referee_showdown

## Purpose

Flags matches where both captains are carded, surfacing leadership-level discipline flashpoints and preserving bilateral match-team context.

## Tactical And Statistical Logic

- Trigger condition:
  - both the home and away captains receive at least one yellow/red card event in the same match.
- Captains are sourced from `silver.match_personnel` (`role = 'starter'`, `is_captain = 1`) by `match_id` and `team_side`.
- Captain card events are sourced from `silver.card` using yellow/red semantics in `card_type`/`description`, then rolled up per captain.
- Triggered matches emit two rows (`home` and `away`) at `match_team` grain so downstream models can consume symmetric side-oriented context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_referee_showdown.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_discipline_cards_referee_showdown`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_referee_showdown
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join and QA key for signal lineage. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context around captain-card escalation. |
| `away_score` | Away full-time goals | Football developer: scoreline context around captain-card escalation. |
| `triggered_side` | Triggered row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream team attribution key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_carded_captains` | Configured trigger threshold (`2`) | Football developer: explicit rule provenance and reproducibility. |
| `match_carded_captains_count` | Number of captains carded in the match (`2`) | Football developer: confirms bilateral trigger satisfaction. |
| `home_captain_player_id` | Home captain player identifier | Football developer: leadership identity for event audits and joins. |
| `home_captain_player_name` | Home captain player name | Football developer: readable home-captain attribution. |
| `away_captain_player_id` | Away captain player identifier | Football developer: leadership identity for event audits and joins. |
| `away_captain_player_name` | Away captain player name | Football developer: readable away-captain attribution. |
| `home_captain_total_cards` | Total cards on home captain | Football developer: side-by-side leadership discipline burden. |
| `away_captain_total_cards` | Total cards on away captain | Football developer: side-by-side leadership discipline burden. |
| `home_captain_yellow_cards` | Yellow cards on home captain | Football developer: sanction composition for home leadership context. |
| `away_captain_yellow_cards` | Yellow cards on away captain | Football developer: sanction composition for away leadership context. |
| `home_captain_red_cards` | Red cards on home captain | Football developer: severe escalation marker for home captain. |
| `away_captain_red_cards` | Red cards on away captain | Football developer: severe escalation marker for away captain. |
| `home_captain_first_card_minute` | First card minute for home captain | Football developer: leadership-discipline onset timing. |
| `away_captain_first_card_minute` | First card minute for away captain | Football developer: bilateral onset-timing comparator. |
| `home_captain_last_card_minute` | Last card minute for home captain | Football developer: persistence of captain-level discipline pressure. |
| `away_captain_last_card_minute` | Last card minute for away captain | Football developer: bilateral persistence comparator. |
| `triggered_captain_player_id` | Triggered-side captain player identifier | Football developer: side-oriented captain identity for consumption symmetry. |
| `triggered_captain_player_name` | Triggered-side captain player name | Football developer: readable side-oriented captain attribution. |
| `opponent_captain_player_id` | Opponent captain player identifier | Football developer: bilateral side-oriented captain comparator. |
| `opponent_captain_player_name` | Opponent captain player name | Football developer: readable bilateral captain comparator. |
| `triggered_captain_total_cards` | Total cards on triggered-side captain | Football developer: triggered-side leadership discipline intensity. |
| `opponent_captain_total_cards` | Total cards on opponent captain | Football developer: bilateral leadership discipline comparator. |
| `captain_total_cards_delta` | Triggered minus opponent captain total cards | Football developer: net leadership sanction imbalance. |
| `triggered_captain_yellow_cards` | Triggered-side captain yellow cards | Football developer: caution burden on triggered leadership side. |
| `opponent_captain_yellow_cards` | Opponent captain yellow cards | Football developer: bilateral caution comparator at captain level. |
| `captain_yellow_cards_delta` | Triggered minus opponent captain yellow cards | Football developer: captain-level caution asymmetry signal. |
| `triggered_captain_red_cards` | Triggered-side captain red cards | Football developer: triggered-side dismissal severity at leadership level. |
| `opponent_captain_red_cards` | Opponent captain red cards | Football developer: bilateral captain dismissal comparator. |
| `captain_red_cards_delta` | Triggered minus opponent captain red cards | Football developer: compact leadership dismissal imbalance metric. |
| `triggered_captain_first_card_minute` | First card minute for triggered-side captain | Football developer: side-oriented onset timing for captain sanctions. |
| `opponent_captain_first_card_minute` | First card minute for opponent captain | Football developer: bilateral onset comparator at captain level. |
| `triggered_team_yellow_cards` | Triggered-side team yellow cards | Football developer: team caution environment around captain trigger. |
| `opponent_yellow_cards` | Opponent team yellow cards | Football developer: bilateral team caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance at team level. |
| `triggered_team_red_cards` | Triggered-side team red cards | Football developer: team dismissal environment around captain trigger. |
| `opponent_red_cards` | Opponent team red cards | Football developer: bilateral team dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance at team level. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate team discipline burden with captain trigger. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact team-level discipline imbalance metric. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression context underlying sanction load. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact-pressure differential. |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive engagement context alongside captain cards. |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context for discipline interpretation. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation and pressing context around trigger. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: control-quality context under disciplinary stress. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral control-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact technical-control differential. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: style and control context for captain-card events. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with the trigger. |
