---
signal_id: sig_player_goalkeeping_defense_aerial_stronghold
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Aerial Stronghold"
trigger: "Defender wins >= 10 aerial duels in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_aerial_stronghold
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_aerial_stronghold.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_goalkeeping_defense_aerial_stronghold

## Purpose

Flags defenders who win at least ten aerial duels in a finished match, capturing dominant
back-line aerial control with bilateral defensive and possession context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `triggered_player_aerial_duels_won >= 10`
  - `match_finished = 1`
- Defender classification is sourced from `silver.match_personnel` (`usual_playing_position_id = 1`) and joined to `silver.player_match_stat` for player-level duel and defensive metrics.
- Player diagnostics preserve aerial, ground-duel, tackle, clearance, interception, and recovery outputs to distinguish pure volume from defensive efficiency.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` aerial/defensive/control fields.
- Similarity gate note: closest active signal is `sig_player_possession_passing_target_man_aerials`; this signal intentionally coexists because that signal targets forwards (`usual_playing_position_id = 3`) as long-ball outlets, while this one targets defenders (`usual_playing_position_id = 1`) for defensive aerial dominance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_aerial_stronghold.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_aerial_stronghold`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_aerial_stronghold
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing for trends/backfills |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Full-time home goals | Outcome context around defender aerial dominance |
| `away_score` | Full-time away goals | Outcome context around defender aerial dominance |
| `triggered_side` | Side of triggered defender (`home`/`away`) | Canonical side orientation |
| `triggered_player_id` | Triggered defender ID | Durable player identity |
| `triggered_player_name` | Triggered defender name | Readable attribution |
| `triggered_team_id` | Triggered defender team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_aerial_duels_won` | Trigger threshold (`10`) | Explicit trigger provenance |
| `triggered_player_position_id` | Match-specific position ID | Role diagnostics for in-match deployment |
| `triggered_player_usual_playing_position_id` | Usual position bucket used for defender gate | Documents role filter contract |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure reliability context |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Core trigger metric |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Denominator for aerial efficiency interpretation |
| `triggered_player_aerial_duel_success_pct` | Triggered defender aerial duel success (%) | Separates raw duel volume from efficiency |
| `triggered_player_duels_won` | Total duels won by triggered defender | Broader duel-control context |
| `triggered_player_duels_lost` | Total duels lost by triggered defender | Complements duel balance interpretation |
| `triggered_player_duel_win_share_pct` | Share of player duels won (%) | Normalized duel dominance indicator |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Defensive profile beyond aerial phase |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground-duel denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success (%) by triggered defender | Ground-duel efficiency diagnostic |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Defensive-action quality context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success (%) by triggered defender | Tackling efficiency diagnostic |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation/reading-of-play context |
| `triggered_player_clearances` | Clearances by triggered defender | Penalty-box protection context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_recoveries` | Ball recoveries by triggered defender | Defensive transition control context |
| `triggered_player_dribbled_past` | Times dribbled past for triggered defender | Defensive vulnerability counterbalance |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy (%) by triggered defender | Composure/retention context |
| `triggered_team_aerials_won` | Team aerial duels won by triggered side | Team-level aerial control baseline |
| `opponent_aerials_won` | Team aerial duels won by opponent side | Bilateral aerial-control comparator |
| `triggered_team_aerial_attempts` | Team aerial attempts by triggered side | Team aerial-volume context |
| `opponent_aerial_attempts` | Team aerial attempts by opponent side | Bilateral aerial-volume comparator |
| `triggered_team_aerial_success_pct` | Triggered-side aerial success (%) | Team-level aerial efficiency context |
| `opponent_aerial_success_pct` | Opponent-side aerial success (%) | Bilateral efficiency comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Physical-control context at team level |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical-control comparator |
| `triggered_team_ground_duels_won` | Team ground duels won by triggered side | Team defensive duel profile context |
| `opponent_ground_duels_won` | Team ground duels won by opponent side | Bilateral duel-profile comparator |
| `triggered_team_ground_duel_attempts` | Team ground duel attempts by triggered side | Team duel-volume context |
| `opponent_ground_duel_attempts` | Team ground duel attempts by opponent side | Bilateral duel-volume comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation/press context |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Defensive pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling output context |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
| `player_share_of_team_aerials_won_pct` | Triggered defender share of team aerial wins (%) | Concentration of aerial dominance in one player |
