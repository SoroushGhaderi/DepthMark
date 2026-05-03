# Scripts Layout

This file documents script locations and canonical entry points.
For script behavior rules, naming/style handwriting, function design, and update policy, use `SCRIPTS_CONTRACT.md` as the source of truth.

## Canonical Entry Points

Use these for all new documentation, automation, and daily runs:

- `scripts/bronze/scrape_fotmob.py`
- `scripts/bronze/load_clickhouse.py`
- `scripts/bronze/drop_clickhouse.py`
- `scripts/bronze/setup_clickhouse.py`
- `scripts/silver/load_clickhouse.py`
- `scripts/silver/drop_clickhouse.py`
- `scripts/silver/setup_clickhouse.py`
- `scripts/gold/load_clickhouse_scenarios.py`
- `scripts/gold/drop_clickhouse_scenarios.py`
- `scripts/gold/setup_clickhouse_gold.py`
- `scripts/orchestration/pipeline.py`
- `scripts/orchestration/setup_clickhouse.py`

### Dry-Run Support

- `scripts/silver/load_clickhouse.py --dry-run`
- `scripts/gold/load_clickhouse_scenarios.py --dry-run`

## Operational Utility Scripts

- `scripts/ensure_directories.py`
- `scripts/health_check.py`
- `scripts/refresh_turnstile.py`
- `scripts/mongodb/init_indexes.py`

## Quality Check Scripts

- `scripts/quality/check_bronze_to_silver_reconciliation.py`
- `scripts/quality/check_logging_style.py`

## Scenario Scripts

These `scripts/gold/scenario/scenario_*.py` runners are discovered and executed by `scripts/gold/load_clickhouse_scenarios.py`.
Scenario standards are defined in `scripts/gold/scenario/SCENARIOS_CONTRACT.md`.

- `scripts/gold/scenario/scenario_demolition.py`
- `scripts/gold/scenario/scenario_defensive_shutdown_win.py`
- `scripts/gold/scenario/scenario_underdog_heist.py`
- `scripts/gold/scenario/scenario_dead_ball_dominance.py`
- `scripts/gold/scenario/scenario_low_block_heist.py`
- `scripts/gold/scenario/scenario_tactical_stalemate.py`
- `scripts/gold/scenario/scenario_great_escape.py`
- `scripts/gold/scenario/scenario_one_man_army.py`
- `scripts/gold/scenario/scenario_last_gasp.py`
- `scripts/gold/scenario/scenario_shot_stopper.py`
- `scripts/gold/scenario/scenario_war_zone.py`
- `scripts/gold/scenario/scenario_clinical_finisher.py`
- `scripts/gold/scenario/scenario_russian_roulette.py`
- `scripts/gold/scenario/scenario_efficiency_machine.py`
- `scripts/gold/scenario/scenario_away_day_masterclass.py`
- `scripts/gold/scenario/scenario_key_pass_king.py`
- `scripts/gold/scenario/scenario_wildcard.py`
- `scripts/gold/scenario/scenario_lead_by_example.py`
- `scripts/gold/scenario/scenario_young_gun.py`
- `scripts/gold/scenario/scenario_second_half_warriors.py`
- `scripts/gold/scenario/scenario_big_chance_killer.py`
- `scripts/gold/scenario/scenario_ten_men_stand.py`
- `scripts/gold/scenario/scenario_progressive_powerhouse.py`
- `scripts/gold/scenario/scenario_sterile_control.py`
- `scripts/gold/scenario/scenario_defensive_masterclass.py`
- `scripts/gold/scenario/scenario_metronome.py`
- `scripts/gold/scenario/scenario_high_intensity_engine.py`
- `scripts/gold/scenario/scenario_box_to_box_general.py`
- `scripts/gold/scenario/scenario_against_the_grain.py`
- `scripts/gold/scenario/scenario_unpunished_aggression.py`
- `scripts/gold/scenario/scenario_pressing_masterclass.py`
- `scripts/gold/scenario/scenario_elite_shot_stopper.py`
- `scripts/gold/scenario/scenario_hollow_dominance.py`
- `scripts/gold/scenario/scenario_touchline_terror.py`
- `scripts/gold/scenario/scenario_line_breaker.py`
- `scripts/gold/scenario/scenario_basketball_match.py`
- `scripts/gold/scenario/scenario_lightning_rod.py`
- `scripts/gold/scenario/scenario_human_shield.py`
- `scripts/gold/scenario/scenario_golden_touch.py`
- `scripts/gold/scenario/scenario_black_hole.py`
- `scripts/gold/scenario/scenario_high_line_trap.py`
- `scripts/gold/scenario/scenario_ghost_poacher.py`
- `scripts/gold/scenario/scenario_route_one_masterclass.py`
- `scripts/gold/scenario/scenario_total_suffocation.py`
- `scripts/gold/scenario/scenario_territorial_suffocation.py`
- `scripts/gold/scenario/scenario_clinical_pivot.py`
- `scripts/gold/scenario/scenario_chaos_engine.py`
- `scripts/gold/scenario/scenario_tired_legs.py`
- `scripts/gold/scenario/SCENARIOS_CATALOG.md`

## Signal Scripts

These `scripts/gold/signal/runners/signal_*.py` runners are also discovered and executed by `scripts/gold/load_clickhouse_scenarios.py`.

- `scripts/gold/signal/runners/sig_team_possession_passing_high_press_victim.py`

## Signal Catalogs

Per-signal docs live in `scripts/gold/signal/catalogs/` and include tactical logic plus output schema tables:

- `scripts/gold/signal/catalogs/README.md`
- `scripts/gold/signal/catalogs/sig_team_possession_passing_high_press_victim.md`
