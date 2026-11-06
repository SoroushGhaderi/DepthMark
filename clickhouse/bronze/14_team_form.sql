-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.team_form
(
    match_id                        Int32,
    team_side                       String,
    team_id                         Int64,
    team_name                       Nullable(String),
    form_position                   Int32,
    result                          Int32,
    result_string                   String,
    score                           Nullable(String),
    form_match_date                 Nullable(String),       -- raw string; silver → Date
    form_match_id                   Nullable(String),       -- raw string; silver → Int32
    form_match_link                 Nullable(String),
    opponent_id                     Nullable(Int32),
    opponent_name                   Nullable(String),
    -- Visual (kept for source fidelity; silver drops)
    opponent_image_url              Nullable(String),
    is_home_match                   Nullable(UInt8),
    home_team_id                    Nullable(Int32),
    home_team_name                  Nullable(String),
    home_score                      Nullable(String),       -- raw string; silver → Int32
    away_team_id                    Nullable(Int32),
    away_team_name                  Nullable(String),
    away_score                      Nullable(String),       -- raw string; silver → Int32
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, team_id, form_position)
SETTINGS index_granularity = 8192;
