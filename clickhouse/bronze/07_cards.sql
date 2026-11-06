-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.cards
(
    match_id                        Int32,
    event_id                        Int64,
    -- [BUG 7 FIX] was 'time' — conflicts with ClickHouse built-in function
    event_time                      Int32,
    added_time                      Nullable(Int32),
    player_id                       Nullable(Int32),
    player_name                     Nullable(String),
    -- Visual (kept for source fidelity; silver drops)
    player_profile_url              Nullable(String),
    team                            String,
    card_type                       String,
    description                     Nullable(String),
    -- [BUG 7 FIX] was 'score' — ambiguous; renamed for clarity
    score_at_event                  String,
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, event_id)
SETTINGS index_granularity = 8192;
