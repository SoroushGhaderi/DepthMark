---
signal_id: sig_player_shooting_goals_persistent_threat
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Persistent Threat Across Match Segments"
trigger: "Player records at least one shot in every 15-minute match segment (00-15, 16-30, 31-45+, 46-60, 61-75, 76-90+) in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_persistent_threat
  sql: clickhouse/gold/signal/sig_player_shooting_goals_persistent_threat.sql
  runner: scripts/gold/signal/runners/sig_player_shooting_goals_persistent_threat.py
---
# sig_player_shooting_goals_persistent_threat

## Purpose

Flags players who sustain shooting presence across the full match by producing at least one shot in every 15-minute segment.

## Tactical And Statistical Logic

- Trigger condition:
  - Match must be finished (`match_finished = 1`).
  - Triggered player must record `>= 1` shot in each segment: `00-15`, `16-30`, `31-45+`, `46-60`, `61-75`, `76-90+`.
- Segmentation logic:
  - Segment assignment is derived from shot event timing using effective minute (`minute + minute_added`, with goal-time fallbacks where needed).
  - Stoppage-time events are retained in the boundary segments (`31-45+`, `76-90+`) to preserve continuity and avoid losing late-phase threat.
- Match-context enrichment:
  - Player finishing context is sourced from `silver.player_match_stat`.
  - Bilateral team and opponent context is sourced from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity gate note:
  - Closest active shooting-goals signals are `sig_player_shooting_goals_shot_volume_monster` and `sig_player_shooting_goals_shot_magnet`.
  - Coexistence rationale: this signal is cadence/coverage-first (segment persistence), while those signals are absolute volume and share-concentration focused.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_persistent_threat.sql`
- Runner: `scripts/gold/signal/runners/sig_player_shooting_goals_persistent_threat.py`
- Target table: `gold_signals.sig_player_shooting_goals_persistent_threat`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_shooting_goals_persistent_threat.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deduplication |
| `match_date` | Match date | Football developer: supports temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time score | Football developer: scoreline context for persistent-threat interpretation |
| `away_score` | Away full-time score | Football developer: scoreline context for persistent-threat interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player output to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: opponent identity for matchup analysis |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_min_shots_per_segment` | Minimum shots required in each segment (`1`) | Football developer: explicit per-segment trigger provenance |
| `trigger_threshold_segment_window_minutes` | Segment window size in minutes (`15`) | Football developer: explicit segmentation rule for reproducibility |
| `trigger_threshold_required_segment_count` | Number of required covered segments (`6`) | Football developer: transparent completeness requirement |
| `triggered_player_shots_segment_00_15` | Triggered-player shots in minutes `00-15` | Football developer: early-phase threat coverage diagnostic |
| `triggered_player_shots_segment_16_30` | Triggered-player shots in minutes `16-30` | Football developer: continuity diagnostic for first-half middle phase |
| `triggered_player_shots_segment_31_45_plus` | Triggered-player shots in minutes `31-45+` | Football developer: late first-half plus stoppage-time threat coverage |
| `triggered_player_shots_segment_46_60` | Triggered-player shots in minutes `46-60` | Football developer: early second-half restart pressure diagnostic |
| `triggered_player_shots_segment_61_75` | Triggered-player shots in minutes `61-75` | Football developer: mid-second-half persistence diagnostic |
| `triggered_player_shots_segment_76_90_plus` | Triggered-player shots in minutes `76-90+` | Football developer: late-match and stoppage-time threat coverage |
| `triggered_player_shot_segments_hit_count` | Number of 15-minute segments with at least one shot | Football developer: core trigger metric for all-phase shooting persistence |
| `triggered_player_shot_segment_coverage_pct` | Share of required segments covered by at least one shot (%) | Football developer: severity ranking for partial/complete coverage analyses |
| `triggered_player_goals` | Goals scored by triggered player | Football developer: finishing outcome attached to persistent-threat profile |
| `triggered_player_expected_goals` | Expected goals generated by triggered player | Football developer: chance-quality load behind persistent shooting cadence |
| `triggered_player_total_shots` | Total shots attempted by triggered player | Football developer: overall volume baseline complementing segment coverage |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: execution-quality context |
| `triggered_player_shot_accuracy_pct` | Shots-on-target share of player shots (%) | Football developer: precision context for sustained shooting behavior |
| `triggered_player_shot_conversion_pct` | Goals per shot for triggered player (%) | Football developer: finishing efficiency context |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot for triggered player | Football developer: average chance profile per attempt |
| `triggered_player_goal_minus_expected_goals` | Player goals minus player expected goals | Football developer: over/under-finishing diagnostic |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting segment persistence |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring context around persistent threat |
| `opponent_goals` | Goals scored by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome context |
| `triggered_team_expected_goals` | Team expected goals for triggered side | Football developer: team chance-quality baseline |
| `opponent_expected_goals` | Team expected goals for opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality balance context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances created by triggered side | Football developer: high-value chance context |
| `opponent_big_chances` | Big chances created by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control profile around persistent shooting output |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent-side touches in opposition box relative to triggered side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of scoring contribution |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Football developer: concentration of shot-taking responsibility |
| `player_share_of_team_shots_on_target_pct` | Triggered player share of team shots on target (%) | Football developer: concentration of on-target execution responsibility |
