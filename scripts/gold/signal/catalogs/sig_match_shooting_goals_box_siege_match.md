---
signal_id: sig_match_shooting_goals_box_siege_match
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Match Box Siege"
trigger: "Combined match touches in the opposition box exceed 80 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_shooting_goals_box_siege_match
  sql: clickhouse/gold/signal/sig_match_shooting_goals_box_siege_match.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_box_siege_match.py
---
# sig_match_shooting_goals_box_siege_match

## Purpose

Detect finished matches with extreme combined penalty-area territorial pressure (`touches_opp_box_home + touches_opp_box_away > 80`) and expose bilateral side-oriented context for shot execution, chance quality, and control diagnostics.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(touches_opp_box_home, 0) + coalesce(touches_opp_box_away, 0)) > 80` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment keeps box-territory dominance interpretable via touch-share splits, shot volume and precision, conversion, xG, chance creation, possession, passing, and corner context.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_box_siege` and `sig_match_shooting_goals_high_pressure_finish`; this signal is distinct because it is match-scoped and triggered by combined box-touch intensity, not team-only inside-box shots or late-minute shot bursts.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_box_siege_match.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_box_siege_match.py`
- Target table: `gold.sig_match_shooting_goals_box_siege_match`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_box_siege_match.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication, QA, and downstream joins. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture context for bilateral analysis. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context for bilateral analysis. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for pressure interpretation. |
| `away_score` | Full-time away goals | Scoreline context for pressure interpretation. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key for downstream models. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_total_touches_opposition_box_exclusive` | Exclusive trigger boundary (`80`) | Makes trigger provenance explicit for QA and audits. |
| `match_total_touches_opposition_box` | Combined opposition-box touches | Core trigger magnitude for territorial pressure intensity. |
| `match_total_shots` | Combined shots by both teams | Match attacking-volume baseline around the box siege. |
| `match_total_shots_on_target` | Combined shots on target | Match precision baseline for pressure conversion analysis. |
| `match_total_shot_accuracy_pct` | Combined on-target rate (%) | Normalized match-level shooting precision context. |
| `match_total_xg` | Combined expected goals | Match chance-quality baseline. |
| `match_total_goals` | Combined full-time goals | Outcome context versus chance and pressure process. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Side-oriented territorial-pressure count. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial-pressure comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territorial dominance differential. |
| `triggered_team_touches_opposition_box_share_pct` | Triggered-side share of combined box touches (%) | Normalized side contribution to box pressure. |
| `opponent_touches_opposition_box_share_pct` | Opponent share of combined box touches (%) | Bilateral normalized comparator. |
| `opposition_box_touch_share_delta_pct` | Triggered minus opponent box-touch share (percentage points) | Compact territorial-balance diagnostic. |
| `triggered_team_total_shots` | Triggered-side total shots | Side attacking-volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shooting-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level precision volume. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision-volume comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized side-level shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Directional precision-gap diagnostic. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side finishing-efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance creation edge. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context behind pressure profile. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Side circulation-volume context. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-volume differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net ball-retention execution differential. |
| `triggered_team_corners` | Triggered-side corners won | Repeat-entry and sustained-pressure context. |
| `opponent_corners` | Opponent corners won | Bilateral sustained-pressure comparator. |
| `corner_delta` | Triggered minus opponent corners | Net set-play pressure differential. |
