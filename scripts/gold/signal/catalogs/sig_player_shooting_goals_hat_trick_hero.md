---
signal_id: sig_player_shooting_goals_hat_trick_hero
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Hat-Trick Hero"
trigger: "Player scores >= 3 goals in a single match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold.sig_player_shooting_goals_hat_trick_hero
  sql: clickhouse/gold/signal/sig_player_shooting_goals_hat_trick_hero.sql
  runner: scripts/gold/signal/runners/sig_player_shooting_goals_hat_trick_hero.py
---
# sig_player_shooting_goals_hat_trick_hero

## Purpose

Detects player-level hat-trick performances (`>= 3` goals) and preserves bilateral match context so analysts can separate pure finishing eruptions from broader team dominance.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_goals >= 3`.
- Identity and orientation:
  - Player identity is preserved via `triggered_player_*`.
  - Team/opponent identity is preserved via `triggered_team_*`, `opponent_team_*`, and canonical `triggered_side`.
- Match-context enrichment:
  - Player-level shooting context from `silver.player_match_stat` (xG, shots, shots on target, shot accuracy proxy, minutes).
  - Bilateral team/opponent context from `silver.period_stat` (`period = 'All'`) for shots, shots on target, big chances, possession, box touches, and xG.
  - Outcome context from `silver.match` (final scoreline and side-relative goal delta).
- Similarity note:
  - This differs from `sig_player_shooting_goals_clinical_brace` by removing the low-xG constraint and raising goal threshold to `>= 3`, focusing on absolute scoring explosion rather than xG-overperformance filtering.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_hat_trick_hero.sql`
- Runner: `scripts/gold/signal/runners/sig_player_shooting_goals_hat_trick_hero.py`
- Target table: `gold.sig_player_shooting_goals_hat_trick_hero`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_shooting_goals_hat_trick_hero.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across Gold signal and downstream feature tables |
| `match_date` | Match date | Football developer: temporal analysis and cohorting |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context for trigger interpretation |
| `away_score` | Full-time away goals | Football developer: outcome context for trigger interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation key for side-aware slicing |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: binds player trigger to team-level context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_goals` | Minimum-goals trigger threshold (`3`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `triggered_player_goals` | Goals scored by triggered player | Football developer: core trigger metric and event intensity |
| `triggered_player_expected_goals` | Expected goals by triggered player | Football developer: chance-quality context behind raw scoring output |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: volume context for hat-trick profile |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: shot quality execution context |
| `triggered_player_shot_accuracy_pct` | Shot accuracy percentage of triggered player | Football developer: finishing precision context |
| `triggered_player_expected_goals_per_shot` | Triggered player xG per shot | Football developer: average chance quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus xG for triggered player | Football developer: finishing over/under-performance diagnostic |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for scoring burst intensity |
| `goals_above_threshold` | Triggered goals above threshold (`goals - 3`) | Football developer: quantifies trigger-margin strength |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring context around player output |
| `opponent_goals` | Goals scored by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome edge context |
| `triggered_team_expected_goals` | Triggered-team expected goals | Football developer: team chance-quality baseline around hat trick |
| `opponent_expected_goals` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team xG minus opponent xG | Football developer: net chance-quality control context |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: team shooting-volume context |
| `opponent_total_shots` | Total shots by opponent team | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent team | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-value chance volume context |
| `opponent_big_chances` | Big chances by opponent team | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control/territory context for scoring burst |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered team's box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player's share of team goals (%) | Football developer: concentration of finishing responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player's share of team xG (%) | Football developer: chance-load concentration around triggered player |
| `player_share_of_team_total_shots_pct` | Triggered player's share of team shots (%) | Football developer: shooting-volume concentration context |
