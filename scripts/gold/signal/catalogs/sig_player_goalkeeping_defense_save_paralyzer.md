---
signal_id: sig_player_goalkeeping_defense_save_paralyzer
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Save Paralyzer"
trigger: "Goalkeeper saves a shot with expected goals > 0.4 at effective minute >= 80 in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_save_paralyzer
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_save_paralyzer.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_save_paralyzer

## Purpose

Identify late-match, high-leverage goalkeeper interventions where a keeper denies a high-quality chance (`xG > 0.4`) in the final 10 minutes, then preserve bilateral pressure and control context for tactical interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - goalkeeper save event (`is_on_target = 1`, `is_goal = 0`, `is_saved_off_line = 0`)
  - saved shot expected goals strictly greater than `0.4`
  - effective minute (`minute + minute_added`) at least `80`
  - finished match and goalkeeper player context
- Trigger aggregation is at `(match_id, triggered_player_id)` with one row per qualifying goalkeeper.
- Save-event rollups retain temporal pressure context through first/last late big-chance save minute and score margin at first qualifying save.
- Bilateral context uses `silver.period_stat` (`period = 'All'`) plus side-level trigger counts to compare late big-chance denial against overall match pressure.
- Similarity gate note: closest active signals are `sig_player_goalkeeping_defense_brick_wall` and `sig_player_goalkeeping_defense_penalty_stopper`; this signal is distinct because it is event-timed (final 10 minutes) and quality-gated (`xG > 0.4`) rather than volume-based total saves or penalty-specific events.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_save_paralyzer.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_save_paralyzer`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_save_paralyzer
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for match/player analytics and QA. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixed fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixed fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Outcome context around late save events. |
| `away_score` | Full-time away goals | Outcome context around late save events. |
| `triggered_side` | Triggered goalkeeper side (`home` or `away`) | Canonical side orientation at player grain. |
| `triggered_player_id` | Triggered goalkeeper identifier | Durable player identity for downstream joins. |
| `triggered_player_name` | Triggered goalkeeper name | Readable player attribution. |
| `triggered_team_id` | Triggered goalkeeper team identifier | Team linkage for contextual analysis. |
| `triggered_team_name` | Triggered goalkeeper team name | Readable team attribution. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator identity. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator. |
| `trigger_threshold_min_saved_shot_expected_goals` | Minimum saved-shot xG threshold (`0.4`) | Encodes trigger provenance for QA. |
| `trigger_threshold_min_effective_minute` | Minimum effective minute threshold (`80`) | Encodes final-10-minute trigger boundary. |
| `triggered_player_big_chance_saves_final_ten` | Count of qualifying late big-chance saves by triggered goalkeeper | Primary trigger intensity metric. |
| `triggered_player_first_big_chance_save_effective_minute` | Effective minute of first qualifying save | Game-state timing context for trigger onset. |
| `triggered_player_last_big_chance_save_effective_minute` | Effective minute of last qualifying save | End-of-match pressure persistence context. |
| `triggered_player_highest_saved_shot_expected_goals_final_ten` | Highest xG among qualifying saved shots | Peak difficulty of denied chance. |
| `triggered_player_avg_saved_shot_expected_goals_final_ten` | Average xG among qualifying saved shots | Mean denied-chance quality for robustness. |
| `triggered_player_saves_match` | Total saves by triggered goalkeeper in match | Full-match workload baseline around trigger event(s). |
| `triggered_player_shots_on_target_faced_match` | Total on-target shots faced by triggered goalkeeper | Denominator for match save-rate interpretation. |
| `triggered_player_goals_conceded_match` | Goals conceded from on-target shots faced | Outcome severity context. |
| `triggered_player_save_rate_match_pct` | Match save rate of triggered goalkeeper (%) | Normalized shot-stopping efficiency measure. |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Exposure context for event counts. |
| `triggered_player_touches` | Touches by triggered goalkeeper | Involvement context beyond saves. |
| `triggered_player_total_passes` | Pass attempts by triggered goalkeeper | Distribution-load context. |
| `triggered_player_accurate_passes` | Accurate passes by triggered goalkeeper | Distribution execution context. |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered goalkeeper (%) | Composure and ball-security context. |
| `triggered_team_score_at_first_big_chance_save` | Triggered-team score at first qualifying save | Scoreboard state at trigger onset. |
| `opponent_score_at_first_big_chance_save` | Opponent score at first qualifying save | Bilateral scoreboard context at trigger onset. |
| `score_margin_at_first_big_chance_save` | Triggered-team score margin at first qualifying save | Tactical pressure state (trailing/level/leading). |
| `triggered_team_big_chance_saves_final_ten` | Qualifying late big-chance saves by triggered side keepers | Side-level late denial context. |
| `opponent_big_chance_saves_final_ten` | Qualifying late big-chance saves by opponent side keepers | Bilateral late denial comparator. |
| `triggered_team_keeper_saves` | Total keeper saves by triggered side | Team-level shot-stopping workload context. |
| `opponent_keeper_saves` | Total keeper saves by opponent side | Bilateral shot-stopping comparator. |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure volume baseline. |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator. |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Precision pressure baseline. |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Bilateral precision pressure comparator. |
| `triggered_team_expected_goals_faced` | Expected goals generated against triggered side | Chance-quality-against baseline. |
| `opponent_expected_goals_faced` | Expected goals generated against opponent side | Bilateral chance-quality comparator. |
| `triggered_team_expected_goals_on_target_faced` | Expected goals on target faced by triggered side | On-target chance-severity context. |
| `opponent_expected_goals_on_target_faced` | Expected goals on target faced by opponent side | Bilateral on-target severity comparator. |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context around late saves. |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator. |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Team execution context under pressure. |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral execution comparator. |
| `big_chance_save_share_of_triggered_team_keeper_saves_pct` | Qualifying big-chance saves as share of triggered-side keeper saves (%) | Concentration metric for high-leverage saves within total workload. |
| `save_volume_delta_vs_opponent_keeper` | Triggered goalkeeper saves minus opponent-side keeper saves | Net goalkeeper workload differential. |
