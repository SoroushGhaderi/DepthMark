---
signal_id: sig_player_creativity_playmaking_chance_machine
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Chance Machine"
trigger: "Player creates >= 3 big chances (Opta definition) in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_chance_machine
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_chance_machine.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_chance_machine

## Purpose

Detects player performances with repeated high-value chance creation, flagging match-level playmakers who generate at least three big chances for teammates.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_big_chances_created >= 3`
- Big-chance creation is resolved from `silver.shot` where:
  - `assist_player_id = triggered_player_id`
  - and assisted shot matches Opta-style big-chance proxy: `situation` contains `big chance` or `expected_goals >= 0.30`.
- Finished-match scope and valid fixture mapping are enforced:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - player team must match home/away side.
- Team control and territorial context are sourced from `silver.period_stat` (`period = 'All'`) so creation output can be interpreted against possession and circulation state.
- Similarity gate note:
  - `sig_player_possession_passing_high_risk_passer`: closest overlap on big-chance creation counting from `silver.shot`, but that signal also requires low pass accuracy and sits under possession taxonomy.
  - `sig_player_creativity_playmaking_maestro_output`: same creativity/playmaking family but key-pass trigger (`chances_created >= 5`) rather than big-chance creation.
  - `sig_player_possession_passing_deadball_creator`: overlaps on big-chance creation logic, but is limited to indirect free-kick situations.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_chance_machine.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_chance_machine`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_chance_machine
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable opponent context |
| `trigger_threshold_min_big_chances_created` | Big-chance trigger floor (`3`) | Explicit trigger provenance and QA guard |
| `triggered_player_big_chances_created` | Big chances created by triggered player | Core trigger metric |
| `triggered_player_big_chances_created_above_threshold` | Big chances above trigger floor (`value - 3`) | Trigger severity beyond activation |
| `triggered_player_chances_created` | Total chances created (key passes) by triggered player | Volume context around high-value creation |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context supporting playmaking output |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Progression context for creative profile |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | High-leverage territorial involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution numerator context |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload denominator context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for creative risk profile |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for output interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_big_chances` | Big chances by triggered player's team | Team-level high-value creation baseline |
| `opponent_big_chances` | Big chances by opponent team | Bilateral high-value creation comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Team circulation baseline around player output |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `player_share_of_team_big_chances_pct` | Triggered player share of team big chances (%) | Concentration of high-leverage creation responsibility |
| `player_share_of_team_chances_created_pct` | Triggered player share of team total chances created (%) | Concentration of overall chance-creation responsibility |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Role centrality in team circulation |
