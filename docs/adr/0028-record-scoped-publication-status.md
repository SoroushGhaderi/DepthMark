# ADR 0028: Record Scoped Publication Status

## Status

Accepted

## Context

ADR 0018 made Silver and Gold loads scope-aware: `ScopedReplacementBatch`
stages every selected job before committing, then commits each target table
with `REPLACE PARTITION` (date/month) or `EXCHANGE TABLES` (full history).
ClickHouse has no cross-table transaction, so a failure after the first commit
leaves some tables on the new version and others on the old one. The batch only
logged "rerun the same scope to converge"; nothing durable told readers that a
partition was mixed. The 2026-10-02 review rated this P1.

The Oddspedia Bronze loader already solves the same problem for its three fact
tables: `oddspedia_bronze.load_status` records `staging`, `published`, or
`failed`, and the resolver reads only `published` dates (ADR 0021).

The alternatives were:

- roll back already-committed tables when a later commit fails (doubles copy
  I/O for every load, and the rollback can fail too);
- versioned tables behind views that publication repoints (closest to atomic
  visibility, but doubles storage for about 400 tables and changes every
  reader);
- record publication status durably and make readers check it.

## Decision

Scoped Silver and Gold batches record a **Scope Publication** status in a
layer-owned table: `silver.scope_publication` for the `silver` batch and
`gold.scope_publication` for the `gold_outputs` (scenarios and signals) and
`gold_activations` batches. Setup creates both tables.

- The batch checks that its publication table exists before staging.
- It records `committing` before the first commit, then `published` after every
  target table committed, or `failed` with the committed tables and the error.
  A staging failure records nothing because targets are unchanged.
- Rows are keyed by `(batch, partition_id)`; the latest `updated_at` wins.
  `partition_id` is the replaced `YYYYMM` partition, or `0` for full history.
  A partition row is superseded by a later full-history row, and a full-history
  row that is not `published` marks every partition.
- Readers must not consume a partition whose latest status is not `published`.
  Gold loads refuse to start while any Silver partition is unpublished (Gold
  jobs may read all Silver history), the activation builder refuses unpublished
  Gold outputs, and `check_data_quality.py --strict` fails on unpublished
  partitions in its scope. External readers apply the same query.
- Commits stay table by table; rerunning the same scope converges and publishes.

## Consequences

A partial commit is now durable, visible, and blocks DepthMark's own downstream
loads until a rerun publishes the partition. Absence of rows (history loaded
before this decision) is treated as published.

Existing warehouses must rerun setup to create the two publication tables;
until then scoped loads fail fast with a setup message. External consumers such
as TouchDesk only gain the protection once they check `gold.scope_publication`.

Readers can still observe a mixed partition during the short window between
the first and last commit of a running batch; the `committing` status makes
that window explicit rather than closing it.
