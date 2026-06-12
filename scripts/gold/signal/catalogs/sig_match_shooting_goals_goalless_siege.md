---
signal_id: sig_match_shooting_goals_goalless_siege
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Goalless Siege"
trigger: "Full-time scoreline is 0-0 and at least one team records >= 25 shots (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_goalless_siege
  sql: clickhouse/gold/signal/sig_match_shooting_goals_goalless_siege.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_goalless_siege.py
---
# sig_match_shooting_goals_goalless_siege

## Purpose

Detect goalless matches where shot volume is extreme for at least one side, then expose bilateral context to diagnose whether the stalemate came from poor finishing, goalkeeper resistance, or asymmetric attacking pressure.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(home_score, 0) = 0`, `coalesce(away_score, 0) = 0`, and `(coalesce(total_shots_home, 0) >= 25 OR coalesce(total_shots_away, 0) >= 25)` at `period = 'All'`.
- Match-level trigger emits two side-oriented rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream joins and feature pipelines.
- Enrichment keeps the stalemate explainable with bilateral shot-share, shot-accuracy, xG, big-chance waste, box-touch penetration, possession, and pass-quality diagnostics.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_match_shooting_goals_boring_stalemate`; this signal is distinct because it combines a strict goalless outcome (`0-0`) with one-sided extreme shot volume (`>= 25` by either team), rather than pure team-level volume or low-event stalemate logic.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_goalless_siege.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_goalless_siege.py`
- Target table: `gold_signals.sig_match_shooting_goals_goalless_siege`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_goalless_siege.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication, QA, and downstream joins. |
| `match_date` | Match date | Enables reproducible backfills and temporal analysis. |
| `home_team_id` | Home team identifier | Preserves fixture context for match-level slicing. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context for match-level slicing. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Verifies the goalless component of the trigger. |
| `away_score` | Full-time away goals | Verifies the goalless component of the trigger. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Team-level join key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable opponent context. |
| `trigger_threshold_min_team_shots` | Configured shot trigger floor (`25`) | Makes trigger provenance explicit for QA and auditability. |
| `match_total_goals` | Combined full-time goals | Confirms the match-level goalless outcome. |
| `match_total_shots` | Combined shots by both teams | Match-level pressure context around the stalemate. |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline. |
| `triggered_team_meets_shot_threshold` | Triggered-side flag for `>= 25` shots | Indicates whether the oriented side is the high-volume siege side. |
| `opponent_meets_shot_threshold` | Opponent flag for `>= 25` shots | Indicates whether the opponent also clears the volume threshold. |
| `both_teams_meet_shot_threshold` | Flag when both teams have `>= 25` shots | Differentiates one-sided siege from bilateral shot chaos. |
| `triggered_team_total_shots` | Triggered-side total shots | Core attacking-volume measure for the oriented side. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shot-pressure differential. |
| `triggered_team_shot_share_pct` | Triggered-side share of match shots (%) | Normalized contribution to total match shot volume. |
| `opponent_shot_share_pct` | Opponent share of match shots (%) | Bilateral normalized shot-share comparator. |
| `shot_share_delta_pct` | Triggered minus opponent shot share (percentage points) | Compact pressure-balance diagnostic. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level shot precision context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized side-level shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Captures which side was more accurate despite 0-0 outcome. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Directional chance-generation differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance count by side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance generation edge. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context for siege narratives. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net finishing-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context behind shot volume. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-access differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context in goalless siege matches. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context in possession phases. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical execution comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Differential circulation-quality diagnostic. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Side-level ball-circulation workload. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential. |
