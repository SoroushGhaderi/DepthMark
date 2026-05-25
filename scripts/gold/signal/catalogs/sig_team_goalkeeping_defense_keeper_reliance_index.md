---
signal_id: sig_team_goalkeeping_defense_keeper_reliance_index
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Keeper Reliance Index"
trigger: "Goalkeeper makes >= 5 saves while team possession is < 40% in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_goalkeeping_defense_keeper_reliance_index
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_keeper_reliance_index.sql
  runner: scripts/gold/signal/runners/sig_team_goalkeeping_defense_keeper_reliance_index.py
---
# sig_team_goalkeeping_defense_keeper_reliance_index

## Purpose

Detect low-possession matches where defensive survival depends on high goalkeeper intervention, then preserve bilateral workload, control-state, and outcome context to profile keeper-reliant defensive performances.

## Tactical And Statistical Logic

- Trigger condition for each side:
  - `triggered_team_keeper_saves >= 5`
  - `triggered_team_possession_pct < 40.0`
  - `match_finished = 1` at `period = 'All'`
- Rows are emitted at canonical `match_team` grain (`triggered_side = 'home'` or `'away'`), so both sides can trigger in the same match when both satisfy the rule.
- Trigger severity is exposed via `triggered_team_keeper_saves_above_threshold`.
- Save execution quality is contextualized by `triggered_team_save_rate_pct`, `opponent_save_rate_pct`, and `save_rate_delta_pct`.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_save_fest`: overlap on high-save matches, but this signal is side-triggered and adds explicit low-possession gating.
  - `sig_team_goalkeeping_defense_clean_sheet_efficiency`: adjacent keeper-pressure theme, but that signal requires clean sheets and on-target-faced thresholds rather than low-possession keeper-reliance.
  - `sig_team_goalkeeping_defense_parking_the_bus`: shared low-possession defensive framing, but parking-the-bus is win + clearance-volume driven, not goalkeeper-save driven.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_keeper_reliance_index.sql`
- Runner: `scripts/gold/signal/runners/sig_team_goalkeeping_defense_keeper_reliance_index.py`
- Target table: `gold.sig_team_goalkeeping_defense_keeper_reliance_index`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_goalkeeping_defense_keeper_reliance_index.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing for backfills and trend analysis |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for defensive interpretation |
| `away_score` | Away full-time goals | Scoreline context for defensive interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_keeper_saves` | Minimum keeper-saves threshold (`5`) | Explicit trigger provenance for reproducibility |
| `trigger_threshold_max_possession_pct` | Maximum possession threshold (`40.0`) | Explicit low-possession boundary for reproducibility |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Core trigger metric for keeper workload |
| `opponent_keeper_saves` | Keeper saves by opponent side | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent keeper saves | Net goalkeeper workload differential |
| `triggered_team_keeper_saves_above_threshold` | Keeper saves above threshold (`saves - 5`) | Trigger intensity beyond activation boundary |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Direct shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Shot-stopping efficiency context under pressure |
| `opponent_save_rate_pct` | Opponent-side save rate (%) | Bilateral efficiency comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net shot-stopping efficiency differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Overall defensive workload context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral workload comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net workload differential |
| `triggered_team_expected_goals_faced` | Expected goals faced by triggered side | Chance-quality pressure context |
| `opponent_expected_goals_faced` | Expected goals faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent expected goals faced | Net chance-quality exposure differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel output context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral ground-duel comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical contest-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-defense context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral vertical-defense comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial-control differential |
| `triggered_team_fouls` | Fouls by triggered side | Defensive discipline context |
| `opponent_fouls` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Core low-possession trigger component |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control-state differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context under pressure |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral circulation-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Outcome translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes zero, else 0 | Distinguishes keeper-reliance with and without full clean sheets |
