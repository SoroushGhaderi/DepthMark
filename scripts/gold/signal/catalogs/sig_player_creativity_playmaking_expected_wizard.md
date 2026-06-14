---
signal_id: sig_player_creativity_playmaking_expected_wizard
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Expected Wizard"
trigger: "Player records >= 1.0 expected assists (xA) with 0 actual assists in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_expected_wizard
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_expected_wizard.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_expected_wizard

## Purpose

Detect player-level high-quality chance creation performances where expected assists reach at least `1.0` but no official assist is credited.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_expected_assists >= 1.0`
  - `triggered_player_assists = 0`
  - finished match scope (`match_finished = 1`)
- Trigger values are sourced from `silver.player_match_stat` and enriched with bilateral team context from `silver.period_stat` (`period = 'All'`).
- Rows are emitted at `match_player` grain with contract-compliant identity fields for player and team.
- Severity is preserved using:
  - `expected_assists_above_threshold`
  - `triggered_player_assist_minus_expected_assists`
- Similarity gate note:
  - `sig_player_possession_passing_xa_underperformer`: near-identical core intent, but that signal uses strict threshold `xA > 1.0` and is categorized under `possession/passing`.
  - `sig_player_possession_passing_xa_overperformer`: opposite outcome profile (`assists >= 2` with low xA), included as a complementary baseline.
  - Coexistence rationale: this signal is intentionally retained as a creativity/playmaking taxonomy variant and uses inclusive threshold boundary (`>= 1.0`) for boundary-value capture.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_expected_wizard.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_expected_wizard`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_expected_wizard
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home goals at full time | Outcome context for unconverted xA |
| `away_score` | Away goals at full time | Outcome context for unconverted xA |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation for match-player rows |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable attribution for catalog consumers |
| `triggered_team_id` | Triggered player's team ID | Team context for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_expected_assists` | Trigger xA threshold (`1.0`) | Explicit trigger provenance |
| `trigger_threshold_max_assists` | Trigger assist ceiling (`0`) | Explicit outcome guard provenance |
| `triggered_player_expected_assists` | Player expected assists (xA) | Core trigger metric for chance-quality creation |
| `triggered_player_assists` | Player official assists | Confirms unconverted creation outcome |
| `triggered_player_assist_minus_expected_assists` | Assists minus xA | Captures finishing underperformance against chance quality |
| `expected_assists_above_threshold` | xA margin above threshold (`xA - 1.0`) | Trigger severity beyond binary activation |
| `triggered_player_chances_created` | Chances created by player | Volume context behind xA |
| `triggered_player_passes_final_third` | Final-third passes by player | Progression context for creation profile |
| `triggered_player_touches_opposition_box` | Touches in opposition box by player | Territorial presence context |
| `triggered_player_accurate_passes` | Accurate passes by player | Passing execution context |
| `triggered_player_total_passes` | Total passes by player | Usage/load context |
| `triggered_player_pass_accuracy_pct` | Player pass accuracy percentage | Normalized passing-quality context |
| `triggered_player_minutes_played` | Minutes played | Reliability and exposure context |
| `triggered_player_touches` | Total touches by player | Involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent | Bilateral quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy percentage | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent possession percentage | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator |
| `player_share_of_team_passes_pct` | Player share of team pass attempts (%) | Centrality in team circulation |
| `player_share_of_team_opposition_box_touches_pct` | Player share of team opposition-box touches (%) | Centrality in advanced-territory involvement |
