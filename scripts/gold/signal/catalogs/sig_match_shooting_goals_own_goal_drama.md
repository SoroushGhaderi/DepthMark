---
signal_id: sig_match_shooting_goals_own_goal_drama
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Own-Goal Drama"
trigger: "Match features >= 1 own goal."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_own_goal_drama
  sql: clickhouse/gold/signal/sig_match_shooting_goals_own_goal_drama.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_own_goal_drama.py
---
# sig_match_shooting_goals_own_goal_drama

## Purpose

Detect finished matches with at least one own goal and expose side-oriented scoring, finishing, and control context so downstream consumers can analyze own-goal dependence and bilateral match dynamics.

## Tactical And Statistical Logic

- Trigger condition: `match_total_own_goals >= 1`, derived from `silver.shot` events where `is_goal = 1`, `is_own_goal = 1`, and `is_home_goal` is available.
- Emits two rows per triggered match (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Own-goal attribution keeps both beneficiary and conceding views: a home-beneficiary own goal implies an away side own-goal concession, and vice versa.
- Enrichment includes own-goal share/dependence metrics, non-own-goal decomposition, shot quality/volume (`shots_on_target`, `xg`), and control context (`possession_pct`, `pass_accuracy_pct`).
- Similarity gate note: closest active signals are `sig_match_shooting_goals_penalty_decided_match` and `sig_team_shooting_goals_no_striker_needed`; this signal is distinct because it is triggered specifically by own-goal events at match scope, not by penalty-only scorelines or team role-based non-own-goal composition.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_own_goal_drama.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_own_goal_drama.py`
- Target table: `gold_signals.sig_match_shooting_goals_own_goal_drama`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_own_goal_drama.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication key. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for own-goal impact analysis. |
| `away_score` | Full-time away goals | Scoreline context for own-goal impact analysis. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_match_own_goals` | Configured own-goal trigger threshold (`1`) | Makes trigger governance explicit for QA. |
| `match_total_goals` | Combined goals in the match | Baseline match scoring magnitude. |
| `match_total_own_goals` | Combined own-goal events in match | Core trigger metric. |
| `match_total_non_own_goals` | Combined non-own goals in match | Separates normal finishing from own-goal contribution. |
| `own_goal_share_of_match_goals_pct` | Share of match goals that were own goals (%) | Normalized match-level own-goal intensity. |
| `home_own_goals_benefited` | Own goals awarded to home side | Home-side beneficiary attribution. |
| `away_own_goals_benefited` | Own goals awarded to away side | Away-side beneficiary attribution. |
| `home_own_goals_conceded` | Own goals conceded by home side | Home-side concession attribution. |
| `away_own_goals_conceded` | Own goals conceded by away side | Away-side concession attribution. |
| `triggered_team_own_goals_benefited` | Own goals awarded to triggered side | Side-level beneficiary own-goal output. |
| `opponent_own_goals_benefited` | Own goals awarded to opponent side | Bilateral beneficiary comparator. |
| `own_goals_benefited_delta` | Triggered minus opponent beneficiary own goals | Net own-goal beneficiary edge. |
| `triggered_team_own_goals_conceded` | Own goals conceded by triggered side | Side-level concession own-goal output. |
| `opponent_own_goals_conceded` | Own goals conceded by opponent side | Bilateral concession comparator. |
| `own_goals_conceded_delta` | Triggered minus opponent conceded own goals | Net own-goal concession differential. |
| `triggered_team_total_goals` | Total goals credited to triggered side | Side scoring baseline before decomposition. |
| `opponent_total_goals` | Total goals credited to opponent side | Bilateral scoring comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome edge from triggered perspective. |
| `triggered_team_non_own_goals` | Triggered-side non-own goals | Isolates open-play/set-piece/penalty non-own scoring output. |
| `opponent_non_own_goals` | Opponent non-own goals | Bilateral non-own scoring comparator. |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Net non-own scoring differential. |
| `triggered_team_own_goal_dependency_pct` | Share of triggered-side goals from own goals (%) | Normalized dependence on opponent mistakes. |
| `opponent_own_goal_dependency_pct` | Share of opponent goals from own goals (%) | Bilateral own-goal dependence comparator. |
| `own_goal_dependency_delta_pct` | Triggered minus opponent own-goal dependence (percentage points) | Compact relative dependence diagnostic. |
| `triggered_team_total_shots` | Triggered-side total shots | Shooting-volume context behind trigger. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Precision-volume context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision-volume comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral precision-rate comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Net precision differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Finishing over/under-performance signal. |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Bilateral finishing comparator. |
| `goals_minus_xg_gap` | Triggered minus opponent goals-minus-xG | Relative finishing over/under-performance edge. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance-volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net high-quality chance differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net technical-execution differential. |
