# Signal Table Contract

Rules for signal DDL under `clickhouse/gold/ddl/signals/`. Tags are defined in
[`README.md`](README.md).

## Layout

1. Signal tables are grouped by entity, family, and subfamily in
   `clickhouse/gold/ddl/signals/<entity>/create_table_<entity>_<family>_<subfamily>.sql`.
2. Each table is `gold_signals.<signal_id>`, and every table MUST have a
   catalog. **[catalog]**
3. Setup DDL is create-only: `CREATE TABLE IF NOT EXISTS` and nothing else.
   **[setup]** (ADR 0026) To change an existing table's columns or sorting key,
   edit the DDL, then recreate the table with
   `python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted` and
   repopulate it. Never add `ALTER`, `DROP`, or migration statements to setup.
4. Tables use `ReplacingMergeTree(inserted_at)` with
   `inserted_at DateTime DEFAULT now()` and `PARTITION BY toYYYYMM(match_date)`,
   so scoped replacement (ADR 0018) can replace whole months.

## Identity Chain

A signal's Row Identity is one chain, and every link uses the same columns in
the same order:

```text
catalog row_identity            [match_id, triggered_player_id, triggered_team_id]
  → DDL signal_instance_id      SHA256('v1' | signal_id | match_id | triggered_player_id | triggered_team_id)
  → Signal Activation ID        the same hash in gold.signal_activations
```

1. Every `row_identity` column MUST exist in the table. **[catalog]**
2. The table MUST declare
   `signal_instance_id String DEFAULT lower(hex(SHA256(concat('v1', '|', '<signal_id>', '|', coalesce(toString(<column>), ''), ...))))`
   over `row_identity` in catalog order, with `match_id` prepended when
   `row_identity` does not contain it. **[catalog]** The expression is
   `signal_instance_id_expression()` in `src/fotmob/gold/signal_catalog.py`;
   the activation builder uses the same function.
3. `ORDER BY` MUST end with `signal_instance_id`. Its leading columns are a
   physical sort key, not the Row Identity, and need not match `row_identity`.
   **[catalog]**
4. `v1` is the Signal Identity Scheme Version (ADR 0006). It changes only with
   an explicit identity-scheme migration, never for ordinary SQL, threshold, or
   catalog text edits.
5. DML does not write `signal_instance_id` or `inserted_at`; ClickHouse fills
   them from their defaults. **[test]**
   `test_signal_dml_insert_columns_match_ddl_and_catalog_identity`
