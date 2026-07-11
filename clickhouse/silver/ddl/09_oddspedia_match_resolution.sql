CREATE TABLE IF NOT EXISTS silver.oddspedia_match_resolution
(
    oddspedia_match_id String,
    oddspedia_discovery_date Date,
    fotmob_match_id Nullable(Int32),
    resolution_status LowCardinality(String),
    coverage_category LowCardinality(Nullable(String)),
    confidence LowCardinality(Nullable(String)),
    match_score Nullable(Float32),
    score_margin Nullable(Float32),
    time_difference_minutes Nullable(Int32),
    home_match_rule Nullable(String),
    away_match_rule Nullable(String),
    candidate_dates_checked Array(Date),
    resolution_rule_version LowCardinality(String),
    resolution_details_json String CODEC(ZSTD(3)),
    resolved_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(resolved_at)
PARTITION BY toYYYYMM(oddspedia_discovery_date)
ORDER BY (oddspedia_discovery_date, oddspedia_match_id);
