CREATE TABLE IF NOT EXISTS oddspedia_bronze.match_payload
(
    oddspedia_match_id String,
    event_date Date,
    source_file String,
    raw_payload_json String CODEC(ZSTD(3)),
    scraped_at Nullable(DateTime),
    loaded_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(loaded_at)
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, oddspedia_match_id);
