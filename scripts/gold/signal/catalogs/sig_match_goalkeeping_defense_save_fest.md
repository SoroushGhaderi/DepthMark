---
signal_id: sig_match_goalkeeping_defense_save_fest
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Save Fest"
trigger: "Combined keeper saves exceed 12 in full match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_save_fest
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_save_fest.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_goalkeeping_defense_save_fest

## Purpose

Detect matches with extreme combined shot-stopping load and emit bilateral, side-oriented defensive context so analysts can study whether save volume came from sustained pressure, low shot quality, or chaotic end-to-end finishing.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(keeper_saves_home, 0) + coalesce(keeper_saves_away, 0)) > 12` at `period = 'All'` in finished matches.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain and consistent side-oriented joins.
- Enrichment keeps tactical explainability symmetric: save rates, shots on target faced, total shots faced, defensive actions (blocks/clearances/interceptions), possession/control, passing quality, and scoreline context.
- Similarity gate note: no active `sig_match_goalkeeping_defense_*` catalog currently exists; closest active signals are team-level defensive workload signals (for example `sig_team_goalkeeping_defense_shot_blocking_unit` and `sig_team_goalkeeping_defense_parking_the_bus`), while this signal is match-level and specifically triggered by *combined* bilateral save volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_save_fest.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_save_fest`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_goalkeeping_defense_save_fest
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication key and downstream join anchor. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture context for bilateral analysis. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context for bilateral analysis. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for defensive workload interpretation. |
| `away_score` | Full-time away goals | Scoreline context for defensive workload interpretation. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical side key for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level join key for features and QA. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_combined_keeper_saves_min` | Configured minimum combined saves (`13`) | Makes trigger boundary explicit for auditability. |
| `match_combined_keeper_saves` | Combined saves by both teams | Core trigger metric for save-fest detection. |
| `match_combined_shots_on_target_faced` | Combined shots on target faced by both keepers | Denominator context for interpreting aggregate save volume. |
| `match_combined_goals_conceded` | Combined goals conceded by both keepers | Outcome context for high-save matches. |
| `match_combined_save_rate_pct` | Combined save rate (%) | Normalized aggregate shot-stopping efficiency signal. |
| `triggered_team_keeper_saves` | Triggered-side keeper saves | Side-level shot-stopping workload and output. |
| `opponent_keeper_saves` | Opponent keeper saves | Bilateral save-volume comparator. |
| `keeper_saves_delta` | Triggered minus opponent saves | Net save workload differential. |
| `triggered_team_shots_on_target_faced` | Triggered-side shots on target faced | Pressure intensity faced by the triggered side. |
| `opponent_shots_on_target_faced` | Opponent shots on target faced | Bilateral pressure comparator. |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential. |
| `triggered_team_goals_conceded` | Goals conceded by triggered side | Defensive outcome suffered by triggered side. |
| `opponent_goals_conceded` | Goals conceded by opponent side | Bilateral defensive outcome comparator. |
| `goals_conceded_delta` | Triggered minus opponent goals conceded | Net concession differential. |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping effectiveness for triggered side. |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral save effectiveness comparator. |
| `save_rate_delta_pct` | Triggered minus opponent save rate (percentage points) | Directional save-efficiency gap. |
| `triggered_team_total_shots_faced` | Triggered-side total shots faced | Overall shot pressure faced beyond on-target attempts. |
| `opponent_total_shots_faced` | Opponent total shots faced | Bilateral total-pressure comparator. |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential. |
| `triggered_team_shot_blocks` | Triggered-side shot blocks | Defensive resistance context complementing saves. |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral block-volume comparator. |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential. |
| `triggered_team_clearances` | Triggered-side clearances | Box-protection and danger-removal workload indicator. |
| `opponent_clearances` | Opponent clearances | Bilateral clearance comparator. |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance workload differential. |
| `triggered_team_interceptions` | Triggered-side interceptions | Defensive anticipation context behind save pressure. |
| `opponent_interceptions` | Opponent interceptions | Bilateral interception comparator. |
| `interceptions_delta` | Triggered minus opponent interceptions | Net interception differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around defensive pressure. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation workload context under match pressure. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context under pressure. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Directional ball-security differential. |
| `triggered_team_goals` | Goals scored by triggered side | Offensive output context to pair with defensive workload. |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator. |
| `goal_delta` | Triggered minus opponent goals | Match result differential from triggered perspective. |
| `triggered_team_clean_sheet_flag` | `1` when triggered side conceded zero goals, else `0` | Quick defensive outcome flag for filtering and modeling. |
