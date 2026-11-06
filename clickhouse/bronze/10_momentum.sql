-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.momentum
(
    match_id                        Int32,
    -- [BUG 2 FIX] was Nullable(Float32) with assumeNotNull() in ORDER BY
    minute                          Float32,
    value                           Nullable(Int32),
    momentum_team                   Nullable(String),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, minute)
SETTINGS index_granularity = 8192;
