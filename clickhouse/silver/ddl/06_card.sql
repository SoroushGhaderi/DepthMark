-- fotmob_silver.card
CREATE TABLE IF NOT EXISTS fotmob_silver.card
(
    match_id        Int32,
    match_date      Date,
    event_id        Int64,
    card_minute     Int32,
    added_time      Nullable(Int32),
    player_id       Nullable(Int32),
    player_name     Nullable(String),
    team_side       LowCardinality(String),
    card_type       LowCardinality(String),
    description     Nullable(String),
    score_home_at_time Nullable(Int32),
    score_away_at_time Nullable(Int32),
    _loaded_at      DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, event_id);
