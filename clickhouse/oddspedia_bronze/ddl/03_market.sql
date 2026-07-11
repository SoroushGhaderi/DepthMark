CREATE TABLE IF NOT EXISTS oddspedia_bronze.market
(
    oddspedia_match_id String,
    event_date Date,
    market_name String,
    lines_json String CODEC(ZSTD(3)),
    source_file String,
    loaded_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(loaded_at)
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, oddspedia_match_id, market_name);
