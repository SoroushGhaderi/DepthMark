-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.player
(
    match_id                        Int32,
    -- [BUG 2 FIX] was Nullable(Int32) with assumeNotNull() in ORDER BY
    player_id                       Int32,
    player_name                     Nullable(String),
    opta_id                         Nullable(String),
    team_id                         Nullable(Int32),
    team_name                       Nullable(String),
    is_goalkeeper                   Nullable(UInt8),
    fotmob_rating                   Nullable(Float32),
    minutes_played                  Nullable(Int32),
    -- Attacking
    goals                           Nullable(Int32),
    assists                         Nullable(Int32),
    total_shots                     Nullable(Int32),
    shots_on_target                 Nullable(Int32),
    shots_off_target                Nullable(Int32),
    blocked_shots                   Nullable(Int32),
    expected_goals                  Nullable(Float32),
    expected_assists                Nullable(Float32),
    xg_plus_xa                      Nullable(Float32),
    xg_non_penalty                  Nullable(Float32),
    chances_created                 Nullable(Int32),
    -- Possession
    touches                         Nullable(Int32),
    touches_opp_box                 Nullable(Int32),
    -- Dribbling
    successful_dribbles             Nullable(Int32),
    dribble_attempts                Nullable(Int32),
    dribble_success_rate            Nullable(Float32),
    -- Passing
    accurate_passes                 Nullable(Int32),
    total_passes                    Nullable(Int32),
    pass_accuracy                   Nullable(Float32),
    passes_final_third              Nullable(Int32),
    -- Crossing
    accurate_crosses                Nullable(Int32),
    cross_attempts                  Nullable(Int32),
    cross_success_rate              Nullable(Float32),
    -- Long balls
    accurate_long_balls             Nullable(Int32),
    long_ball_attempts              Nullable(Int32),
    long_ball_success_rate          Nullable(Float32),
    -- Defending
    tackles_won                     Nullable(Int32),
    tackle_attempts                 Nullable(Int32),
    tackle_success_rate             Nullable(Float32),
    interceptions                   Nullable(Int32),
    clearances                      Nullable(Int32),
    defensive_actions               Nullable(Int32),
    recoveries                      Nullable(Int32),
    dribbled_past                   Nullable(Int32),
    -- Duels
    duels_won                       Nullable(Int32),
    duels_lost                      Nullable(Int32),
    ground_duels_won                Nullable(Int32),
    ground_duel_attempts            Nullable(Int32),
    ground_duel_success_rate        Nullable(Float32),
    aerial_duels_won                Nullable(Int32),
    aerial_duel_attempts            Nullable(Int32),
    aerial_duel_success_rate        Nullable(Float32),
    -- Discipline
    fouls_committed                 Nullable(Int32),
    was_fouled                      Nullable(Int32),
    -- xG summary
    shotmap_count                   Nullable(Int32),
    average_xg_per_shot             Nullable(Float32),
    total_xg                        Nullable(Float32),
    -- Unstructured — Array(Nullable(String)) is unsupported in ClickHouse
    fun_facts                       Array(String),          -- [BUG 3 FIX] was Array(Nullable(String))
    inserted_at                     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added; [BUG 2 FIX] no more assumeNotNull in ORDER BY
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, player_id)
SETTINGS index_granularity = 8192;
