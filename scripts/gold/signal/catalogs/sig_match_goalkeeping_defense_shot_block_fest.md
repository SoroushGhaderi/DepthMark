---
signal_id: sig_match_goalkeeping_defense_shot_block_fest
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Shot Block Fest"
trigger: "Combined match blocked shots exceed 15."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_goalkeeping_defense_shot_block_fest
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_shot_block_fest.sql
  runner: scripts/gold/signal/runners/sig_match_goalkeeping_defense_shot_block_fest.py
---
# sig_match_goalkeeping_defense_shot_block_fest

## Purpose

Detects finished matches with extreme combined shot-block volume and emits bilateral side-oriented defensive context to evaluate resistance structure, pressure profile, and match control trade-offs.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(shot_blocks_home, 0) + coalesce(shot_blocks_away, 0)) > 15` from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emits two rows (`triggered_side = 'home'` and `triggered_side = 'away'`) at canonical `match_team` grain.
- Severity is represented by `match_combined_shot_blocks_above_threshold = match_combined_shot_blocks - 15`.
- Enrichment keeps bilateral context symmetric for shot blocks, shots faced, save performance, defensive actions, physical contests, discipline, possession, passing quality, and scoreline.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_shot_blocking_unit`: closest shot-block intent overlap, but that signal is team-triggered (`triggered_team_shot_blocks >= 10`) while this signal is match-triggered on combined bilateral shot blocks.
  - `sig_match_goalkeeping_defense_save_fest`: same match-goalkeeping-defense scope, but trigger axis is combined saves (`> 12`) instead of combined shot blocks.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_shot_block_fest.sql`
- Runner: `scripts/gold/signal/runners/sig_match_goalkeeping_defense_shot_block_fest.py`
- Target table: `gold.sig_match_goalkeeping_defense_shot_block_fest`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_goalkeeping_defense_shot_block_fest.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication key and downstream join anchor |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture context for bilateral analysis |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture context for bilateral analysis |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Full-time home goals | Outcome context for defensive-intensity interpretation |
| `away_score` | Full-time away goals | Outcome context for defensive-intensity interpretation |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team identifier | Side-level join key for features and QA |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context |
| `trigger_threshold_min_combined_shot_blocks` | Configured combined-shot-block threshold (`15`) | Makes trigger boundary explicit for auditability |
| `match_combined_shot_blocks` | Combined shot blocks in the match | Core trigger metric for match-level shot-block intensity |
| `match_combined_shot_blocks_above_threshold` | Combined shot blocks above threshold (`value - 15`) | Captures trigger severity beyond activation |
| `triggered_team_shot_blocks` | Triggered-side shot blocks | Side-level defensive resistance contribution |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral shot-block comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_shot_block_share_pct` | Triggered-side share of combined shot blocks (%) | Normalized bilateral contribution |
| `opponent_shot_block_share_pct` | Opponent share of combined shot blocks (%) | Symmetric normalized comparator |
| `shot_block_share_delta_pct` | Triggered minus opponent shot-block share (pp) | Compact normalized balance diagnostic |
| `triggered_team_total_shots_faced` | Triggered-side total shots faced | Defensive pressure context beyond blocked attempts |
| `opponent_total_shots_faced` | Opponent total shots faced | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Triggered-side shots on target faced | Direct keeper-pressure context |
| `opponent_shots_on_target_faced` | Opponent shots on target faced | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Triggered-side keeper saves | Shot-stopping workload/output context |
| `opponent_keeper_saves` | Opponent keeper saves | Bilateral save-volume comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net save workload differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping effectiveness |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral save-effectiveness comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Directional keeper-efficiency gap |
| `triggered_team_clearances` | Triggered-side clearances | Danger-removal workload indicator |
| `opponent_clearances` | Opponent clearances | Bilateral clearance comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_interceptions` | Triggered-side interceptions | Defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Ground-duel defensive output context |
| `opponent_tackles_won` | Opponent successful tackles | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Triggered-side duels won | Physical contest context |
| `opponent_duels_won` | Opponent duels won | Bilateral duel comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel differential |
| `triggered_team_aerials_won` | Triggered-side aerial duels won | Vertical contest context |
| `opponent_aerials_won` | Opponent aerial duels won | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Discipline/aggression trade-off context |
| `opponent_fouls_committed` | Fouls committed by opponent | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around defensive resistance |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation-quality context under pressure |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net ball-security differential |
| `triggered_team_goals` | Goals scored by triggered side | Offensive output context paired with defensive workload |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match result differential from triggered perspective |
| `triggered_team_clean_sheet_flag` | `1` when triggered side conceded zero goals, else `0` | Quick defensive outcome flag for filtering and modeling |
