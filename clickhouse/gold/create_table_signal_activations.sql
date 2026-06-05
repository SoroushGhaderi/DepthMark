CREATE TABLE IF NOT EXISTS gold.signal_activations (
    signal_instance_id String,
    signal_id LowCardinality(String),
    signal_id_version LowCardinality(String) DEFAULT 'v1',
    signal_prefix LowCardinality(String),
    signal_entity LowCardinality(String),
    signal_family LowCardinality(String),
    signal_subfamily LowCardinality(String),
    signal_name LowCardinality(String),
    signal_tags Array(String),
    match_id Int32,
    match_date Date,
    triggered_side LowCardinality(Nullable(String)),
    triggered_team_id Nullable(Int32),
    triggered_player_id Nullable(Int32),
    source_table LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (signal_id, match_id, signal_instance_id)
PARTITION BY toYYYYMM(match_date);

CREATE TABLE IF NOT EXISTS gold.signal_activations_match (
    match_activation_instance_id String,
    match_id Int32,
    match_date Date,
    activated_signal_instance_ids Array(String),
    activated_signal_ids Array(String),
    activated_signal_entities Array(String),
    activated_signal_tags Array(String),
    activated_signal_names Array(String),
    total_signal_rows UInt32,
    unique_signal_count UInt16,
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_date, match_id, match_activation_instance_id)
PARTITION BY toYYYYMM(match_date);

CREATE VIEW IF NOT EXISTS gold.match_reference AS
SELECT
    match_id,
    match_date,
    match_time_utc,
    match_time_utc_date,
    match_round,
    coverage_level,
    league_id,
    league_name,
    league_round_name,
    parent_league_id,
    parent_league_name,
    parent_league_season,
    parent_league_tournament_id,
    country_code,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    match_started,
    match_finished,
    full_score,
    home_score,
    away_score,
    inserted_at
FROM bronze.match_reference FINAL;
