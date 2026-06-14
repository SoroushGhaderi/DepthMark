# Gold Scenario Query Contexts

Scenarios are grouped by query context:

- `team/`: team-centric and match-context scenarios (team-level outcomes, tactical profiles, and match dynamics)
- `player/`: player-centric scenarios (individual impact, roles, and performance signatures)

Scenario SQL jobs populate `gold_scenarios.scenario_*` tables and are executed
through `scripts/gold/run_sql_job.py` or the bulk Gold loader with
`--part scenarios` / `--part all`.

Catalog entries live in `scripts/gold/scenario/scenarios_catalog.md`.
