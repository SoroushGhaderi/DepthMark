# ADR 0029: Split ClickHouse Identities and Isolate Staging

## Status

Accepted

## Context

Setup granted the single application user `SELECT, INSERT, ALTER, CREATE TABLE,
DROP TABLE, TRUNCATE, OPTIMIZE` on every warehouse database, so any bug or
mistaken command could drop or empty a warehouse table. The 2026-10-02 review
rated this P1.

The grants were broad for real reasons. Scoped Silver/Gold loads, the
Oddspedia Bronze loader, and the activation builder created, optimized, and
dropped staging tables inside the warehouse databases. Full-history loads swap
whole tables with `EXCHANGE TABLES`. In the local stack the problem was worse:
the ClickHouse image turns `CLICKHOUSE_USER` into a configuration-file user with
full access, so setup's `GRANT`/`REVOKE` statements on it had no effect.

Verified against ClickHouse 24.10 with a narrowly granted user:

- `SELECT, INSERT, ALTER DELETE` on a target allows `ALTER TABLE ... REPLACE
  PARTITION ... FROM warehouse_stage.*` and `DROP PARTITION`, while denying
  `DROP TABLE`, `CREATE TABLE`, `RENAME`, `TRUNCATE`, `OPTIMIZE`,
  `ALTER UPDATE`, and column changes. A plain `ALTER` grant also allows
  `DROP COLUMN`.
- `EXCHANGE TABLES` is denied without `DROP TABLE` on the target.
- `CREATE TABLE stage AS target` across databases works with `SELECT` on the
  target, and grants on a not-yet-created database are accepted.

Alternatives were wildcard grants on staging-table name prefixes (keeps
staging beside targets, depends on wildcard-grant support and naming
discipline) and only moving `TRUNCATE` to an operator user (leaves `DROP TABLE`
on every table).

## Decision

1. **Staging database.** Every staging table lives in `warehouse_stage`:
   scoped calculation and replacement tables
   (`warehouse_stage._depthmark_<run>_<database>__<table>_calc|_replace`),
   Oddspedia Bronze stages, and `warehouse_stage.signal_activations_stage`.
   Setup creates the database.
2. **Application identity** (`CLICKHOUSE_USER`): `SELECT, INSERT, ALTER DELETE`
   on `bronze`, `oddspedia_bronze`, `silver`, `gold`, `gold_scenarios`, and
   `gold_signals`; `SELECT, INSERT, ALTER DELETE, CREATE TABLE, DROP TABLE,
   OPTIMIZE, TRUNCATE` on `warehouse_stage` only. Routine loads, resolution,
   and quality checks use it.
3. **Maintenance identity** (`CLICKHOUSE_MAINTENANCE_USER` /
   `CLICKHOUSE_MAINTENANCE_PASSWORD`): created by the ClickHouse container with
   access management. Both setup commands, full-history Silver/Gold/activation
   loads, Table Recreation, optimization, drop scripts, and
   `load_fotmob_bronze.py --truncate` use it.
4. Setup always runs as the maintenance identity and creates or resets the
   application user (revoke, then re-grant) on every run. The two names must
   differ. The passwordless local `default` bootstrap path is removed.

## Consequences

The application identity can no longer drop, truncate, optimize, rename, or
alter the columns of a warehouse table; destructive mistakes fail with
`ACCESS_DENIED`. Staging leftovers from failed runs are confined to
`warehouse_stage`.

Deployments need a second secret. Existing local stacks must add
`CLICKHOUSE_MAINTENANCE_PASSWORD` to `.env`, recreate the ClickHouse container
so it creates the maintenance user, and rerun setup to recreate
`CLICKHOUSE_USER` as a narrowly granted SQL user. Data volumes are unaffected.

Full-history loads require maintenance credentials. A separate read-only
reporting identity (for example for TouchDesk) is not yet defined.
