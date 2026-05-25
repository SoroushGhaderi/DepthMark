---
signal_id: sig_player_creativity_playmaking_fullback_playmaker
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Fullback Playmaker"
trigger: "Fullback records >= 5 successful passes into the box (proxied by passes_final_third) in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold.sig_player_creativity_playmaking_fullback_playmaker
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_fullback_playmaker.sql
  runner: scripts/gold/signal/runners/sig_player_creativity_playmaking_fullback_playmaker.py
---
# sig_player_creativity_playmaking_fullback_playmaker

## Purpose

Detect fullbacks who act as high-frequency playmaking outlets by repeatedly progressing possession
into advanced box-access zones during finished matches.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_successful_box_passes_proxy >= 5`
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `triggered_player_position_id IN (2, 5)` (fullback proxy)
- Source limitation note:
  - `silver.player_match_stat` does not expose direct `passes_into_penalty_area`.
  - This signal uses `passes_final_third` as explicit proxy
    (`triggered_player_successful_box_passes_proxy_source = 'passes_final_third_proxy'`).
- Position scope is resolved from `silver.match_personnel` with starter-priority role resolution
  per `(match_id, person_id)`.
- Finished-match scope and valid side mapping are enforced:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - player team must map to home/away side.
- Bilateral passing, territorial, and control context is retained from `silver.period_stat`
  (`period = 'All'`).
- Similarity gate note:
  - `sig_player_creativity_playmaking_box_penetrator` is the closest metric overlap (same `>= 5`
    proxy trigger on `passes_final_third`), but it is role-agnostic.
  - `sig_player_creativity_playmaking_the_quarterback` shares role-scoped creativity framing for
    defenders, but targets center-backs and long-ball completion, not fullback box-access proxy.
  - Coexistence rationale: this signal is the fullback-specific variant of box-progression
    playmaking and retains explicit positional gating.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_fullback_playmaker.sql`
- Runner: `scripts/gold/signal/runners/sig_player_creativity_playmaking_fullback_playmaker.py`
- Target table: `gold.sig_player_creativity_playmaking_fullback_playmaker`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_creativity_playmaking_fullback_playmaker.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and deduplication anchor |
| `match_date` | Match date | Temporal slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Bilateral fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Bilateral fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match-outcome context |
| `away_score` | Away full-time goals | Match-outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable opponent context |
| `triggered_player_role_group` | Role label (`fullback`) | Explicit role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Tactical deployment QA for fullback gate |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Stable defender-role gate provenance |
| `trigger_threshold_min_successful_box_passes_proxy` | Trigger floor (`5`) | Explicit trigger provenance for QA |
| `trigger_threshold_required_usual_playing_position_id` | Required usual-playing-position ID (`1`) | Documents deterministic defender filter |
| `trigger_fullback_position_ids` | Fullback proxy position IDs (`2,5`) | Documents deterministic fullback scope |
| `triggered_player_successful_box_passes_proxy` | Proxy count for successful box passes from final-third passes | Core trigger metric under source constraints |
| `triggered_player_successful_box_passes_proxy_source` | Proxy source label | Makes metric provenance explicit |
| `triggered_player_successful_box_passes_proxy_above_threshold` | Proxy margin above threshold (`value - 5`) | Trigger severity beyond activation |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Raw supporting progression metric |
| `triggered_player_chances_created` | Chances created by triggered player | Creative-output context around progression |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Advanced-territory involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution numerator context |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload denominator context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Passing efficiency context |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial-pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `player_share_of_team_box_passes_proxy_pct` | Player proxy-box-pass share of team opposition-half passes (%) | Concentration context for fullback progression responsibility |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Role centrality in overall circulation |
