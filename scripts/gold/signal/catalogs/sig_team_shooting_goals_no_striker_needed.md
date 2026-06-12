---
signal_id: sig_team_shooting_goals_no_striker_needed
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "No Striker Needed"
trigger: "Team scores > 2 non-own goals and all of those goals are scored by midfielders or defenders in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_no_striker_needed
  sql: clickhouse/gold/signal/sig_team_shooting_goals_no_striker_needed.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_no_striker_needed.py
---
# sig_team_shooting_goals_no_striker_needed

## Purpose

Detect team-level high-scoring outputs where forwards are not required for finishing, i.e. the team scores at least three non-own goals and every scorer is classified as midfielder or defender.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_non_own_goals > 2`
  - `triggered_team_forward_non_own_goals = 0`
  - `triggered_team_non_own_goals = triggered_team_midfielder_defender_non_own_goals`
- Goal events come from `silver.shot` with `is_goal = 1` and `is_own_goal = 0`.
- Scorer role classification uses `silver.match_personnel` (`usual_playing_position_id`) with starter-priority resolution (`argMax` over `starter` then `substitute`).
- Trigger evaluation is side-specific (home and away independently) and limited to finished matches.
- Bilateral context is preserved through symmetric `triggered_team_*` and `opponent_*` role-composition and shooting-context metrics.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_defensive_scoring_unit` and `sig_team_shooting_goals_shared_scoring`; this signal coexists because it is role-composition constrained (no forward scorers with >2 team non-own goals) rather than defender-scorer diversity or generic scorer distribution.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_no_striker_needed.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_no_striker_needed.py`
- Target table: `gold_signals.sig_team_shooting_goals_no_striker_needed`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_no_striker_needed.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: deterministic key for joins and deduplication |
| `match_date` | Match date | Football developer: temporal slicing and replayability |
| `home_team_id` | Home team identifier | Football developer: fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row-side identity |
| `triggered_team_id` | Triggered team identifier | Football developer: team identity anchor |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_non_own_goals` | Minimum non-own goals required by trigger (`3`) | Football developer: explicit threshold provenance for QA/governance |
| `trigger_threshold_required_forward_non_own_goals` | Required forward non-own goals under trigger (`0`) | Football developer: explicit no-forward trigger provenance |
| `triggered_team_non_own_goals` | Triggered-team non-own goals | Football developer: core trigger volume baseline |
| `opponent_non_own_goals` | Opponent non-own goals | Football developer: bilateral scoring comparator |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Football developer: side-level non-own scoring edge |
| `triggered_team_midfielder_non_own_goals` | Triggered-team non-own goals scored by midfielders | Football developer: midfield contribution volume |
| `opponent_midfielder_non_own_goals` | Opponent non-own goals scored by midfielders | Football developer: bilateral midfield-scoring comparator |
| `midfielder_non_own_goals_delta` | Triggered minus opponent midfielder non-own goals | Football developer: side-level midfield-scoring differential |
| `triggered_team_defender_non_own_goals` | Triggered-team non-own goals scored by defenders | Football developer: defender contribution volume |
| `opponent_defender_non_own_goals` | Opponent non-own goals scored by defenders | Football developer: bilateral defender-scoring comparator |
| `defender_non_own_goals_delta` | Triggered minus opponent defender non-own goals | Football developer: side-level defender-scoring differential |
| `triggered_team_midfielder_defender_non_own_goals` | Triggered-team non-own goals from midfielders + defenders | Football developer: direct numerator for no-striker trigger |
| `opponent_midfielder_defender_non_own_goals` | Opponent non-own goals from midfielders + defenders | Football developer: bilateral non-forward-scoring comparator |
| `midfielder_defender_non_own_goals_delta` | Triggered minus opponent midfielder+defender non-own goals | Football developer: side-level non-forward scoring differential |
| `triggered_team_forward_non_own_goals` | Triggered-team non-own goals scored by forwards | Football developer: direct trigger guardrail metric (must be zero) |
| `opponent_forward_non_own_goals` | Opponent non-own goals scored by forwards | Football developer: bilateral role-composition comparator |
| `forward_non_own_goals_delta` | Triggered minus opponent forward non-own goals | Football developer: forward-reliance differential |
| `triggered_team_other_or_unknown_non_own_goals` | Triggered-team non-own goals from non-1/2/3 or unknown roles | Football developer: data-quality and classification leakage diagnostic |
| `opponent_other_or_unknown_non_own_goals` | Opponent non-own goals from non-1/2/3 or unknown roles | Football developer: bilateral role-classification QA comparator |
| `other_or_unknown_non_own_goals_delta` | Triggered minus opponent other/unknown-role non-own goals | Football developer: compact role-classification anomaly differential |
| `triggered_team_distinct_midfielder_defender_goal_scorers` | Distinct triggered-team scorers among midfielders/defenders | Football developer: scorer diversity within the permitted role set |
| `opponent_distinct_midfielder_defender_goal_scorers` | Distinct opponent scorers among midfielders/defenders | Football developer: bilateral scorer-diversity comparator |
| `distinct_midfielder_defender_goal_scorers_delta` | Triggered minus opponent distinct midfielder/defender scorers | Football developer: side-level permitted-role scorer-diversity edge |
| `triggered_team_distinct_forward_goal_scorers` | Distinct triggered-team forward scorers | Football developer: trigger-rule validation and forward usage signal |
| `opponent_distinct_forward_goal_scorers` | Distinct opponent forward scorers | Football developer: bilateral forward-scoring diversity comparator |
| `distinct_forward_goal_scorers_delta` | Triggered minus opponent distinct forward scorers | Football developer: forward-scorer diversity differential |
| `triggered_team_midfielder_defender_goal_share_pct` | Share of triggered-team non-own goals from midfielders/defenders (%) | Football developer: normalized trigger intensity metric |
| `opponent_midfielder_defender_goal_share_pct` | Share of opponent non-own goals from midfielders/defenders (%) | Football developer: bilateral normalized comparator |
| `midfielder_defender_goal_share_delta_pct` | Triggered minus opponent midfielder/defender goal share (percentage points) | Football developer: compact role-share differential |
| `triggered_team_goals` | Triggered-team official full-time goals | Football developer: official outcome context |
| `opponent_goals` | Opponent official full-time goals | Football developer: bilateral scoreline context |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: match-outcome framing |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: attacking-volume context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution-quality baseline |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation edge |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
