CREATE TABLE IF NOT EXISTS oddspedia_bronze.event
(
    oddspedia_match_id String,
    discovery_date Date,
    scheduled_kickoff_utc Nullable(DateTime),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    league_name Nullable(String),
    country Nullable(String),
    status Nullable(String),
    source_url Nullable(String),
    full_source_url Nullable(String),
    source_file String,
    raw_event_json String CODEC(ZSTD(3)),
    loaded_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(loaded_at)
PARTITION BY toYYYYMM(discovery_date)
ORDER BY (discovery_date, oddspedia_match_id);
