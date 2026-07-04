---
signal_id: sig_player_creativity_playmaking_isolated_creativity
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Isolated Creativity"
trigger: "Player creates >= 50% of the team's total key passes in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_isolated_creativity
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_isolated_creativity.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_creativity_playmaking_isolated_creativity

## Purpose

Detect player performances where one creator carries at least half of a team's key-pass volume in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_total_key_passes > 0`
  - `player_share_of_team_key_passes_pct >= 50.0`
- Key passes are represented by `silver.player_match_stat.chances_created`.
- Team key-pass totals are computed per `(match_id, team_id)` from player-level rows.
- Bilateral passing, possession, and opposition-box context from `silver.period_stat` (`period = 'All'`) is preserved to separate player concentration from overall team game state.
- Similarity gate note:
  - `sig_player_possession_passing_creative_monopoly` is the closest existing signal and uses the same concentration trigger with possession/passing taxonomy.
  - `sig_player_creativity_playmaking_maestro_output` shares key-pass semantics but uses an absolute volume trigger (`>= 5`) rather than team-share concentration.
  - This new signal is intentionally scoped to `creativity/playmaking` taxonomy with explicit key-pass naming and concentration-focused threshold fields.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_isolated_creativity.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_isolated_creativity`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_creativity_playmaking_isolated_creativity
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Time-based analysis and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for interpreting creative burden |
| `away_score` | Away full-time goals | Outcome context for interpreting creative burden |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at player grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Human-readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable bilateral comparator |
| `trigger_threshold_min_player_share_of_team_key_passes_pct` | Trigger threshold (`50.0`) | Explicit concentration floor provenance |
| `triggered_player_key_passes` | Triggered player key passes | Core numerator of isolated creativity trigger |
| `triggered_team_total_key_passes` | Total key passes by triggered player's team | Core denominator for concentration metric |
| `player_share_of_team_key_passes_pct` | Triggered player key-pass share of team total (%) | Core trigger metric (`>= 50.0`) |
| `player_share_of_team_key_passes_above_threshold_pct` | Percentage points above share threshold | Trigger severity beyond activation boundary |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context around concentrated creation |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Progression context around playmaking burden |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Territory context near goal actions |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution baseline |
| `triggered_player_total_passes` | Triggered player pass attempts | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for chance-creation burden |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for concentration interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality context |
| `opponent_accurate_passes` | Accurate passes by opponent | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution benchmark |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession (%) | Match control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure baseline |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial pressure comparator |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Measures whether creative monopoly aligns with circulation monopoly |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player share of team opposition-box touches (%) | Separates pass-led concentration from direct box-presence concentration |
