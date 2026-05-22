---
signal_id: sig_match_goalkeeping_defense_goalkeeper_man_of_the_match
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Goalkeeper Man Of The Match"
trigger: "Goalkeeper is the highest-rated player in a 1-0 or 0-0 game."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_goalkeeping_defense_goalkeeper_man_of_the_match
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_goalkeeper_man_of_the_match.sql
  runner: scripts/gold/signal/runners/sig_match_goalkeeping_defense_goalkeeper_man_of_the_match.py
---
# sig_match_goalkeeping_defense_goalkeeper_man_of_the_match

## Purpose

Detect low-scoring defensive matches where a goalkeeper delivers the match-best rating profile,
then preserve bilateral side-oriented workload, control, and score context for interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - match scoreline is in `{0-0, 1-0, 0-1}`
  - a side's top-rated goalkeeper rating equals the highest player rating in the same finished match
- Match-level trigger emits one or two side-oriented rows (`triggered_side = 'home'` / `'away'`), allowing bilateral triggering when both goalkeepers tie at the top rating.
- Goalkeeper identity and rating are resolved per match-side from `silver.player_match_stat` using goalkeeper-only rows (`is_goalkeeper = 1`) with deterministic tie-breakers (rating, minutes played, player ID).
- Symmetric enrichment keeps defensive workload and control context from `silver.period_stat` (`period = 'All'`): saves, shots faced, interceptions, clearances, possession, pass accuracy, and result translation.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_save_fest`: same entity/family/subfamily and match-level defensive lens, but trigger is combined save volume, not player-rating leadership in low-scoring matches.
  - `sig_match_goalkeeping_defense_offside_frenzy`: same family and bilateral output style, but trigger axis is combined offsides, not goalkeeper top-rating.
  - `sig_player_shooting_goals_man_of_the_match_output`: overlaps with man-of-the-match framing, but that signal is attacking-output player-grain (`xG` + `xA`) rather than goalkeeper-led defensive match context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_goalkeeper_man_of_the_match.sql`
- Runner: `scripts/gold/signal/runners/sig_match_goalkeeping_defense_goalkeeper_man_of_the_match.py`
- Target table: `gold.sig_match_goalkeeping_defense_goalkeeper_man_of_the_match`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_goalkeeping_defense_goalkeeper_man_of_the_match.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for low-scoring trigger interpretation |
| `away_score` | Away full-time goals | Outcome context for low-scoring trigger interpretation |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable triggered attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_max_match_total_goals` | Maximum total-goals guardrail (`1`) | Explicit low-scoring trigger provenance |
| `trigger_condition_goalkeeper_highest_rated_required` | Flag indicating top-rating goalkeeper requirement (`1`) | Documents mandatory trigger component |
| `match_total_goals` | Combined goals in match | Low-scoring state evidence |
| `match_low_scoring_flag` | 1 for qualifying low-scoring scoreline | Fast filtering for trigger decomposition |
| `match_scoreline_label` | Scoreline bucket (`0-0` or `1-0`) | Compact tactical state descriptor |
| `match_highest_player_rating` | Highest player rating in match | Match-level benchmark for trigger validation |
| `triggered_goalkeeper_player_id` | Triggered goalkeeper player ID | Durable goalkeeper identity |
| `triggered_goalkeeper_player_name` | Triggered goalkeeper name | Readable goalkeeper attribution |
| `opponent_goalkeeper_player_id` | Opponent goalkeeper player ID | Bilateral goalkeeper comparator identity |
| `opponent_goalkeeper_player_name` | Opponent goalkeeper name | Readable bilateral goalkeeper context |
| `triggered_goalkeeper_fotmob_rating` | Triggered goalkeeper rating | Core trigger-side rating metric |
| `opponent_goalkeeper_fotmob_rating` | Opponent goalkeeper rating | Bilateral goalkeeper rating comparator |
| `goalkeeper_fotmob_rating_delta` | Triggered minus opponent goalkeeper rating | Net goalkeeper rating edge |
| `triggered_goalkeeper_minutes_played` | Triggered goalkeeper minutes | Exposure context for rating interpretation |
| `opponent_goalkeeper_minutes_played` | Opponent goalkeeper minutes | Bilateral exposure comparator |
| `goalkeeper_minutes_played_delta` | Triggered minus opponent goalkeeper minutes | Exposure differential context |
| `both_goalkeepers_top_rated_flag` | 1 when both goalkeepers tie at match-top rating | Distinguishes one-sided heroics from bilateral tie-top outcomes |
| `triggered_team_keeper_saves` | Saves by triggered side goalkeeper | Shot-stopping workload context |
| `opponent_keeper_saves` | Saves by opponent side goalkeeper | Bilateral workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net goalkeeper workload differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | On-target pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Overall defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Anticipation and screening context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Danger-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net danger-release differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context around goalkeeper impact |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates rating heroics from clean-sheet outcome |
