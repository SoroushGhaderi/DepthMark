-- fotmob_silver.match_personnel
CREATE TABLE IF NOT EXISTS fotmob_silver.match_personnel
(
    match_id                  Int32,
    match_date                Date,
    team_side                 LowCardinality(String),
    role                      LowCardinality(String),
    person_id                 Int64,
    name                      Nullable(String),
    first_name                Nullable(String),
    last_name                 Nullable(String),
    age                       Nullable(Int32),
    country_name              Nullable(String),
    country_code              LowCardinality(Nullable(String)),
    shirt_number              Nullable(Int32),
    position_id               Nullable(Int32),
    usual_playing_position_id Nullable(Int32),
    is_captain                Nullable(UInt8),
    performance_rating        Nullable(Float32),
    substitution_time         Nullable(Int32),
    substitution_type         LowCardinality(Nullable(String)),
    substitution_reason       Nullable(String),
    primary_team_id           Nullable(Int32),
    primary_team_name         Nullable(String),
    _loaded_at                DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, team_side, role, person_id);
