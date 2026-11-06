-- fotmob_silver.team_form
CREATE TABLE IF NOT EXISTS fotmob_silver.team_form
(
    match_id            Int32,
    match_date          Date,
    team_side           LowCardinality(String),
    team_id             Int64,
    team_name           Nullable(String),
    form_position       Int32,
    result_code         Int32,
    result_string       LowCardinality(String),
    form_match_id       Nullable(Int32),
    form_match_date     Nullable(Date),
    form_match_link     Nullable(String),
    opponent_id         Nullable(Int32),
    opponent_name       Nullable(String),
    is_home_match       Nullable(UInt8),
    home_team_id        Nullable(Int32),
    home_team_name      Nullable(String),
    home_score          Nullable(Int32),
    away_team_id        Nullable(Int32),
    away_team_name      Nullable(String),
    away_score          Nullable(Int32),
    _loaded_at          DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, team_id, form_position);
