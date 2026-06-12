---
signal_id: sig_team_possession_passing_accurate_unit
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Accurate Unit"
trigger: "Team overall pass accuracy exceeds 92% in full-match period stats (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_accurate_unit
  sql: clickhouse/gold/signal/sig_team_possession_passing_accurate_unit.sql
  runner: scripts/gold/signal/runners/sig_team_possession_passing_accurate_unit.py
---
# sig_team_possession_passing_accurate_unit

## Purpose

Triggers when a team records elite full-match pass accuracy above `92%`, flagging highly synchronized possession units.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_pass_accuracy_pct > 92.0` from `silver.period_stat` rows where `period = 'All'`.
- Signal emits side-oriented rows (`home` / `away`), so both teams can trigger in the same match.
- Enrichment retains bilateral passing volume, field-territory distribution, possession share, and shot/xG context to distinguish sterile control from productive precision.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_accurate_unit.sql`
- Runner: `scripts/gold/signal/runners/sig_team_possession_passing_accurate_unit.py`
- Target table: `gold_signals.sig_team_possession_passing_accurate_unit`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_possession_passing_accurate_unit.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across Gold and TouchDesk assets. |
| `match_date` | Calendar match date | Football developer: supports time slicing and backtests. |
| `home_team_id` | Home team ID | Football developer: fixture orientation context. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team ID | Football developer: fixture orientation context. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context around the style trigger. |
| `away_score` | Full-time away goals | Football developer: outcome context around the style trigger. |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row orientation for match-team grain. |
| `triggered_team_id` | Team ID of the triggered side | Football developer: primary identity key for downstream features. |
| `triggered_team_name` | Team name of the triggered side | Football developer: human-readable team attribution. |
| `opponent_team_id` | Opponent team ID | Football developer: preserves bilateral interpretation. |
| `opponent_team_name` | Opponent team name | Football developer: preserves bilateral interpretation. |
| `trigger_threshold_pass_accuracy_pct` | Trigger threshold constant (`92.0`) | Football developer: explicit threshold provenance for QA and explainability. |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Football developer: denominator context for reliability of elite accuracy. |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral pace and possession comparator. |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Football developer: raw numerator behind the trigger metric. |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: bilateral passing-quality comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy percentage | Football developer: core trigger signal value. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Football developer: bilateral quality baseline. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: directional quality edge indicator. |
| `triggered_team_possession_pct` | Triggered side possession percentage | Football developer: control-state context for elite completion profiles. |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: contextualizes whether elite accuracy came with territorial control. |
| `triggered_team_own_half_passes` | Triggered team own-half pass count | Football developer: build-up depth context for the completion profile. |
| `opponent_own_half_passes` | Opponent own-half pass count | Football developer: bilateral field-distribution comparator. |
| `triggered_team_own_half_pass_share_pct` | Share of triggered-team passes played in own half | Football developer: distinguishes conservative circulation from progressive control. |
| `opponent_own_half_pass_share_pct` | Share of opponent passes played in own half | Football developer: bilateral shape and territory comparator. |
| `triggered_team_opposition_half_passes` | Triggered team opposition-half passes | Football developer: territorial progression context. |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Football developer: bilateral progression comparator. |
| `triggered_team_opposition_half_pass_share_pct` | Share of triggered-team passes in opposition half | Football developer: indicates field tilt while preserving precision. |
| `opponent_opposition_half_pass_share_pct` | Share of opponent passes in opposition half | Football developer: bilateral field-tilt comparator. |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Football developer: penetration context beyond circulation quality. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral penetration comparator. |
| `triggered_team_total_shots` | Triggered team total shots | Football developer: attacking output context around elite passing accuracy. |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral attacking-volume comparator. |
| `triggered_team_xg` | Triggered team expected goals | Football developer: chance-quality output context for the possession profile. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent xG | Football developer: net attacking quality balance under elite passing control. |
