DROP TABLE IF EXISTS gold.signal_activations_match;
DROP TABLE IF EXISTS gold.match_reference;
DROP TABLE IF EXISTS gold.signal_activations;

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
    match_activation_instance_id String,
    activated_signal_instance_ids Array(String),
    activated_signal_ids Array(String),
    activated_signal_entities Array(String),
    activated_signal_tags Array(String),
    activated_signal_names Array(String),
    total_signal_rows UInt32,
    unique_signal_count UInt16,
    home_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_id Nullable(Int32),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    triggered_side LowCardinality(Nullable(String)),
    triggered_team_id Nullable(Int32),
    triggered_team_name Nullable(String),
    triggered_player_id Nullable(Int32),
    triggered_player_name Nullable(String),
    opponent_team_id Nullable(Int32),
    opponent_team_name Nullable(String),
    source_table LowCardinality(String),
    source_row_json String CODEC(ZSTD(3)),
    source_row_columns Array(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_date, match_id, signal_id, signal_instance_id)
PARTITION BY toYYYYMM(match_date);
