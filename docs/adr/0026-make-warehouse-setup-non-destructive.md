# ADR 0026: Make Warehouse Setup Non-Destructive

## Status

Accepted

## Context

ADR 0020 made ClickHouse layer setup schema-only by removing full-table
optimization, and the runbooks describe setup as safe to repeat. The Gold setup
DDL still contradicted that contract: 16 setup files ran `DROP TABLE IF EXISTS`
before creating every `gold_signals.sig_*` table and `gold.signal_activations`
(347 drops in total). Each setup run therefore emptied all Gold signal and
activation tables, and the Docker entrypoint ran setup on every container start.

The drops were deliberate. They were how a changed signal table definition,
such as the `signal_instance_id` row-identity `DEFAULT` and `ORDER BY` contract,
reached existing tables without `ALTER TABLE`. Removing them makes data safe
but means existing tables no longer pick up DDL changes automatically. The
2026-10-02 whole-repository review rated this P0.

The alternatives were:

- keep auto-applying DDL changes by dropping tables (current behaviour; loses
  data on every run);
- apply additive `ALTER TABLE ... ADD COLUMN` automatically (cannot apply
  sorting-key or identity changes, and conflicts with the documented rule not
  to patch `signal_instance_id` in place);
- ignore differences or only warn (setup succeeds on a stale schema and the
  mismatch surfaces later as a failed or silently wrong load);
- fail closed on differences and make the destructive step an explicit
  operator command.

## Decision

Normal setup is create-only for every warehouse layer: FotMob Bronze, Silver,
Gold, and the Oddspedia setup.

1. Setup SQL may contain only `CREATE DATABASE IF NOT EXISTS` and
   `CREATE TABLE IF NOT EXISTS`. Setup checks every selected file and refuses to
   run if any other statement is present.
2. Before creating anything, setup compares each existing table with its DDL.
   **Schema Drift** is a difference in column names, column types, or the
   `ORDER BY` sorting key. Drift makes setup exit non-zero, list the drifted
   tables, and name the recreation command; setup never drops or alters a table.
   A change confined to a `DEFAULT` expression, such as an activation identity
   scheme version (ADR 0006), is not drift and stays a deliberate operator
   action.
3. **Table Recreation** is the only supported way to apply drift:
   `scripts/maintenance/recreate_clickhouse_tables.py`. It follows the ADR 0020
   maintenance pattern: plan by default, `--execute` to mutate, and an explicit
   selector (`--drifted`, `--table`, `--database`, or a specific `--layer`). It
   drops the selected tables and recreates them empty from setup DDL; it never
   reloads rows. The operator reruns the normal layer loader afterward.
4. Containers do not run setup on start. The Docker entrypoint only executes
   its command; setup is an explicit step, run once for a new warehouse and
   again after setup DDL changes.
5. The activation builder's ephemeral `gold.signal_activations_stage` DDL under
   `clickhouse/gold/ddl/activations/` is not setup DDL. The builder keeps
   dropping and recreating its own stage table.

## Consequences

Repeating setup, restarting containers, and running setup in automation can no
longer erase warehouse rows. A stale schema is reported at setup time instead of
surfacing later as a load failure.

DDL changes to existing tables now take two explicit operator steps, Table
Recreation and a reload, and setup fails until they are done. The drift check
compares normalized text of types and sorting-key expressions as ClickHouse
reports them, so an unusual formatting difference could cause a false failure;
when that happens, fix the comparison rather than bypassing the check.

The one-time drops of the legacy `gold.signal_activations_match` and
`gold.match_reference` tables (ADR 0014) were removed from setup. Warehouses that
still contain them keep them until an operator drops them.

Grants are unchanged: the runtime ClickHouse identity can still drop tables. The
2026-10-02 review's role-split recommendation is tracked in the ADR backlog.
