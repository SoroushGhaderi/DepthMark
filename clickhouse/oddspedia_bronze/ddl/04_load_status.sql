CREATE TABLE IF NOT EXISTS oddspedia_bronze.load_status
(
    load_date Date,
    run_id String,
    status LowCardinality(String),
    inventory_checksum String,
    event_rows UInt64,
    payload_rows UInt64,
    market_rows UInt64,
    error Nullable(String),
    updated_at DateTime64(6, 'UTC') DEFAULT now64(6)
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(load_date)
ORDER BY load_date;
