---
signal_id: sig_team_possession_passing_one_sided_passing
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "One-Sided Passing"
trigger: "team accurate passes > 3.0x opponent accurate passes"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_one_sided_passing
  sql: clickhouse/gold/signal/sig_team_possession_passing_one_sided_passing.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_one_sided_passing

## Purpose

Flags matches where one team completes more than three times as many passes as the opponent, capturing extreme circulation control and one-directional ball progression.

## Tactical And Statistical Logic

- Signal name: `sig_team_possession_passing_one_sided_passing`.
- Trigger condition: `triggered_team_accurate_passes > 3.0 * opponent_accurate_passes`.
- Trigger is evaluated symmetrically for home and away teams on full-match (`period = 'All'`) stats.
- Enrichment preserves bilateral passing quality, possession share, territorial progression, and chance-creation context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_one_sided_passing.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_one_sided_passing`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_one_sided_passing
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Anchors deterministic joins to other Gold/Silver match-level assets |
| `match_date` | Match calendar date | Supports partition pruning, chronological analysis, and release QA reproducibility |
| `home_team_id` | Home team identifier | Preserves full fixture context for downstream side mapping |
| `home_team_name` | Home team display name | Improves analyst readability in ad-hoc reviews |
| `away_team_id` | Away team identifier | Preserves full fixture context for downstream side mapping |
| `away_team_name` | Away team display name | Improves analyst readability in ad-hoc reviews |
| `home_score` | Full-time home goals | Adds scoreline context for interpreting possession imbalance outcomes |
| `away_score` | Full-time away goals | Adds scoreline context for interpreting possession imbalance outcomes |
| `triggered_side` | Side that fired the signal (`home` or `away`) | Canonical orientation key for row-level identity and side-safe downstream features |
| `triggered_team_id` | Triggered team identifier | Required triggered-entity identity for tactical attribution |
| `triggered_team_name` | Triggered team display name | Human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Enables bilateral comparison and opponent-linked joins |
| `opponent_team_name` | Opponent team display name | Human-readable bilateral context |
| `trigger_threshold_pass_multiplier` | Constant trigger multiplier (`3.0`) | Makes trigger rule explicit in row-level exports and feature audits |
| `triggered_team_accurate_passes` | Completed passes by triggered team | Core trigger numerator that defines passing monopoly |
| `opponent_accurate_passes` | Completed passes by opponent | Core trigger denominator for one-sidedness detection |
| `triggered_to_opponent_accurate_passes_ratio` | Triggered-to-opponent completed-pass ratio | Quantifies how extreme the passing imbalance was beyond binary trigger |
| `accurate_passes_delta` | Triggered minus opponent completed passes | Net completed-pass gap used for ranking and severity tracking |
| `triggered_team_accurate_pass_share_pct` | Triggered share of combined completed passes (%) | Normalized dominance metric robust to match pace differences |
| `opponent_accurate_pass_share_pct` | Opponent share of combined completed passes (%) | Symmetric complement to preserve bilateral interpretability |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Adds volume denominator for completion-quality interpretation |
| `opponent_pass_attempts` | Opponent pass attempts | Symmetric denominator for bilateral passing quality checks |
| `triggered_team_pass_accuracy_pct` | Triggered team completion rate (%) | Distinguishes controlled circulation from noisy high-volume passing |
| `opponent_pass_accuracy_pct` | Opponent team completion rate (%) | Symmetric passing-quality context for opponent resistance assessment |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Measures quality gap, not only volume gap, in the passing monopoly |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Tests whether completed-pass monopoly aligns with macro ball control |
| `opponent_possession_pct` | Opponent possession share (%) | Symmetric possession baseline for imbalance interpretation |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control indicator paired with completed-pass imbalance |
| `triggered_team_opposition_half_passes` | Triggered team passes in opposition half | Indicates whether monopoly is territorially progressive |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Symmetric territorial progression context |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression gap complementary to pass monopoly |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Connects circulation dominance to high-value final-third access |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Symmetric final-third access context for interpretation |
| `triggered_team_xg` | Triggered team expected goals | Chance-quality output for the dominant-passing side |
| `opponent_xg` | Opponent expected goals | Symmetric chance-quality baseline for the non-dominant side |
| `xg_delta` | Triggered minus opponent expected goals | Evaluates whether passing monopoly translated into superior chance quality |

