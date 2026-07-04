---
signal_id: sig_team_possession_passing_territorial_dominance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Territorial Dominance"
trigger: "Team records >= 40 touches in the opposition box."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_territorial_dominance
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_territorial_dominance.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_territorial_dominance

## Purpose

Detect team-level territorial dominance where repeated opposition-box occupation (`>= 40` touches) indicates sustained control in advanced zones.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_territorial_dominance`
- Trigger condition source: `-- Trigger: Team records >= 40 touches in the opposition box.`
- Emits one row per triggered side (`home` / `away`), preserving bilateral opponent context for fair tactical interpretation.
- Enrichment combines territory (`touches`, `opposition_half_passes`) with execution quality (`pass_accuracy`) and attacking payoff (`shots`, `xg`, `xg_per_opposition_box_touch`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_territorial_dominance.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_territorial_dominance`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_territorial_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across gold match-level assets |
| `match_date` | Match date | Football developer: supports temporal slicing and release validation |
| `home_team_id` | Home team ID | Football developer: fixture identity and side reconstruction |
| `home_team_name` | Home team name | Football developer: analyst-readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture identity and side reconstruction |
| `away_team_name` | Away team name | Football developer: analyst-readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context when reading territorial dominance payoff |
| `away_score` | Full-time away goals | Football developer: outcome context when reading territorial dominance payoff |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: ensures side-oriented interpretation of triggered/opponent fields |
| `triggered_team_id` | Triggered team ID | Football developer: primary team identity for downstream feature joins |
| `triggered_team_name` | Triggered team name | Football developer: readable identity for analysts |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Football developer: bilateral comparator identity |
| `trigger_threshold_opposition_box_touches` | Constant trigger threshold (`40`) | Football developer: explicit threshold traceability for QA and audits |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: direct territorial trigger metric |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territory comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Football developer: net final-third territorial edge |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Football developer: control context behind high box-touch volume |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control gap supporting territorial interpretation |
| `triggered_team_opposition_half_passes` | Triggered-team passes completed in opposition half | Football developer: progression context for sustained territorial pressure |
| `opponent_opposition_half_passes` | Opponent passes completed in triggered-team half | Football developer: bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Football developer: net advanced-territory circulation advantage |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation volume context for dominance style |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `pass_attempts_delta` | Triggered minus opponent pass attempts | Football developer: net passing load differential |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Football developer: passing execution volume under territorial control |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: bilateral passing execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: execution quality context for controlled dominance |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net passing-quality edge |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: attacking output volume from territorial pressure |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral output comparator |
| `shot_volume_delta` | Triggered minus opponent total shots | Football developer: net shot-volume edge from territorial dominance |
| `triggered_team_shots_inside_box` | Triggered-team shots inside the box | Football developer: close-range conversion of box occupation |
| `opponent_shots_inside_box` | Opponent shots inside the box | Football developer: bilateral close-range comparator |
| `shots_inside_box_delta` | Triggered minus opponent shots inside box | Football developer: net penalty-area shooting edge |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: finishing output quality context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral finishing-output comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality output from territorial control |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Football developer: net chance-quality advantage |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: direct high-quality chance count under dominance |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral big-chance comparator |
| `triggered_team_corners` | Triggered-team corners won | Football developer: set-piece pressure context of sustained final-third presence |
| `opponent_corners` | Opponent corners won | Football developer: bilateral set-piece pressure comparator |
| `triggered_team_xg_per_opposition_box_touch` | Triggered-team xG per opposition-box touch | Football developer: efficiency of converting territorial occupation into chance value |
| `opponent_xg_per_opposition_box_touch` | Opponent xG per opposition-box touch | Football developer: bilateral efficiency comparator |
| `xg_per_opposition_box_touch_delta` | Triggered minus opponent xG per opposition-box touch | Football developer: net efficiency edge in chance creation from box occupation |
