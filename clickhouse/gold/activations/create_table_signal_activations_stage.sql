DROP TABLE IF EXISTS gold.signal_activations_stage;

CREATE TABLE gold.signal_activations_stage (
    signal_instance_id String,
    signal_id String,
    signal_id_version String,
    signal_prefix String,
    signal_entity String,
    signal_family String,
    signal_subfamily String,
    signal_name String,
    signal_tags Array(String),
    match_id Int32,
    match_date Date,
    home_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_id Nullable(Int32),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    triggered_side Nullable(String),
    triggered_team_id Nullable(Int32),
    triggered_team_name Nullable(String),
    triggered_player_id Nullable(Int32),
    triggered_player_name Nullable(String),
    opponent_team_id Nullable(Int32),
    opponent_team_name Nullable(String),
    source_table String,
    source_row_json String,
    source_row_columns Array(String),
    inserted_at DateTime
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_date, match_id, signal_id, signal_instance_id)
PARTITION BY toYYYYMM(match_date);
