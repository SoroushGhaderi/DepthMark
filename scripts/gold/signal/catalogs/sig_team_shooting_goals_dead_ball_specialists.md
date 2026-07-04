---
signal_id: sig_team_shooting_goals_dead_ball_specialists
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Dead-Ball Specialists"
trigger: "Team scores >= 2 goals from corner/free-kick dead-ball events in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_dead_ball_specialists
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_dead_ball_specialists.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_dead_ball_specialists

## Purpose

Detect teams that produce at least two goals from dead-ball shooting situations, highlighting set-piece finishing dominance at team level.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_dead_ball_goals >= 2`
- Dead-ball goal taxonomy uses `silver.shot.situation IN ('FromCorner', 'FreeKick', 'SetPiece')` with own goals excluded (`is_own_goal = 0`).
- Trigger is evaluated independently for home and away teams in finished matches.
- Bilateral output is preserved through `triggered_team_*` and `opponent_*` metrics for tactical comparison.
- Similarity gate note: closest active signals are `sig_team_possession_passing_set_piece_focus` and `sig_match_possession_passing_set_piece_dominance`; this signal is distinct because it is finishing-outcome driven (`>= 2` dead-ball goals) rather than possession/restart-volume driven.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_dead_ball_specialists.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_dead_ball_specialists`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_dead_ball_specialists
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream models and QA checks |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: fixed match orientation context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed match orientation context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context around trigger |
| `away_score` | Away full-time goals | Football developer: outcome context around trigger |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity anchor for triggered entity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `trigger_threshold_min_dead_ball_goals` | Trigger threshold for minimum dead-ball goals (`2`) | Football developer: explicit rule provenance for governance and QA |
| `triggered_team_goals` | Total goals scored by triggered team | Football developer: scoreline baseline for dead-ball share interpretation |
| `opponent_goals` | Total goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome edge |
| `triggered_team_dead_ball_goals` | Dead-ball goals by triggered team | Football developer: core trigger metric |
| `opponent_dead_ball_goals` | Dead-ball goals by opponent | Football developer: bilateral dead-ball output comparator |
| `dead_ball_goals_delta` | Triggered minus opponent dead-ball goals | Football developer: net set-piece finishing dominance measure |
| `triggered_team_corner_goals` | Corner-situation goals by triggered team | Football developer: disaggregates dead-ball source mix |
| `opponent_corner_goals` | Corner-situation goals by opponent | Football developer: bilateral corner-finishing comparator |
| `corner_goals_delta` | Triggered minus opponent corner goals | Football developer: corner-source finishing edge diagnostic |
| `triggered_team_free_kick_goals` | Free-kick-situation goals by triggered team | Football developer: direct/indirect free-kick scoring evidence |
| `opponent_free_kick_goals` | Free-kick-situation goals by opponent | Football developer: bilateral free-kick scoring comparator |
| `free_kick_goals_delta` | Triggered minus opponent free-kick goals | Football developer: free-kick finishing imbalance metric |
| `triggered_team_set_piece_goals` | Generic `SetPiece`-tag goals by triggered team | Football developer: captures residual dead-ball finishing not tagged as explicit corner/free-kick |
| `opponent_set_piece_goals` | Generic `SetPiece`-tag goals by opponent | Football developer: bilateral residual dead-ball scoring comparator |
| `set_piece_goals_delta` | Triggered minus opponent generic `SetPiece` goals | Football developer: residual dead-ball source imbalance |
| `triggered_team_dead_ball_goal_share_pct` | Share of triggered-team goals from dead balls (%) | Football developer: dependence measure on dead-ball finishing |
| `opponent_dead_ball_goal_share_pct` | Share of opponent goals from dead balls (%) | Football developer: bilateral dependence comparator |
| `dead_ball_goal_share_delta_pct` | Triggered minus opponent dead-ball goal share (percentage points) | Football developer: concise side-level style difference |
| `triggered_team_dead_ball_shots` | Dead-ball shots by triggered team | Football developer: volume denominator for dead-ball conversion context |
| `opponent_dead_ball_shots` | Dead-ball shots by opponent | Football developer: bilateral dead-ball shot-volume comparator |
| `triggered_team_dead_ball_xg` | Dead-ball expected goals by triggered team | Football developer: chance-quality baseline for dead-ball output |
| `opponent_dead_ball_xg` | Dead-ball expected goals by opponent | Football developer: bilateral chance-quality comparator on dead-ball attempts |
| `dead_ball_xg_delta` | Triggered minus opponent dead-ball xG | Football developer: net dead-ball chance-quality edge |
| `triggered_team_dead_ball_goals_per_shot` | Triggered-team dead-ball goals per dead-ball shot | Football developer: dead-ball conversion intensity metric |
| `opponent_dead_ball_goals_per_shot` | Opponent dead-ball goals per dead-ball shot | Football developer: bilateral conversion intensity comparator |
| `dead_ball_goals_per_shot_delta` | Triggered minus opponent dead-ball goals-per-shot ratio | Football developer: net dead-ball finishing efficiency edge |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: broader shooting-volume context |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: execution baseline around set-piece output |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: whole-match chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: overall chance-generation edge context |
| `triggered_team_set_play_xg` | Set-play xG by triggered team from period stats | Football developer: aggregate set-play quality corroboration for trigger |
| `opponent_set_play_xg` | Set-play xG by opponent from period stats | Football developer: bilateral set-play quality comparator |
| `set_play_xg_delta` | Triggered minus opponent set-play xG | Football developer: net set-play chance-quality edge |
| `triggered_team_corners` | Corners won by triggered team | Football developer: restart-pressure and territory proxy |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral restart-pressure comparator |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Football developer: control context around dead-ball finishing profile |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: technical execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact possession-quality imbalance metric |
