---
signal_id: sig_team_creativity_playmaking_total_fluidity
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Total Fluidity"
trigger: "Team has >= 6 different players with at least one key pass proxy (`chances_created >= 1`) in one finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_total_fluidity
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_total_fluidity.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_creativity_playmaking_total_fluidity

## Purpose

Detect team-level distributed playmaking performances where chance creation is spread across many players, highlighting collective creativity instead of reliance on a single creator.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_distinct_key_pass_players >= 6`
- Key-pass proxy:
  - `silver.player_match_stat.chances_created >= 1` at player-match grain.
- Team rollup:
  - Distinct creators are counted per `match_id, team_id`, then matched to home/away sides.
  - Trigger is evaluated independently for home and away, so both teams can trigger in the same fixture.
- Bilateral context:
  - Output retains mirrored `triggered_team_*` and `opponent_*` fields for pass control, territorial progression, shot profile, and chance-quality interpretation.
- Similarity gate note:
  - No active `team | creativity | playmaking` signal exists in the catalog index at implementation time.
  - Closest active team alternatives are `sig_team_possession_passing_pass_marathon` (extreme pass volume) and `sig_team_possession_passing_accurate_unit` (elite pass accuracy), but both measure circulation quality/volume rather than distinct creator dispersion.
  - Closest creativity analogs are player-grain signals such as `sig_player_creativity_playmaking_maestro_output`, which track individual output rather than team-wide creator spread.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_total_fluidity.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_total_fluidity`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_total_fluidity
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deterministic deduplication |
| `match_date` | Match date | Football developer: supports time slicing and backfill reproducibility |
| `home_team_id` | Home team identifier | Football developer: preserves fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for playmaking spread interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for playmaking spread interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity anchor for triggered side |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_distinct_key_pass_players` | Trigger threshold for minimum distinct creators (`6`) | Football developer: explicit rule provenance for QA and governance |
| `triggered_team_distinct_key_pass_players` | Distinct triggered-team players with `chances_created >= 1` | Football developer: core trigger metric for collective creativity |
| `triggered_team_distinct_key_pass_players_above_threshold` | Distinct creator count above threshold (`value - 6`) | Football developer: trigger severity beyond activation floor |
| `opponent_distinct_key_pass_players` | Distinct opponent players with `chances_created >= 1` | Football developer: bilateral creator-dispersion comparator |
| `distinct_key_pass_players_delta` | Triggered minus opponent distinct creators | Football developer: compact collective-creativity edge diagnostic |
| `triggered_team_total_key_passes` | Triggered-team summed key-pass proxy volume (`sum(chances_created)`) | Football developer: chance-creation workload context behind creator spread |
| `opponent_total_key_passes` | Opponent summed key-pass proxy volume | Football developer: bilateral chance-creation volume comparator |
| `total_key_passes_delta` | Triggered minus opponent total key-pass volume | Football developer: net chance-creation flow differential |
| `triggered_team_key_passes_per_creator` | Triggered-team average key-pass proxy per creator | Football developer: intensity-per-creator context around distributed output |
| `opponent_key_passes_per_creator` | Opponent average key-pass proxy per creator | Football developer: bilateral creator-intensity comparator |
| `key_passes_per_creator_delta` | Triggered minus opponent key-pass-per-creator average | Football developer: compact density differential for creator output |
| `triggered_team_multi_key_pass_creators` | Triggered-team creators with at least two key-pass proxies | Football developer: depth-of-creation context beyond one-off events |
| `opponent_multi_key_pass_creators` | Opponent creators with at least two key-pass proxies | Football developer: bilateral depth comparator |
| `multi_key_pass_creators_delta` | Triggered minus opponent multi-key-pass creators | Football developer: concentration-vs-depth balance indicator |
| `triggered_team_top_creator_key_passes` | Highest key-pass proxy total by one triggered-team creator | Football developer: maximum individual creative load |
| `opponent_top_creator_key_passes` | Highest key-pass proxy total by one opponent creator | Football developer: bilateral peak-load comparator |
| `top_creator_key_passes_delta` | Triggered minus opponent top-creator key-pass total | Football developer: side-level peak creator burden differential |
| `triggered_team_top_creator_share_pct` | Share of triggered-team key-pass proxy volume from top creator (%) | Football developer: creator-concentration intensity measure |
| `opponent_top_creator_share_pct` | Share of opponent key-pass proxy volume from top creator (%) | Football developer: bilateral concentration comparator |
| `top_creator_share_delta_pct` | Triggered minus opponent top-creator share (percentage points) | Football developer: compact concentration differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation denominator context for creativity spread |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Football developer: execution-quality numerator context |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: bilateral execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: quality context around distributed creation |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: directional passing-quality edge |
| `triggered_team_opposition_half_passes` | Triggered-team passes completed in opposition half | Football developer: territorial progression context for creator spread |
| `opponent_opposition_half_passes` | Opponent passes completed in opposition half | Football developer: bilateral territorial progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: attacking output volume context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral attacking output comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: finishing-threat execution context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral finishing-threat comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline behind creator dispersion |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-quality differential |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Football developer: match control context for distributed playmaking |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control-state differential |
