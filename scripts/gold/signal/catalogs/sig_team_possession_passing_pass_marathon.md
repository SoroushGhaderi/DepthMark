---
signal_id: sig_team_possession_passing_pass_marathon
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Pass Marathon"
trigger: "team completes >= 800 total passes in full-match period stats (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_pass_marathon
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_pass_marathon.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_pass_marathon

## Purpose

Triggers when a team reaches extreme full-match passing volume (`>= 800` completed passes), signaling sustained circulation control and long-possession game states.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_total_passes >= 800` using `silver.period_stat` rows where `period = 'All'`.
- Signal is side-specific (`home` / `away`) and emits one row per triggered side, so both teams can independently trigger in the same match.
- Enrichment preserves bilateral context for pass quality, possession split, territorial progression, and chance creation quality.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_pass_marathon.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_pass_marathon`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_pass_marathon
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Date of the match | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Home team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Home team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Away team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Away team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Full-time home goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Full-time away goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: preserves orientation so side/opponent readings remain correct |
| `triggered_team_id` | Team ID of the side that crossed the threshold | Football developer: stable triggered-entity identity for joins and QA |
| `triggered_team_name` | Team name of the triggered side | Football developer: human-readable triggered-entity identity |
| `opponent_team_id` | Team ID of the opponent side | Football developer: symmetric bilateral context for tactical interpretation |
| `opponent_team_name` | Team name of the opponent side | Football developer: symmetric bilateral context for tactical interpretation |
| `trigger_threshold_total_passes` | Constant trigger threshold (`800`) | Football developer: explicit threshold provenance for reproducibility and QA |
| `triggered_team_total_passes` | Total completed passes by the triggered team | Football developer: direct trigger metric for classifying pass-marathon matches |
| `opponent_total_passes` | Total completed passes by the opponent | Football developer: bilateral comparator for circulation asymmetry |
| `total_passes_delta` | Triggered minus opponent total passes | Football developer: net passing-control differential for tactical profiling |
| `triggered_team_pass_share_pct` | Share of total match completed passes owned by triggered side (%) | Football developer: normalizes raw volume by match-wide circulation load |
| `opponent_pass_share_pct` | Share of total match completed passes owned by opponent (%) | Football developer: bilateral normalization pair for the same denominator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: denominator context for completion quality and intent |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral denominator context |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Football developer: raw quality numerator around the trigger condition |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: bilateral quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: distinguishes controlled marathons from noisy possession |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral quality benchmark |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: directional passing-quality edge around high volume |
| `triggered_team_possession_pct` | Triggered-team full-match possession (%) | Football developer: links passing marathon to ball-control dominance |
| `opponent_possession_pct` | Opponent full-match possession (%) | Football developer: bilateral control-state comparator |
| `possession_delta` | Triggered minus opponent possession (%) | Football developer: net control indicator paired with pass-volume dominance |
| `triggered_team_opposition_half_passes` | Triggered-team passes completed in the opposition half | Football developer: territorial progression context for high-volume circulation |
| `opponent_opposition_half_passes` | Opponent passes completed in the opposition half | Football developer: bilateral progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: final-third penetration context behind the passing load |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral penetration comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality output to test productivity of the marathon |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Football developer: net chance-quality balance under high passing volume |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: shooting-volume context around the trigger |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: shot-quality execution context for high-volume possession |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral finishing-threat comparator |
