# Gold ClickHouse SQL Layout

Gold SQL is split the same way as Silver: **DDL** defines schemas; **DML** runs
transformations.

```text
clickhouse/gold/
  ddl/                         # setup_clickhouse_gold.py
    00_create_database.sql
    01_create_scenario_tables.sql
    create_table_signal_activations.sql
    signals/
      match/                   # create_table_match_*.sql
      team/                    # create_table_team_*.sql
      player/                  # create_table_player_*.sql
    activations/
      create_table_signal_activations_stage.sql
  dml/                         # run_sql_job.py / load_clickhouse_gold.py
    scenarios/
      team/                    # scenario_*.sql
      player/                  # scenario_*.sql
    signals/
      match/                   # sig_match_*.sql
      team/                    # sig_team_*.sql
      player/                  # sig_player_*.sql
    activations/
      signal_activation_final_insert.sql
```

`gold.signal_activations_stage` is ephemeral: the activation builder creates it
from `ddl/activations/` during rebuilds and drops it after the final insert.
