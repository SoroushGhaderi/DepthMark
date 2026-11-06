-- Auto-extracted from /Users/soroush/Downloads/bronze_ddl.sql
CREATE TABLE IF NOT EXISTS fotmob_bronze.period
(
    match_id                            Int32,
    period                              String,             -- 'FirstHalf'|'SecondHalf'|'FullMatch'
    -- Possession
    ball_possession_home                Nullable(Int32),
    ball_possession_away                Nullable(Int32),
    -- xG
    expected_goals_home                 Nullable(Float32),
    expected_goals_away                 Nullable(Float32),
    expected_goals_open_play_home       Nullable(Float32),
    expected_goals_open_play_away       Nullable(Float32),
    expected_goals_set_play_home        Nullable(Float32),
    expected_goals_set_play_away        Nullable(Float32),
    expected_goals_non_penalty_home     Nullable(Float32),
    expected_goals_non_penalty_away     Nullable(Float32),
    expected_goals_on_target_home       Nullable(Float32),
    expected_goals_on_target_away       Nullable(Float32),
    -- Physical / tracking
    distance_covered_home               Nullable(Float32),
    distance_covered_away               Nullable(Float32),
    walking_distance_home               Nullable(Float32),
    walking_distance_away               Nullable(Float32),
    running_distance_home               Nullable(Float32),
    running_distance_away               Nullable(Float32),
    sprinting_distance_home             Nullable(Float32),
    sprinting_distance_away             Nullable(Float32),
    number_of_sprints_home              Nullable(Int32),
    number_of_sprints_away              Nullable(Int32),
    -- Physical / tracking (source-style aliases kept for compatibility)
    physical_metrics_distance_covered_home Nullable(Float32),
    physical_metrics_distance_covered_away Nullable(Float32),
    physical_metrics_walking_home       Nullable(Float32),
    physical_metrics_walking_away       Nullable(Float32),
    physical_metrics_running_home       Nullable(Float32),
    physical_metrics_running_away       Nullable(Float32),
    physical_metrics_sprinting_home     Nullable(Float32),
    physical_metrics_sprinting_away     Nullable(Float32),
    physical_metrics_number_of_sprints_home Nullable(Int32),
    physical_metrics_number_of_sprints_away Nullable(Int32),
    top_speed_home                      Nullable(Float32),
    top_speed_away                      Nullable(Float32),
    -- Shots
    total_shots_home                    Nullable(Int32),
    total_shots_away                    Nullable(Int32),
    shots_on_target_home                Nullable(Int32),
    shots_on_target_away                Nullable(Int32),
    shots_off_target_home               Nullable(Int32),
    shots_off_target_away               Nullable(Int32),
    blocked_shots_home                  Nullable(Int32),
    blocked_shots_away                  Nullable(Int32),
    shots_woodwork_home                 Nullable(Int32),
    shots_woodwork_away                 Nullable(Int32),
    shots_sidebox_home                  Nullable(Int32),    -- kept for source fidelity; silver drops
    shots_sidebox_away                  Nullable(Int32),    -- kept for source fidelity; silver drops
    shots_inside_box_home               Nullable(Int32),
    shots_inside_box_away               Nullable(Int32),
    shots_outside_box_home              Nullable(Int32),
    shots_outside_box_away              Nullable(Int32),
    big_chances_home                    Nullable(Int32),
    big_chances_away                    Nullable(Int32),
    big_chances_missed_home             Nullable(Int32),
    big_chances_missed_away             Nullable(Int32),
    -- [BUG 8 FIX] removed shots_home/shots_away — duplicate of total_shots_home/away
    -- Discipline
    fouls_home                          Nullable(Int32),
    fouls_away                          Nullable(Int32),
    corners_home                        Nullable(Int32),
    corners_away                        Nullable(Int32),
    -- Passes (ratio strings e.g. "43/58" — silver splits into two Int32 columns)
    passes_home                         Nullable(Int32),
    passes_away                         Nullable(Int32),
    accurate_passes_home                Nullable(String),
    accurate_passes_away                Nullable(String),
    own_half_passes_home                Nullable(Int32),
    own_half_passes_away                Nullable(Int32),
    opposition_half_passes_home         Nullable(Int32),
    opposition_half_passes_away         Nullable(Int32),
    long_balls_accurate_home            Nullable(String),   -- ratio string; silver splits
    long_balls_accurate_away            Nullable(String),
    accurate_crosses_home               Nullable(String),   -- ratio string; silver splits
    accurate_crosses_away               Nullable(String),
    player_throws_home                  Nullable(Int32),
    player_throws_away                  Nullable(Int32),
    touches_opp_box_home                Nullable(Int32),
    touches_opp_box_away                Nullable(Int32),
    -- Defending
    tackles_succeeded_home              Nullable(String),   -- ratio string; silver splits
    tackles_succeeded_away              Nullable(String),
    interceptions_home                  Nullable(Int32),
    interceptions_away                  Nullable(Int32),
    shot_blocks_home                    Nullable(Int32),
    shot_blocks_away                    Nullable(Int32),
    clearances_home                     Nullable(Int32),
    clearances_away                     Nullable(Int32),
    keeper_saves_home                   Nullable(Int32),
    keeper_saves_away                   Nullable(Int32),
    -- Duels (ratio strings; silver splits)
    duels_won_home                      Nullable(Int32),
    duels_won_away                      Nullable(Int32),
    ground_duels_won_home               Nullable(String),   -- ratio string; silver splits
    ground_duels_won_away               Nullable(String),
    aerials_won_home                    Nullable(String),   -- ratio string; silver splits
    aerials_won_away                    Nullable(String),
    dribbles_succeeded_home             Nullable(String),   -- ratio string; silver splits
    dribbles_succeeded_away             Nullable(String),
    -- Discipline
    yellow_cards_home                   Nullable(Int32),
    yellow_cards_away                   Nullable(Int32),
    red_cards_home                      Nullable(Int32),
    red_cards_away                      Nullable(Int32),
    offsides_home                       Nullable(Int32),
    offsides_away                       Nullable(Int32),
    -- Visual (kept for source fidelity; silver drops)
    home_color                          Nullable(String),
    away_color                          Nullable(String),
    inserted_at                         DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(inserted_at)
-- [BUG 5 FIX] PARTITION BY added
PARTITION BY toYYYYMM(inserted_at)
ORDER BY (match_id, period)
SETTINGS index_granularity = 8192;
