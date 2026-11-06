-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.coaches
(
    match_id                        Int32,
    team_side                       String,
    -- [BUG 7 FIX] was 'id' — ambiguous
    coach_id                        Int64,
    age                             Nullable(Int32),
    name                            Nullable(String),
    first_name                      Nullable(String),
    last_name                       Nullable(String),
    country_name                    Nullable(String),
    country_code                    Nullable(String),
    primary_team_id                 Nullable(Int32),
    primary_team_name               Nullable(String),
    is_coach                        Nullable(UInt8),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, coach_id)
SETTINGS index_granularity = 8192;
