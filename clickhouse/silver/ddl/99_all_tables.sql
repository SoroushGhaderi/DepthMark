-- Consolidated Silver layer DDL
-- Creates silver database and all silver tables.

CREATE DATABASE IF NOT EXISTS fotmob_silver;

-- fotmob_silver.match
CREATE TABLE IF NOT EXISTS fotmob_silver.match
(
    match_id                        Int32,
    match_date                      Date,
    match_time_utc                  Nullable(DateTime),
    match_started                   UInt8,
    match_finished                  UInt8,
    match_round                     Nullable(String),
    coverage_level                  LowCardinality(Nullable(String)),
    league_id                       Nullable(Int32),
    league_name                     LowCardinality(Nullable(String)),
    league_round_name               Nullable(String),
    parent_league_id                Nullable(Int32),
    parent_league_name              Nullable(String),
    parent_league_season            Nullable(String),
    parent_league_tournament_id     Nullable(Int32),
    country_code                    LowCardinality(Nullable(String)),
    tournament_id                   Nullable(Int32),
    tournament_name                 Nullable(String),
    tournament_round                Nullable(String),
    tournament_link                 Nullable(String),
    home_team_id                    Nullable(Int32),
    home_team_name                  Nullable(String),
    away_team_id                    Nullable(Int32),
    away_team_name                  Nullable(String),
    home_score                      Nullable(Int32),
    away_score                      Nullable(Int32),
    full_score                      Nullable(String),
    game_started                    UInt8 DEFAULT 0,
    game_finished                   UInt8 DEFAULT 0,
    game_cancelled                  UInt8 DEFAULT 0,
    first_half_started              Nullable(DateTime),
    first_half_ended                Nullable(DateTime),
    second_half_started             Nullable(DateTime),
    second_half_ended               Nullable(DateTime),
    first_extra_half_started        Nullable(DateTime),
    second_extra_half_started       Nullable(DateTime),
    game_ended                      Nullable(DateTime),
    stadium_name                    Nullable(String),
    stadium_city                    Nullable(String),
    stadium_country                 LowCardinality(Nullable(String)),
    stadium_latitude                Nullable(Float64),
    stadium_longitude               Nullable(Float64),
    stadium_capacity                Nullable(Int32),
    stadium_surface                 LowCardinality(Nullable(String)),
    attendance                      Nullable(Int32),
    match_date_verified             Nullable(UInt8),
    referee_name                    Nullable(String),
    referee_country                 LowCardinality(Nullable(String)),
    _loaded_at                      DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY match_id;

-- fotmob_silver.period_stat
CREATE TABLE IF NOT EXISTS fotmob_silver.period_stat
(
    match_id                            Int32,
    match_date                          Date,
    period                              LowCardinality(String),
    ball_possession_home                Nullable(Int32),
    ball_possession_away                Nullable(Int32),
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
    top_speed_home                      Nullable(Float32),
    top_speed_away                      Nullable(Float32),
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
    shots_inside_box_home               Nullable(Int32),
    shots_inside_box_away               Nullable(Int32),
    shots_outside_box_home              Nullable(Int32),
    shots_outside_box_away              Nullable(Int32),
    big_chances_home                    Nullable(Int32),
    big_chances_away                    Nullable(Int32),
    big_chances_missed_home             Nullable(Int32),
    big_chances_missed_away             Nullable(Int32),
    passes_home                         Nullable(Int32),
    passes_away                         Nullable(Int32),
    accurate_passes_home                Nullable(Int32),
    pass_attempts_home                  Nullable(Int32),
    accurate_passes_away                Nullable(Int32),
    pass_attempts_away                  Nullable(Int32),
    own_half_passes_home                Nullable(Int32),
    own_half_passes_away                Nullable(Int32),
    opposition_half_passes_home         Nullable(Int32),
    opposition_half_passes_away         Nullable(Int32),
    player_throws_home                  Nullable(Int32),
    player_throws_away                  Nullable(Int32),
    touches_opp_box_home                Nullable(Int32),
    touches_opp_box_away                Nullable(Int32),
    accurate_long_balls_home            Nullable(Int32),
    long_ball_attempts_home             Nullable(Int32),
    accurate_long_balls_away            Nullable(Int32),
    long_ball_attempts_away             Nullable(Int32),
    accurate_crosses_home               Nullable(Int32),
    cross_attempts_home                 Nullable(Int32),
    accurate_crosses_away               Nullable(Int32),
    cross_attempts_away                 Nullable(Int32),
    interceptions_home                  Nullable(Int32),
    interceptions_away                  Nullable(Int32),
    clearances_home                     Nullable(Int32),
    clearances_away                     Nullable(Int32),
    shot_blocks_home                    Nullable(Int32),
    shot_blocks_away                    Nullable(Int32),
    keeper_saves_home                   Nullable(Int32),
    keeper_saves_away                   Nullable(Int32),
    tackles_succeeded_home              Nullable(Int32),
    tackle_attempts_home                Nullable(Int32),
    tackles_succeeded_away              Nullable(Int32),
    tackle_attempts_away                Nullable(Int32),
    duels_won_home                      Nullable(Int32),
    duels_won_away                      Nullable(Int32),
    ground_duels_won_home               Nullable(Int32),
    ground_duel_attempts_home           Nullable(Int32),
    ground_duels_won_away               Nullable(Int32),
    ground_duel_attempts_away           Nullable(Int32),
    aerials_won_home                    Nullable(Int32),
    aerial_attempts_home                Nullable(Int32),
    aerials_won_away                    Nullable(Int32),
    aerial_attempts_away                Nullable(Int32),
    dribbles_succeeded_home             Nullable(Int32),
    dribble_attempts_home               Nullable(Int32),
    dribbles_succeeded_away             Nullable(Int32),
    dribble_attempts_away               Nullable(Int32),
    yellow_cards_home                   Nullable(Int32),
    yellow_cards_away                   Nullable(Int32),
    red_cards_home                      Nullable(Int32),
    red_cards_away                      Nullable(Int32),
    fouls_home                          Nullable(Int32),
    fouls_away                          Nullable(Int32),
    corners_home                        Nullable(Int32),
    corners_away                        Nullable(Int32),
    offsides_home                       Nullable(Int32),
    offsides_away                       Nullable(Int32),
    _loaded_at                          DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, period);

-- fotmob_silver.player_match_stat
CREATE TABLE IF NOT EXISTS fotmob_silver.player_match_stat
(
    match_id                 Int32,
    match_date               Date,
    player_id                Int32,
    player_name              Nullable(String),
    opta_id                  Nullable(String),
    team_id                  Int32,
    team_name                Nullable(String),
    is_goalkeeper            UInt8,
    fotmob_rating            Nullable(Float32),
    minutes_played           Nullable(Int32),
    goals                    Nullable(Int32),
    assists                  Nullable(Int32),
    total_shots              Nullable(Int32),
    shots_on_target          Nullable(Int32),
    shots_off_target         Nullable(Int32),
    blocked_shots            Nullable(Int32),
    expected_goals           Nullable(Float32),
    expected_assists         Nullable(Float32),
    xg_plus_xa               Nullable(Float32),
    xg_non_penalty           Nullable(Float32),
    chances_created          Nullable(Int32),
    average_xg_per_shot      Nullable(Float32),
    total_xg                 Nullable(Float32),
    shotmap_count            Nullable(Int32),
    touches                  Nullable(Int32),
    touches_opp_box          Nullable(Int32),
    successful_dribbles      Nullable(Int32),
    dribble_attempts         Nullable(Int32),
    dribble_success_rate     Nullable(Float32),
    accurate_passes          Nullable(Int32),
    total_passes             Nullable(Int32),
    pass_accuracy            Nullable(Float32),
    passes_final_third       Nullable(Int32),
    accurate_crosses         Nullable(Int32),
    cross_attempts           Nullable(Int32),
    cross_success_rate       Nullable(Float32),
    accurate_long_balls      Nullable(Int32),
    long_ball_attempts       Nullable(Int32),
    long_ball_success_rate   Nullable(Float32),
    tackles_won              Nullable(Int32),
    tackle_attempts          Nullable(Int32),
    tackle_success_rate      Nullable(Float32),
    interceptions            Nullable(Int32),
    clearances               Nullable(Int32),
    defensive_actions        Nullable(Int32),
    recoveries               Nullable(Int32),
    dribbled_past            Nullable(Int32),
    duels_won                Nullable(Int32),
    duels_lost               Nullable(Int32),
    ground_duels_won         Nullable(Int32),
    ground_duel_attempts     Nullable(Int32),
    ground_duel_success_rate Nullable(Float32),
    aerial_duels_won         Nullable(Int32),
    aerial_duel_attempts     Nullable(Int32),
    aerial_duel_success_rate Nullable(Float32),
    fouls_committed          Nullable(Int32),
    was_fouled               Nullable(Int32),
    _loaded_at               DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, player_id);

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

-- fotmob_silver.shot
CREATE TABLE IF NOT EXISTS fotmob_silver.shot
(
    match_id                    Int32,
    match_date                  Date,
    shot_id                     Int64,
    event_type                  LowCardinality(Nullable(String)),
    team_id                     Nullable(Int32),
    player_id                   Nullable(Int32),
    player_name                 Nullable(String),
    keeper_id                   Nullable(Int32),
    minute                      Nullable(Int32),
    minute_added                Nullable(Int32),
    period                      LowCardinality(Nullable(String)),
    x                           Nullable(Float32),
    y                           Nullable(Float32),
    shot_type                   LowCardinality(Nullable(String)),
    situation                   LowCardinality(Nullable(String)),
    is_on_target                Nullable(UInt8),
    is_blocked                  Nullable(UInt8),
    is_saved_off_line           Nullable(UInt8),
    is_from_inside_box          Nullable(UInt8),
    blocked_x                   Nullable(Float32),
    blocked_y                   Nullable(Float32),
    goal_crossed_y              Nullable(Float32),
    goal_crossed_z              Nullable(Float32),
    on_goal_shot_x              Nullable(Float32),
    on_goal_shot_y              Nullable(Float32),
    expected_goals              Nullable(Float32),
    expected_goals_on_target    Nullable(Float32),
    is_goal                     UInt8 DEFAULT 0,
    is_own_goal                 UInt8 DEFAULT 0,
    goal_time                   Nullable(Int32),
    goal_overload_time          Nullable(Int32),
    home_score_after            Nullable(Int32),
    away_score_after            Nullable(Int32),
    is_home_goal                Nullable(UInt8),
    goal_description            Nullable(String),
    assist_player_id            Nullable(Int32),
    assist_player_name          Nullable(String),
    _loaded_at                  DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, shot_id);

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

-- fotmob_silver.match_personnel
CREATE TABLE IF NOT EXISTS fotmob_silver.match_personnel
(
    match_id                  Int32,
    match_date                Date,
    team_side                 LowCardinality(String),
    role                      LowCardinality(String),
    person_id                 Int64,
    name                      Nullable(String),
    first_name                Nullable(String),
    last_name                 Nullable(String),
    age                       Nullable(Int32),
    country_name              Nullable(String),
    country_code              LowCardinality(Nullable(String)),
    shirt_number              Nullable(Int32),
    position_id               Nullable(Int32),
    usual_playing_position_id Nullable(Int32),
    is_captain                Nullable(UInt8),
    performance_rating        Nullable(Float32),
    substitution_time         Nullable(Int32),
    substitution_type         LowCardinality(Nullable(String)),
    substitution_reason       Nullable(String),
    primary_team_id           Nullable(Int32),
    primary_team_name         Nullable(String),
    _loaded_at                DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, team_side, role, person_id);

-- fotmob_silver.team_form
CREATE TABLE IF NOT EXISTS fotmob_silver.team_form
(
    match_id            Int32,
    match_date          Date,
    team_side           LowCardinality(String),
    team_id             Int64,
    team_name           Nullable(String),
    form_position       Int32,
    result_code         Int32,
    result_string       LowCardinality(String),
    form_match_id       Nullable(Int32),
    form_match_date     Nullable(Date),
    form_match_link     Nullable(String),
    opponent_id         Nullable(Int32),
    opponent_name       Nullable(String),
    is_home_match       Nullable(UInt8),
    home_team_id        Nullable(Int32),
    home_team_name      Nullable(String),
    home_score          Nullable(Int32),
    away_team_id        Nullable(Int32),
    away_team_name      Nullable(String),
    away_score          Nullable(Int32),
    _loaded_at          DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_loaded_at)
PARTITION BY toYYYYMM(match_date)
ORDER BY (match_id, team_id, form_position);
