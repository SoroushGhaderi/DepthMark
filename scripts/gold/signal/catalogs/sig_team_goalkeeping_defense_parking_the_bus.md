---
signal_id: sig_team_goalkeeping_defense_parking_the_bus
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Parking The Bus"
trigger: "Team wins with < 30% possession and >= 30 clearances in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_parking_the_bus
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_parking_the_bus.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_goalkeeping_defense_parking_the_bus

## Purpose

Flags low-possession wins built on extreme clearance volume, surfacing compact, deep-block defensive game plans that absorb pressure and still deliver a positive result.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_goals > opponent_goals` (must win)
  - `triggered_team_possession_pct < 30.0`
  - `triggered_team_clearances >= 30`
  - `match_finished = 1` and `period = 'All'`
- Rows are emitted at `match_team` grain with `triggered_side` orientation, so either home or away team can trigger when conditions are met.
- Core trigger metrics (possession, clearances, win state) are enriched with bilateral defensive and shot-quality context from `silver.period_stat`.
- Similarity gate note:
  - `sig_team_shooting_goals_no_shots_allowed`: overlap in defensive suppression framing, but that signal requires `opponent_shots_on_target = 0` and has no possession/clearance/win gate.
  - `sig_team_possession_passing_low_block_frustration`: adjacent low-block tactical framing, but trigger is crossing volume (`cross_attempts > 40`) rather than low-possession winning defense.
  - `sig_team_shooting_goals_defensive_scoring_unit`: shares winning/outcome context but focuses on multi-defender scoring, not defensive resistance profile.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_parking_the_bus.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_parking_the_bus`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_parking_the_bus
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_max_possession_pct` | Maximum possession threshold (`30.0`) | Explicit trigger provenance for reproducibility |
| `trigger_threshold_min_clearances` | Minimum clearances threshold (`30`) | Explicit trigger provenance for reproducibility |
| `trigger_condition_match_win_required` | Win requirement flag (`1`) | Makes mandatory result condition explicit |
| `triggered_team_goals` | Goals scored by triggered team | Core trigger component (winning state) |
| `opponent_goals` | Goals scored by opponent | Core trigger component (winning state comparator) |
| `goal_delta` | Triggered-team goals minus opponent goals | Margin context around low-block win profile |
| `triggered_team_possession_pct` | Triggered-team possession percentage | Core trigger component (low-possession condition) |
| `opponent_possession_pct` | Opponent possession percentage | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential context |
| `triggered_team_clearances` | Triggered-team clearances | Core trigger component (defensive resistance volume) |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_clearances_above_threshold` | Clearances above threshold (`clearances - 30`) | Trigger severity beyond activation boundary |
| `triggered_team_total_shots` | Triggered-team total shots | Attacking volume context under low-possession strategy |
| `opponent_total_shots` | Opponent total shots | Pressure exposure comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Finishing execution context |
| `opponent_shots_on_target` | Opponent shots on target | Defensive containment context |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target threat differential |
| `triggered_team_keeper_saves` | Triggered-team goalkeeper saves | Last-line defensive workload context |
| `opponent_keeper_saves` | Opponent goalkeeper saves | Bilateral save-load comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper workload differential |
| `triggered_team_interceptions` | Triggered-team interceptions | Anticipation/disruption context |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Triggered-team tackles won | Ground-duel defensive output context |
| `opponent_tackles_won` | Opponent tackles won | Bilateral ground-duel comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Triggered-team duels won | Physical contest-control context |
| `opponent_duels_won` | Opponent duels won | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_fouls` | Triggered-team fouls committed | Discipline trade-off context |
| `opponent_fouls` | Opponent fouls committed | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality context for low-possession wins |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality differential |
| `triggered_team_xg_on_target` | Triggered-team expected goals on target | Shot-stopping pressure quality context |
| `opponent_xg_on_target` | Opponent expected goals on target | Bilateral shot-quality-on-target comparator |
| `xg_on_target_delta` | Triggered minus opponent expected goals on target | Net on-target shot-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territory/penetration context for attack efficiency |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy percentage | Ball-retention and execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Distinguishes low-block wins with and without full clean sheets |
