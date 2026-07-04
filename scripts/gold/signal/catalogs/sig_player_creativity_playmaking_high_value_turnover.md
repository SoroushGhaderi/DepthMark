---
signal_id: sig_player_creativity_playmaking_high_value_turnover
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "High Value Turnover"
trigger: "Player records 0 assists despite >= 5 key passes in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_high_value_turnover
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_high_value_turnover.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_creativity_playmaking_high_value_turnover

## Purpose

Detect high-volume key-pass creators whose output was not converted into assists, highlighting potentially wasteful finishing around the chance provider.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_key_passes >= 5`
  - `triggered_player_assists = 0`
  - finished match scope (`match_finished = 1`)
- Key passes are sourced from `silver.player_match_stat.chances_created`, with assist outcomes from `silver.player_match_stat.assists`.
- Severity is preserved with:
  - `triggered_player_key_passes_above_threshold`
  - `triggered_player_unconverted_key_passes`
  - `triggered_player_assist_minus_expected_assists`
- Bilateral team context from `silver.period_stat` (`period = 'All'`) is retained to contextualize whether unconverted creation happened in dominant or low-control match states.
- Similarity gate note:
  - `sig_player_creativity_playmaking_maestro_output`: same key-pass floor (`>= 5`) but no assist-outcome guard.
  - `sig_player_creativity_playmaking_expected_wizard`: same zero-assist outcome guard but trigger is xA (`>= 1.0`), not key-pass volume.
  - `sig_player_possession_passing_creative_hub`: close metric family but uses strict `> 5` under possession/passing taxonomy.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_high_value_turnover.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_high_value_turnover`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_creativity_playmaking_high_value_turnover
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for interpreting unconverted creation |
| `away_score` | Away full-time goals | Outcome context for interpreting unconverted creation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Human-readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Human-readable bilateral comparator |
| `trigger_threshold_min_key_passes` | Key-pass trigger floor (`5`) | Explicit threshold provenance |
| `trigger_threshold_max_assists` | Assist trigger ceiling (`0`) | Explicit outcome guard provenance |
| `triggered_player_key_passes` | Triggered player key passes | Core trigger metric for creative output volume |
| `triggered_player_key_passes_above_threshold` | Key passes above trigger floor (`key_passes - 5`) | Trigger severity beyond activation |
| `triggered_player_assists` | Triggered player assists | Confirms zero-assist trigger outcome |
| `triggered_player_unconverted_key_passes` | Key passes not converted into assists | Direct proxy for creation-to-assist disconnect |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context around key-pass output |
| `triggered_player_assist_minus_expected_assists` | Assists minus expected assists | Measures conversion underperformance against chance quality |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Progression context around creation burden |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Territory context near chance-creation zones |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution baseline |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context around high-volume creation |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for volume interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution benchmark |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession (%) | Match control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure baseline |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial pressure comparator |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Quantifies circulation centrality of the creator |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player share of team opposition-box touches (%) | Quantifies advanced-territory involvement concentration |
