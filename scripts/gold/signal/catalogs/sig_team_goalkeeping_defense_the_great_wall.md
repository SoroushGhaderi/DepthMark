---
signal_id: sig_team_goalkeeping_defense_the_great_wall
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "The Great Wall"
trigger: "Team blocks >= 50% of opposition shot attempts in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_goalkeeping_defense_the_great_wall
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_the_great_wall.sql
  runner: scripts/gold/signal/runners/sig_team_goalkeeping_defense_the_great_wall.py
---
# sig_team_goalkeeping_defense_the_great_wall

## Purpose

Detect matches where a team blocks at least half of opposition shot attempts, then preserve bilateral defensive workload and control context to explain how that block-rate wall profile emerges.

## Tactical And Statistical Logic

- Trigger condition for each side:
  - `triggered_team_total_shots_faced >= 1`
  - `triggered_team_shot_block_rate_pct >= 50.0`
  - `match_finished = 1` at `period = 'All'`
- Triggered-side block rate is computed as `100 * triggered_team_shot_blocks / triggered_team_total_shots_faced`.
- Rows are emitted at canonical `match_team` grain (`triggered_side = 'home'` or `'away'`), so both sides can trigger in the same match if both satisfy the rate rule.
- Trigger severity is explicit through `triggered_team_shot_block_rate_above_threshold_pct`.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_shot_blocking_unit`: closest overlap, but this signal uses normalized shot-block **rate** (`>= 50%`) while that one uses raw shot-block **volume** (`>= 10`).
  - `sig_match_goalkeeping_defense_shot_block_fest`: same tactical theme of blocked shots, but match-triggered on combined bilateral blocks rather than side-triggered rate.
  - `sig_team_goalkeeping_defense_wide_blockade`: same family/subfamily, but wide-blockade trigger is cross-defense volume, not shot-block conversion against faced shots.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_the_great_wall.sql`
- Runner: `scripts/gold/signal/runners/sig_team_goalkeeping_defense_the_great_wall.py`
- Target table: `gold.sig_team_goalkeeping_defense_the_great_wall`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_goalkeeping_defense_the_great_wall.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key and deduplication anchor |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for defensive interpretation |
| `away_score` | Away full-time goals | Scoreline context for defensive interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identity |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_shot_block_rate_pct` | Minimum block-rate threshold (`50.0`) | Explicit normalized trigger boundary for reproducibility |
| `trigger_threshold_min_opposition_total_shots` | Minimum opposition-shot denominator (`1`) | Documents denominator guardrail for valid rate logic |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Core numerator of block-rate trigger |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral shot-block comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_total_shots_faced` | Total opposition shots faced by triggered side | Core denominator of block-rate trigger |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent shots faced | Net pressure-exposure differential |
| `triggered_team_shot_block_rate_pct` | Triggered-side blocked-shot rate (%) | Core normalized trigger metric |
| `opponent_shot_block_rate_pct` | Opponent blocked-shot rate (%) | Bilateral normalized comparator |
| `shot_block_rate_delta_pct` | Triggered minus opponent block-rate (pp) | Net normalized shot-blocking advantage |
| `triggered_team_shot_block_rate_above_threshold_pct` | Block-rate points above threshold (`rate - 50`) | Trigger severity beyond activation boundary |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Direct keeper-pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Last-line workload context |
| `opponent_keeper_saves` | Keeper saves by opponent side | Bilateral goalkeeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net keeper-workload differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release baseline |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling baseline |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control baseline |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral vertical-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial-control differential |
| `triggered_team_fouls` | Fouls by triggered side | Defensive discipline context |
| `opponent_fouls` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context around defensive block profile |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation-quality context under pressure |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates block-wall intensity from clean-sheet outcome |
