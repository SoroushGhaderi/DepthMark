-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.shotmap
(
    match_id                        Int32,
    -- [BUG 2 FIX] was Nullable(Int64) with assumeNotNull() in ORDER BY
    shot_id                         Int64,
    event_type                      Nullable(String),
    team_id                         Nullable(Int32),
    player_id                       Nullable(Int32),
    player_name                     Nullable(String),
    -- Shot location
    x                               Nullable(Float32),
    y                               Nullable(Float32),
    -- [BUG 7 FIX] renamed from 'min'/'min_added' (min = ClickHouse function name)
    minute                          Nullable(Int32),
    minute_added                    Nullable(Int32),
    -- Shot outcome flags
    is_blocked                      Nullable(UInt8),
    is_on_target                    Nullable(UInt8),
    is_own_goal                     Nullable(UInt8),
    is_saved_off_line               Nullable(UInt8),
    is_from_inside_box              Nullable(UInt8),
    -- Block/goal coordinates
    blocked_x                       Nullable(Float32),
    blocked_y                       Nullable(Float32),
    goal_crossed_y                  Nullable(Float32),
    goal_crossed_z                  Nullable(Float32),
    -- On-goal shot display (visual; kept for source fidelity)
    on_goal_shot_x                  Nullable(Float32),
    on_goal_shot_y                  Nullable(Float32),
    on_goal_shot_zoom_ratio         Nullable(Float32),
    -- xG
    expected_goals                  Nullable(Float32),
    expected_goals_on_target        Nullable(Float32),
    -- Categorical
    shot_type                       Nullable(String),
    situation                       Nullable(String),
    period                          Nullable(String),
    -- Goalkeeper
    keeper_id                       Nullable(Int32),
    -- Redundant player name fields (kept for source fidelity; silver drops)
    first_name                      Nullable(String),
    last_name                       Nullable(String),
    full_name                       Nullable(String),
    -- Visual (kept for source fidelity; silver drops)
    team_color                      Nullable(String),
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, shot_id)
SETTINGS index_granularity = 8192;
