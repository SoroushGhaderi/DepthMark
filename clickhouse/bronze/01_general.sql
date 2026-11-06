-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.general
(
    match_id                        Int32,
    match_round                     Nullable(String),
    -- Visual columns (kept for source fidelity; dropped in silver)
    team_color_dark_mode_home       Nullable(String),
    team_color_dark_mode_away       Nullable(String),
    team_color_light_mode_home      Nullable(String),
    team_color_light_mode_away      Nullable(String),
    -- League context
    league_id                       Nullable(Int32),
    league_name                     Nullable(String),
    league_round_name               Nullable(String),
    parent_league_id                Nullable(Int32),
    country_code                    Nullable(String),
    parent_league_name              Nullable(String),
    parent_league_season            Nullable(String),
    parent_league_tournament_id     Nullable(Int32),
    -- Teams
    home_team_name                  Nullable(String),
    home_team_id                    Nullable(Int32),
    away_team_name                  Nullable(String),
    away_team_id                    Nullable(Int32),
    -- Coverage & time (raw strings — silver converts to typed columns)
    coverage_level                  Nullable(String),
    match_time_utc                  Nullable(String),       -- raw string; silver → DateTime
    match_time_utc_date             Nullable(String),       -- raw string; silver → Date
    -- Status flags
    match_started                   UInt8,
    match_finished                  UInt8,
    -- Score
    full_score                      Nullable(String),
    home_score                      Nullable(Int32),
    away_score                      Nullable(Int32),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 1 FIX] ifNull() instead of assumeNotNull() — sentinel 1970-01-01 is a
-- visible canary for rows with missing dates, not a silent wrong partition.
PARTITION BY toYYYYMM(ifNull(toDateOrNull(match_time_utc_date), toDate('1970-01-01')))
ORDER BY match_id
SETTINGS index_granularity = 8192;
