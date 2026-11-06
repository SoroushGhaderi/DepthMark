-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.venue
(
    match_id                        Int32,
    -- Stadium
    stadium_name                    Nullable(String),
    stadium_city                    Nullable(String),
    stadium_country                 Nullable(String),
    stadium_latitude                Nullable(Float64),
    stadium_longitude               Nullable(Float64),
    stadium_capacity                Nullable(Int32),
    stadium_surface                 Nullable(String),
    attendance                      Nullable(Int32),
    -- Referee (referee_image_url kept for source fidelity; dropped in silver)
    referee_name                    Nullable(String),
    referee_country                 Nullable(String),
    referee_image_url               Nullable(String),
    -- Match date (raw string; silver converts to Date)
    match_date_utc                  Nullable(String),
    match_date_verified             Nullable(UInt8),
    -- Tournament
    tournament_id                   Nullable(Int32),
    tournament_name                 Nullable(String),
    tournament_round                Nullable(String),
    tournament_parent_league_id     Nullable(Int32),
    tournament_link                 Nullable(String),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 1 FIX] ifNull guard on nullable string date
PARTITION BY toYYYYMM(ifNull(toDateOrNull(match_date_utc), toDate('1970-01-01')))
ORDER BY match_id
SETTINGS index_granularity = 8192;
