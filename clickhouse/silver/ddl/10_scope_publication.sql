-- Publication status for scoped Silver batches (ADR 0028).
-- One row per status change; the latest row per (batch, partition_id) wins.
-- partition_id is the replaced YYYYMM partition, or 0 for a full-history batch.
-- Readers must not consume a partition whose latest status is not 'published'.
CREATE TABLE IF NOT EXISTS silver.scope_publication
(
    batch LowCardinality(String),
    partition_id UInt32,
    run_id String,
    scope_label String,
    status LowCardinality(String),
    tables Array(String),
    committed_tables Array(String),
    error Nullable(String),
    updated_at DateTime64(6, 'UTC') DEFAULT now64(6)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (batch, partition_id);
