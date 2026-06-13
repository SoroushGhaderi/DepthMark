---
signal_id: sig_player_creativity_playmaking_assist_hat_trick
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Assist Hat-Trick Playmaker"
trigger: "Player records >= 3 assists in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_assist_hat_trick
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_assist_hat_trick.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_assist_hat_trick

## Purpose

Detect player-level playmaking performances where a single player records an assist hat-trick (`>= 3`) in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_assists >= 3`
  - `match_finished = 1`
- Trigger source is `silver.player_match_stat.assists` at `match_player` grain.
- Output preserves bilateral team context from `silver.period_stat` (`period = 'All'`) for passing quality, possession control, and territorial pressure interpretation.
- Severity and diagnostic context are retained through:
  - `triggered_player_assists_above_threshold`
  - `triggered_player_assist_minus_expected_assists`
  - `triggered_player_assists_per_chance_created_pct`
  - `player_share_of_team_goals_assisted_pct`
- Similarity gate note:
  - `sig_player_creativity_playmaking_assist_brace`: closest overlap in taxonomy and metric (`assists`), but that signal triggers at lower boundary (`>= 2`) while this one isolates rarer assist hat-trick output (`>= 3`).
  - `sig_player_possession_passing_xa_overperformer`: overlaps on high-assist outcomes, but additionally requires low xA (`< 0.5`) and is positioned under `possession/passing`.
  - Coexistence rationale: this signal is an intentionally stricter creativity/playmaking outcome tier for extreme direct assist production.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_assist_hat_trick.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_assist_hat_trick`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_assist_hat_trick
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication key |
| `match_date` | Match date | Temporal analysis and reproducible backfills |
| `home_team_id` | Home team ID | Fixture context orientation |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture context orientation |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match-outcome context for assist impact |
| `away_score` | Away full-time goals | Match-outcome context for assist impact |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream models |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_assists` | Trigger floor (`3`) | Explicit threshold provenance and QA guard |
| `triggered_player_assists` | Player assists | Core trigger metric |
| `triggered_player_assists_above_threshold` | Assists above trigger floor (`assists - 3`) | Trigger severity beyond activation |
| `triggered_player_expected_assists` | Player expected assists (xA) | Chance-quality context for assist output |
| `triggered_player_assist_minus_expected_assists` | Assists minus xA | Outcome-versus-expected conversion context |
| `triggered_player_chances_created` | Player total chances created | Volume context around assist output |
| `triggered_player_assists_per_chance_created_pct` | Assist conversion of created chances (%) | Efficiency context for direct final-pass output |
| `triggered_player_passes_final_third` | Player final-third passes | Progression context for playmaking profile |
| `triggered_player_touches_opposition_box` | Player opposition-box touches | Advanced-territory involvement context |
| `triggered_player_accurate_passes` | Player accurate passes | Passing execution context |
| `triggered_player_total_passes` | Player pass attempts | Workload and role centrality context |
| `triggered_player_pass_accuracy_pct` | Player pass accuracy (%) | Passing reliability context |
| `triggered_player_minutes_played` | Player minutes played | Exposure context for interpretation |
| `triggered_player_touches` | Player total touches | Overall involvement context |
| `triggered_team_goals` | Goals scored by triggered player's team | Team scoring context for assist concentration |
| `opponent_goals` | Goals scored by opponent team | Bilateral outcome comparator |
| `triggered_team_big_chances` | Big chances by triggered team | Team chance-quality baseline |
| `opponent_big_chances` | Big chances by opponent team | Bilateral chance-quality comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession (%) | Team control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `triggered_team_touches_opposition_box` | Triggered team opposition-box touches | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial-pressure comparator |
| `player_share_of_team_goals_assisted_pct` | Share of team goals directly assisted by player (%) | Quantifies player contribution concentration in final output |
| `player_share_of_team_passes_pct` | Share of team pass attempts by player (%) | Quantifies role centrality in circulation |
| `player_share_of_team_opposition_box_touches_pct` | Share of team opposition-box touches by player (%) | Quantifies player's final-third/box involvement concentration |
