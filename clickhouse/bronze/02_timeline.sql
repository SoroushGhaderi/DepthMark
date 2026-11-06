-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.timeline
(
    match_id                        Int32,
    match_time_utc                  Nullable(String),       -- [BUG 4 FIX] was Nullable(DateTime), now String like fotmob_bronze.general
    -- Half timestamps — raw strings, silver converts to DateTime
    first_half_started              Nullable(String),
    first_half_ended                Nullable(String),
    second_half_started             Nullable(String),
    second_half_ended               Nullable(String),
    first_extra_half_started        Nullable(String),
    second_extra_half_started       Nullable(String),
    game_ended                      Nullable(String),
    -- Status flags
    game_finished                   UInt8,
    game_started                    UInt8,
    game_cancelled                  UInt8,
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 1 FIX] ifNull guard on nullable string date
PARTITION BY toYYYYMM(ifNull(toDateOrNull(match_time_utc), toDate('1970-01-01')))
ORDER BY match_id
SETTINGS index_granularity = 8192;
