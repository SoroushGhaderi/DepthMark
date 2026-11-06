-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.goal
(
    match_id                        Int32,
    event_id                        Int64,
    goal_time                       Int32,
    goal_overload_time              Nullable(Int32),
    home_score                      Int32,
    away_score                      Int32,
    is_home                         UInt8,
    is_own_goal                     Nullable(UInt8),
    goal_description                Nullable(String),
    -- Scorer
    player_id                       Nullable(Int32),
    player_name                     Nullable(String),
    -- Assist
    assist_player_id                Nullable(Int32),
    assist_player_name              Nullable(String),
    -- Linked shot (joins to fotmob_bronze.shotmap.shot_id)
    shot_event_id                   Nullable(Int64),
    shot_x_loc                      Nullable(Float32),
    shot_y_loc                      Nullable(Float32),
    shot_minute                     Nullable(Int32),
    shot_minute_added               Nullable(Int32),
    shot_expected_goal              Nullable(Float32),
    shot_expected_goal_on_target    Nullable(Float32),
    shot_type                       Nullable(String),
    shot_situation                  Nullable(String),
    shot_period                     Nullable(String),
    shot_from_inside_box            Nullable(UInt8),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
-- [BUG 6 FIX] ORDER BY simplified — event_id is unique per goal event
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, event_id)
SETTINGS index_granularity = 8192;
