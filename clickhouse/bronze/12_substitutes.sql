-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.substitutes
(
    match_id                        Int32,
    team_side                       String,
    player_id                       Int64,
    age                             Nullable(Int32),
    name                            Nullable(String),
    first_name                      Nullable(String),
    last_name                       Nullable(String),
    usual_playing_position_id       Nullable(Int32),
    shirt_number                    Nullable(String),       -- raw string; silver → Nullable(Int32)
    country_name                    Nullable(String),
    country_code                    Nullable(String),
    performance_rating              Nullable(Float32),
    substitution_time               Nullable(Int32),
    substitution_type               Nullable(String),
    substitution_reason             Nullable(String),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, player_id)
SETTINGS index_granularity = 8192;
