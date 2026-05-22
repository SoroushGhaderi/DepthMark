---
signal_id: sig_team_goalkeeping_defense_wide_blockade
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Wide Blockade"
trigger: "Team allows <= 2 successful crosses from >= 20 cross attempts in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_goalkeeping_defense_wide_blockade
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_wide_blockade.sql
  runner: scripts/gold/signal/runners/sig_team_goalkeeping_defense_wide_blockade.py
---
# sig_team_goalkeeping_defense_wide_blockade

## Purpose

Detect team-level wide defensive suppression performances where a side faces heavy crossing volume but allows very few successful crosses.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_finished = 1`
  - `triggered_team_cross_attempts_allowed >= 20`
  - `triggered_team_successful_crosses_allowed <= 2`
- Side interpretation note:
  - this signal is defense-oriented; "allowed" is modeled from opponent crossing output
  - for a `home` trigger, opponent crossing stats are `*_away`; for an `away` trigger, opponent crossing stats are `*_home`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both teams can trigger in the same match.
- Trigger severity and context:
  - severity is captured with `triggered_team_successful_crosses_allowed_below_threshold` and `triggered_team_cross_attempts_allowed_above_threshold`
  - bilateral context includes shots faced, saves, xG faced, clearances, interceptions, possession, passing, and scoreline outputs
- Similarity gate note:
  - `sig_team_goalkeeping_defense_low_block_success`: same entity/family/subfamily and pressure-absorption framing, but trigger axis is high interceptions, not cross-suppression under wide pressure.
  - `sig_team_goalkeeping_defense_defensive_discipline`: same family and clean-defending flavor, but trigger is low fouls plus clean sheet, not crossing prevention.
  - `sig_team_possession_passing_cross_spam`: crossing-volume adjacent, but offensive possession family; this signal inverts perspective to defensive prevention of opponent crossing success.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_wide_blockade.sql`
- Runner: `scripts/gold/signal/runners/sig_team_goalkeeping_defense_wide_blockade.py`
- Target table: `gold.sig_team_goalkeeping_defense_wide_blockade`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_goalkeeping_defense_wide_blockade.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Supports time slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context |
| `away_score` | Away full-time goals | Scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Stable triggered-side key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_max_successful_crosses_allowed` | Maximum successful crosses allowed threshold (`2`) | Explicit trigger provenance for QA and audits |
| `trigger_threshold_min_cross_attempts_allowed` | Minimum cross attempts faced threshold (`20`) | Explicit exposure floor for trigger activation |
| `triggered_team_cross_attempts_allowed` | Opponent cross attempts against triggered side | Core trigger denominator |
| `opponent_cross_attempts_allowed` | Triggered-side cross attempts against opponent | Bilateral exposure comparator |
| `cross_attempts_allowed_delta` | Triggered minus opponent cross attempts allowed | Net exposure differential |
| `triggered_team_successful_crosses_allowed` | Opponent successful crosses against triggered side | Core trigger numerator |
| `opponent_successful_crosses_allowed` | Triggered-side successful crosses against opponent | Bilateral suppression comparator |
| `successful_crosses_allowed_delta` | Triggered minus opponent successful crosses allowed | Net suppression differential |
| `triggered_team_crosses_prevented` | Cross attempts faced minus successful crosses allowed | Defensive prevention volume context |
| `opponent_crosses_prevented` | Opponent-side equivalent prevented crosses | Bilateral prevention comparator |
| `crosses_prevented_delta` | Triggered minus opponent prevented crosses | Net prevention-volume differential |
| `triggered_team_successful_crosses_allowed_below_threshold` | Trigger headroom as `2 - successful_crosses_allowed` | Trigger severity below boundary |
| `triggered_team_cross_attempts_allowed_above_threshold` | Exposure headroom as `cross_attempts_allowed - 20` | Trigger severity above minimum volume |
| `triggered_team_successful_crosses_allowed_pct` | Successful crosses allowed as a percentage of crosses faced | Normalized suppression efficiency metric |
| `opponent_successful_crosses_allowed_pct` | Opponent-side equivalent allowed percentage | Bilateral efficiency comparator |
| `successful_crosses_allowed_pct_delta` | Triggered minus opponent successful-crosses-allowed percentage | Net efficiency differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Precision pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral precision-pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line defensive workload context |
| `opponent_keeper_saves` | Saves by opponent-side goalkeeper | Bilateral keeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper-workload differential |
| `triggered_team_expected_goals_faced` | Expected goals faced by triggered side | Chance-quality-against baseline |
| `opponent_expected_goals_faced` | Expected goals faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent expected goals faced | Net chance-quality-against differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release defensive context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context around defensive game model |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Execution quality context under defensive pressure |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Outcome context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Result differential context |
| `triggered_team_clean_sheet_flag` | 1 when triggered side keeps a clean sheet | Separates wide suppression with/without clean-sheet result |
