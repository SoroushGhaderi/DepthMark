-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.red_card
(
    match_id                        Int32,
    event_id                        Int64,
    red_card_time                   Int32,
    red_card_overload_time          Nullable(Int32),
    player_id                       Nullable(Int32),
    player_name                     Nullable(String),
    home_score                      Int32,
    away_score                      Int32,
    is_home                         UInt8,
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, event_id)
SETTINGS index_granularity = 8192;
