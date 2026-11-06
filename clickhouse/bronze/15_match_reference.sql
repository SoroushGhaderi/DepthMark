-- Compact bronze match reference for fast date/id/team filtering.
CREATE TABLE IF NOT EXISTS fotmob_bronze.match_reference
(
    match_id                        Int32,
    match_date                      Date,
    match_time_utc                  Nullable(String),
    match_time_utc_date             Nullable(String),
    match_round                     Nullable(String),
    coverage_level                  Nullable(String),
    league_id                       Nullable(Int32),
    league_name                     Nullable(String),
    league_round_name               Nullable(String),
    parent_league_id                Nullable(Int32),
    parent_league_name              Nullable(String),
    parent_league_season            Nullable(String),
    parent_league_tournament_id     Nullable(Int32),
    country_code                    Nullable(String),
    home_team_id                    Nullable(Int32),
    home_team_name                  Nullable(String),
    away_team_id                    Nullable(Int32),
    away_team_name                  Nullable(String),
    match_started                   UInt8,
    match_finished                  UInt8,
    full_score                      Nullable(String),
    home_score                      Nullable(Int32),
    away_score                      Nullable(Int32),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_date, match_id)
SETTINGS index_granularity = 8192;
