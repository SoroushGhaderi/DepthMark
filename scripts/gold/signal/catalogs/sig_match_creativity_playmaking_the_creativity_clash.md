---
signal_id: sig_match_creativity_playmaking_the_creativity_clash
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "The Creativity Clash"
trigger: "Both teams record >= 1.5 expected assists (xA) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_creativity_playmaking_the_creativity_clash
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_the_creativity_clash.sql
  runner: scripts/gold/signal/runners/sig_match_creativity_playmaking_the_creativity_clash.py
---
# sig_match_creativity_playmaking_the_creativity_clash

## Purpose

Detect finished matches where both teams generate substantial creative output (`xA >= 1.5` each),
capturing bilateral playmaking clashes rather than one-sided chance creation.

## Tactical And Statistical Logic

- Trigger condition:
  - `home_expected_assists >= 1.5`
  - `away_expected_assists >= 1.5`
  - with `period = 'All'`, `match_finished = 1`, and valid `match_id`.
- Team creative aggregates are sourced from `silver.player_match_stat`:
  - `team_expected_assists = sum(expected_assists)`
  - `team_key_passes = sum(chances_created)`
- Emits one row per side (`triggered_side = 'home'` and `'away'`) to preserve canonical
  `match_team` grain and symmetric downstream usage.
- Enrichment adds conversion, shot quality/volume, progression, box access, and possession context
  to explain whether bilateral xA parity translates into balanced outcomes.
- Similarity gate note:
  - `sig_team_creativity_playmaking_one_sided_vision` is a key-pass monopoly signal
    (`triggered >= 10`, `opponent = 0`), while this signal requires both sides to be highly creative.
  - `sig_team_creativity_playmaking_chance_barrage` captures unilateral high key-pass volume, while
    this signal is explicitly bilateral on xA thresholds.
  - `sig_match_possession_passing_keeper_playmaking_battle` is a match-level bilateral playmaking
    analogue but goalkeeper-pass driven, not chance-quality (`xA`) driven.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_the_creativity_clash.sql`
- Runner: `scripts/gold/signal/runners/sig_match_creativity_playmaking_the_creativity_clash.py`
- Target table: `gold.sig_match_creativity_playmaking_the_creativity_clash`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_creativity_playmaking_the_creativity_clash.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and deduplication anchor |
| `match_date` | Match date | Backfill reproducibility and time slicing |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team identifier | Side-specific key for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_team_expected_assists` | Minimum per-team xA threshold (`1.5`) | Explicit trigger provenance for QA and governance |
| `match_total_expected_assists` | Combined expected assists from both teams | Match-level creativity intensity signal |
| `triggered_team_expected_assists` | Triggered-side expected assists | Core trigger metric for side context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral trigger comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity quality differential |
| `triggered_team_key_passes` | Triggered-side key passes (`chances_created`) | Creativity volume context around xA |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_expected_assists_per_key_pass` | Triggered-side expected assists per key pass | Average chance quality per creation action |
| `opponent_expected_assists_per_key_pass` | Opponent expected assists per key pass | Bilateral per-action quality comparator |
| `expected_assists_per_key_pass_delta` | Triggered minus opponent expected assists per key pass | Net per-action creative quality edge |
| `triggered_team_goals` | Triggered-side goals | Outcome context for creativity realization |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_chance_conversion_pct` | Triggered-side goals per key pass (%) | Finishing realization over created chances |
| `opponent_chance_conversion_pct` | Opponent goals per key pass (%) | Bilateral realization comparator |
| `chance_conversion_delta_pct` | Triggered minus opponent chance-conversion rate (%) | Net finishing-efficiency differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Possession-circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third pressure differential |
