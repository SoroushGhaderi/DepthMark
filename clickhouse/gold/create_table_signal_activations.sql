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

DROP VIEW IF EXISTS gold.match_signal_reference;
DROP VIEW IF EXISTS gold.match_signals_reference;
DROP VIEW IF EXISTS gold.match_scenario_reference;
DROP VIEW IF EXISTS gold.match_scenarios_reference;

CREATE VIEW IF NOT EXISTS gold.match_signals_reference AS
WITH signal_rollup AS (
    SELECT
        match_id,
        match_date,
        arrayDistinct(arrayFlatten(groupArray(activated_signal_ids))) AS all_signal_ids,
        length(arrayDistinct(arrayFlatten(groupArray(activated_signal_ids)))) AS signal_count,
        max(inserted_at) AS sa_inserted_at
    FROM gold.signal_activations_match
    GROUP BY match_id, match_date
)
SELECT
    mr.match_id,
    mr.match_date,
    mr.match_time_utc,
    mr.match_time_utc_date,
    mr.match_round,
    mr.coverage_level,
    mr.league_id,
    mr.league_name,
    mr.league_round_name,
    mr.parent_league_id,
    mr.parent_league_name,
    mr.parent_league_season,
    mr.parent_league_tournament_id,
    mr.country_code,
    mr.home_team_id,
    mr.home_team_name,
    mr.away_team_id,
    mr.away_team_name,
    mr.match_started,
    mr.match_finished,
    mr.full_score,
    mr.home_score,
    mr.away_score,
    ifNull(sr.all_signal_ids, []) AS all_signal_ids,
    ifNull(sr.all_signal_ids, []) AS available_signal_ids,
    [] AS unavailable_signal_ids,
    toUInt32(ifNull(sr.signal_count, 0)) AS signal_count,
    toUInt32(ifNull(sr.signal_count, 0)) AS available_signal_count,
    (ifNull(sr.signal_count, 0) > 0) AS has_any_signal,
    coalesce(sr.sa_inserted_at, mr.inserted_at) AS inserted_at
FROM gold.match_reference AS mr
INNER JOIN signal_rollup AS sr
    ON sr.match_id = mr.match_id
   AND sr.match_date = mr.match_date;

CREATE VIEW IF NOT EXISTS gold.match_signal_reference AS
SELECT *
FROM gold.match_signals_reference;

CREATE VIEW IF NOT EXISTS gold.match_scenarios_reference AS
SELECT
    mr.match_id,
    mr.match_date,
    mr.match_time_utc,
    mr.match_time_utc_date,
    mr.match_round,
    mr.coverage_level,
    mr.league_id,
    mr.league_name,
    mr.league_round_name,
    mr.parent_league_id,
    mr.parent_league_name,
    mr.parent_league_season,
    mr.parent_league_tournament_id,
    mr.country_code,
    mr.home_team_id,
    mr.home_team_name,
    mr.away_team_id,
    mr.away_team_name,
    mr.match_started,
    mr.match_finished,
    mr.full_score,
    mr.home_score,
    mr.away_score,
    [] AS all_scenario_ids,
    [] AS available_scenario_ids,
    [] AS unavailable_scenario_ids,
    toUInt32(0) AS scenario_count,
    toUInt32(0) AS available_scenario_count,
    toUInt8(0) AS has_any_scenario,
    mr.inserted_at
FROM gold.match_reference AS mr;

CREATE VIEW IF NOT EXISTS gold.match_scenario_reference AS
SELECT *
FROM gold.match_scenarios_reference;
