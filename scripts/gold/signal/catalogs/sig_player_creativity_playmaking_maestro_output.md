---
signal_id: sig_player_creativity_playmaking_maestro_output
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Maestro Output"
trigger: "Player records >= 5 key passes (chances created) in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold.sig_player_creativity_playmaking_maestro_output
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_maestro_output.sql
  runner: scripts/gold/signal/runners/sig_player_creativity_playmaking_maestro_output.py
---
# sig_player_creativity_playmaking_maestro_output

## Purpose

Flags player performances with high-volume chance creation (`>= 5` key passes) to identify dominant single-match playmaking output.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_key_passes >= 5`
- Trigger is sourced from `silver.player_match_stat.chances_created` (key-pass chance creation).
- Only finished matches are considered (`m.match_finished = 1`) and only players mapped to home/away teams are kept.
- Bilateral passing and territorial context from `silver.period_stat` (`period = 'All'`) is retained to interpret whether the output came in high-control or transition-heavy match states.
- Similarity gate note:
  - `sig_player_possession_passing_creative_hub` is the closest existing signal and uses almost the same metric but with `> 5`; this signal explicitly captures the inclusive threshold case (`>= 5`) under `creativity/playmaking` taxonomy.
  - `sig_player_possession_passing_creative_monopoly` overlaps in creator framing but focuses on share concentration, not absolute key-pass floor.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_maestro_output.sql`
- Runner: `scripts/gold/signal/runners/sig_player_creativity_playmaking_maestro_output.py`
- Target table: `gold.sig_player_creativity_playmaking_maestro_output`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_creativity_playmaking_maestro_output.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match-level join and dedup key |
| `match_date` | Match date | Temporal analysis and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context for interpretation |
| `away_score` | Away full-time goals | Match outcome context for interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Human-readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_key_passes` | Trigger floor (`5`) | Explicit threshold provenance for QA and reproducibility |
| `triggered_player_key_passes` | Triggered player key passes (chances created) | Core trigger metric |
| `triggered_player_key_passes_above_threshold` | Key passes above threshold (`key_passes - 5`) | Trigger severity beyond activation boundary |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context alongside chance volume |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Territorial progression context for playmaking profile |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | High-leverage involvement context near goal |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution baseline |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for risk/reward assessment |
| `triggered_player_minutes_played` | Triggered player minutes | Exposure context for volume interpretation |
| `triggered_player_touches` | Triggered player touches | Overall on-ball involvement context |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Team circulation baseline around player output |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Team passing-quality context |
| `opponent_accurate_passes` | Opponent accurate passes | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution benchmark for player output |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession (%) | Control-state context for creativity conditions |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Quantifies player centrality in ball circulation |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player share of team opposition-box touches (%) | Quantifies player share of high-leverage attacking presence |
