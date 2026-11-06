-- fotmob_silver.momentum
CREATE TABLE IF NOT EXISTS fotmob_silver.momentum
(
    match_id      Int32,
    match_date    Date,
    minute        Float32,
    value         Nullable(Int32),
    momentum_team LowCardinality(Nullable(String)),
    _loaded_at    DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, minute);
