-- Scenario tables for gold layer

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_demolition (
    match_id Int32,
    home_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_id Nullable(Int32),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_defensive_shutdown_win (
    match_id Int32,
    home_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_id Nullable(Int32),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    expected_goals_home Nullable(Float32),
    expected_goals_away Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    xg_conceded Nullable(Float32),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_underdog_heist (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    xg_home Nullable(Float32),
    xg_away Nullable(Float32),
    xg_diff Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    winner_xg Nullable(Float32),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_dead_ball_dominance (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    home_set_piece_goals UInt32,
    away_set_piece_goals UInt32,
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_low_block_heist (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    possession_home Nullable(Float32),
    possession_away Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    winner_possession Nullable(Float32),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_tactical_stalemate (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    xg_home Nullable(Float32),
    xg_away Nullable(Float32),
    combined_xg Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, match_result)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_great_escape (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    home_score_at_60 UInt32,
    away_score_at_60 UInt32,
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_one_man_army (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    goals Nullable(Int32),
    assists Nullable(Int32),
    goal_contributions Nullable(Int32),
    xg Nullable(Float32),
    xa Nullable(Float32),
    xg_xa Nullable(Float32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    team_side LowCardinality(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_last_gasp (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    winning_goal_minute Nullable(Int32),
    winning_goal_added_time Nullable(Int32),
    winning_goal_scorer Nullable(String),
    home_score_before Nullable(Int32),
    away_score_before Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_shot_stopper (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    keeper_id Nullable(Int32),
    goalkeeper_name Nullable(String),
    goalkeeper_team_id Nullable(Int32),
    goalkeeper_team Nullable(String),
    saves UInt32,
    xg_saved Nullable(Float32),
    keeper_side LowCardinality(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(keeper_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_war_zone (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    fouls_home Nullable(Int32),
    fouls_away Nullable(Int32),
    combined_fouls Nullable(Int32),
    yellow_cards_home Nullable(Int32),
    yellow_cards_away Nullable(Int32),
    combined_yellow_cards Nullable(Int32),
    red_cards_home Nullable(Int32),
    red_cards_away Nullable(Int32),
    combined_red_cards Nullable(Int32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, match_result)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_clinical_finisher (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    goals UInt32,
    total_shots UInt32,
    combined_xg Nullable(Float32),
    team_side LowCardinality(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_russian_roulette (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_duration UInt32,
    total_penalties UInt32,
    home_penalties UInt32,
    away_penalties UInt32,
    penalties_scored UInt32,
    penalties_missed UInt32,
    home_penalties_scored UInt32,
    away_penalties_scored UInt32,
    home_penalties_missed UInt32,
    away_penalties_missed UInt32,
    home_penalty_xgot Nullable(Float32),
    away_penalty_xgot Nullable(Float32),
    combined_penalty_xgot Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, match_result)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_efficiency_machine (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    home_total_shots UInt32,
    away_total_shots UInt32,
    home_avg_xg_per_shot Nullable(Float32),
    away_avg_xg_per_shot Nullable(Float32),
    home_total_xg Nullable(Float32),
    away_total_xg Nullable(Float32),
    winner_total_shots UInt32,
    winner_avg_xg_per_shot Nullable(Float32),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_away_day_masterclass (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    possession_home Nullable(Float32),
    possession_away Nullable(Float32),
    xg_home Nullable(Float32),
    xg_away Nullable(Float32),
    xg_diff Nullable(Float32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(away_team_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_key_pass_king (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    chances_created Nullable(Int32),
    xa Nullable(Float32),
    assists Nullable(Int32),
    goals Nullable(Int32),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    team_side LowCardinality(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_wildcard (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_side LowCardinality(String),
    substitution_time Nullable(Int32),
    substitution_reason Nullable(String),
    goals Nullable(Int32),
    assists Nullable(Int32),
    goal_contributions Nullable(Int32),
    xg Nullable(Float32),
    xa Nullable(Float32),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_lead_by_example (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    player_id Nullable(Int32),
    captain_name Nullable(String),
    team_side LowCardinality(String),
    goals Nullable(Int32),
    assists Nullable(Int32),
    goal_contributions Nullable(Int32),
    xg Nullable(Float32),
    xa Nullable(Float32),
    rating Nullable(Float32),
    avg_rating Nullable(Float32),
    rating_above_avg Nullable(Float32),
    minutes_played Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_young_gun (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    age Nullable(Int32),
    team_side LowCardinality(String),
    is_captain Nullable(UInt8),
    goals Nullable(Int32),
    assists Nullable(Int32),
    goal_contributions Nullable(Int32),
    xg Nullable(Float32),
    xa Nullable(Float32),
    rating Nullable(Float32),
    avg_rating Nullable(Float32),
    rating_above_avg Nullable(Float32),
    minutes_played Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(player_id, -1))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_second_half_warriors (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    home_score_ft Nullable(Int32),
    away_score_ft Nullable(Int32),
    home_score_ht UInt32,
    away_score_ht UInt32,
    home_second_half_goals Int32,
    away_second_half_goals Int32,
    losing_team_at_ht LowCardinality(String),
    match_result LowCardinality(String),
    comeback_team Nullable(String),
    comeback_type LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, match_result)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_big_chance_killer (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    keeper_id Nullable(Int32),
    goalkeeper_name Nullable(String),
    goalkeeper_team_id Nullable(Int32),
    goalkeeper_team Nullable(String),
    keeper_side LowCardinality(String),
    big_chances_denied UInt32,
    total_xgot_denied Nullable(Float32),
    highest_xgot_saved Nullable(Float32),
    avg_xgot_per_save Nullable(Float32),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_ten_men_stand (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    home_red_cards UInt32,
    away_red_cards UInt32,
    home_first_red_minute Nullable(Int32),
    away_first_red_minute Nullable(Int32),
    home_score_at_red Nullable(Int32),
    away_score_at_red_home_event Nullable(Int32),
    home_score_at_red_away_event Nullable(Int32),
    away_score_at_red Nullable(Int32),
    red_card_side LowCardinality(String),
    match_result LowCardinality(String),
    resilient_team Nullable(String),
    heroic_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_progressive_powerhouse (
    match_id Int32,
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    player_team Nullable(String),
    pass_accuracy Nullable(Float32),
    passes_final_third Nullable(Int32),
    successful_dribbles Nullable(Int32),
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_sterile_control (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    period LowCardinality(String),
    ball_possession_home Nullable(Float32),
    ball_possession_away Nullable(Float32),
    passes_home Nullable(Int32),
    passes_away Nullable(Int32),
    expected_goals_home Nullable(Float32),
    expected_goals_away Nullable(Float32),
    shots_on_target_home Nullable(Int32),
    shots_on_target_away Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_defensive_masterclass (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    aerial_duels_won Nullable(Int32),
    aerial_duel_attempts Nullable(Int32),
    aerial_duel_success_rate Nullable(Float32),
    clearances Nullable(Int32),
    fouls_committed Nullable(Int32),
    fotmob_rating Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_metronome (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    touches Nullable(Int32),
    total_passes Nullable(Int32),
    pass_accuracy Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_high_intensity_engine (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    position_id Nullable(Int32),
    usual_playing_position_id Nullable(Int32),
    tackles_won Nullable(Int32),
    interceptions Nullable(Int32),
    recoveries Nullable(Int32),
    defensive_volume Nullable(Int32),
    touches Nullable(Int32),
    defensive_actions Nullable(Int32),
    event_density_per90 Nullable(Float64),
    duels_won Nullable(Int32),
    duels_lost Nullable(Int32),
    tackles_total Nullable(Int32),
    tackle_attempts Nullable(Int32),
    tackle_success_rate Nullable(Float32),
    clearances Nullable(Int32),
    dribbled_past Nullable(Int32),
    fouls_committed Nullable(Int32),
    was_fouled Nullable(Int32),
    passes_final_third Nullable(Int32),
    total_passes Nullable(Int32),
    pass_accuracy Nullable(Float32),
    expected_goals Nullable(Float32),
    expected_assists Nullable(Float32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_box_to_box_general (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    shots_on_target Nullable(Int32),
    tackles_won Nullable(Int32),
    touches_opp_box Nullable(Int32),
    pass_accuracy Nullable(Float32),
    fotmob_rating Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_against_the_grain (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    accurate_passes Nullable(Int32),
    total_passes Nullable(Int32),
    pass_accuracy Nullable(Float64),
    passes_final_third Nullable(Int32),
    accurate_long_balls Nullable(Int32),
    long_ball_attempts Nullable(Int32),
    long_ball_success_rate Nullable(Float64),
    accurate_crosses Nullable(Int32),
    cross_attempts Nullable(Int32),
    chances_created Nullable(Int32),
    team_possession Nullable(Float32),
    opponent_possession Nullable(Float32),
    possession_gap Nullable(Float32),
    against_grain_score Nullable(Float64),
    passes_per_possession_unit Nullable(Float64),
    touches Nullable(Int32),
    touches_opp_box Nullable(Int32),
    successful_dribbles Nullable(Int32),
    goals Nullable(Int32),
    assists Nullable(Int32),
    xg Nullable(Float64),
    xa Nullable(Float64),
    fotmob_rating Nullable(Float32),
    minutes_played Nullable(Int32),
    team_side Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_unpunished_aggression (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    total_match_fouls Int32,
    total_match_yellows Int32,
    league_name Nullable(String),
    fouls_home Nullable(Int32),
    fouls_away Nullable(Int32),
    yellow_cards_home Nullable(Int32),
    yellow_cards_away Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_pressing_masterclass (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    total_recoveries_home Nullable(Int32),
    total_recoveries_away Nullable(Int32),
    total_interceptions_home Nullable(Int32),
    total_interceptions_away Nullable(Int32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_elite_shot_stopper (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    total_saves Nullable(Int32),
    xg_conceded Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_hollow_dominance (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    siege_team Nullable(String),
    siege_side Nullable(String),
    total_shots_home Nullable(Int32),
    total_shots_away Nullable(Int32),
    shots_on_target_home Nullable(Int32),
    shots_on_target_away Nullable(Int32),
    shots_inside_box_home Nullable(Int32),
    shots_inside_box_away Nullable(Int32),
    blocked_shots_home Nullable(Int32),
    blocked_shots_away Nullable(Int32),
    big_chances_home Nullable(Int32),
    big_chances_away Nullable(Int32),
    big_chances_missed_home Nullable(Int32),
    big_chances_missed_away Nullable(Int32),
    xg_home Nullable(Float64),
    xg_away Nullable(Float64),
    npxg_home Nullable(Float64),
    npxg_away Nullable(Float64),
    xg_open_play_home Nullable(Float64),
    xg_open_play_away Nullable(Float64),
    siege_shots Nullable(Int32),
    siege_xg Nullable(Float64),
    siege_big_chances_missed Nullable(Int32),
    xg_underperformance Nullable(Float64),
    ball_possession_home Nullable(Float32),
    ball_possession_away Nullable(Float32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(siege_side, ''))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_touchline_terror (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    successful_dribbles Nullable(Int32),
    dribble_attempts Nullable(Int32),
    dribble_success_rate Nullable(Float32),
    touches_opp_box Nullable(Int32),
    expected_assists Nullable(Float32),
    fotmob_rating Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_line_breaker (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    accurate_long_balls Nullable(Int32),
    accurate_passes Nullable(Int32),
    pass_accuracy Nullable(Float32),
    chances_created Nullable(Int32),
    touches_opp_box Nullable(Int32),
    fotmob_rating Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_basketball_match (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    total_goals Nullable(Int32),
    goal_diff Nullable(Int32),
    xg_home Nullable(Float64),
    xg_away Nullable(Float64),
    combined_xg Nullable(Float64),
    xg_diff Nullable(Float64),
    total_shots_home Nullable(Int32),
    total_shots_away Nullable(Int32),
    combined_shots Nullable(Int32),
    shots_on_target_home Nullable(Int32),
    shots_on_target_away Nullable(Int32),
    combined_shots_on_target Nullable(Int32),
    shots_inside_box_home Nullable(Int32),
    shots_inside_box_away Nullable(Int32),
    big_chances_home Nullable(Int32),
    big_chances_away Nullable(Int32),
    combined_big_chances Nullable(Int32),
    ball_possession_home Nullable(Int32),
    ball_possession_away Nullable(Int32),
    xg_open_play_home Nullable(Float64),
    xg_open_play_away Nullable(Float64),
    combined_xg_open_play Nullable(Float64),
    chaos_score Nullable(Float64),
    chaos_type Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, ifNull(chaos_type, ''))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_lightning_rod (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    match_time_utc_date Nullable(String),
    player_name Nullable(String),
    player_team Nullable(String),
    was_fouled Nullable(Int32),
    dribble_attempts Nullable(Int32),
    touches_opp_box Nullable(Int32),
    fotmob_rating Nullable(Float32),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_human_shield (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    shots_blocked Nullable(Int32),
    clearances Nullable(Int32),
    interceptions Nullable(Int32),
    tackles_won Nullable(Int32),
    duels_won Nullable(Int32),
    duels_lost Nullable(Int32),
    aerial_duels_won Nullable(Int32),
    shield_score Nullable(Float64),
    shots_faced Nullable(UInt64),
    block_share_pct Nullable(Float64),
    fotmob_rating Nullable(Float32),
    minutes_played Nullable(Int32),
    fouls_committed Nullable(Int32),
    team_side Nullable(String),
    xg_faced Nullable(Float32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_golden_touch (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    team_side Nullable(String),
    substitution_time Nullable(Int32),
    substitution_reason Nullable(String),
    touches Nullable(Int32),
    goals Nullable(Int32),
    assists Nullable(Int32),
    goal_contributions Nullable(Int32),
    minutes_played Nullable(Int32),
    xg Nullable(Float32),
    xa Nullable(Float32),
    xg_xa Nullable(Float64),
    contribution_per_touch Nullable(Float64),
    minutes_available Nullable(Int32),
    total_shots Nullable(Int32),
    shots_on_target Nullable(Int32),
    xg_per_shot Nullable(Float64),
    fotmob_rating Nullable(Float32),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_chaos_engine (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    tackles_won Nullable(Int32),
    interceptions Nullable(Int32),
    defensive_actions Nullable(Int32),
    touches_opp_box Nullable(Int32),
    fouls_committed Nullable(Int32),
    was_fouled Nullable(Int32),
    recoveries Nullable(Int32),
    duels_won Nullable(Int32),
    duels_lost Nullable(Int32),
    duel_win_pct Nullable(Float64),
    disruption_score Nullable(Float64),
    team_total_shots Nullable(UInt64),
    team_shots_on_target Nullable(UInt64),
    team_xg Nullable(Float64),
    fotmob_rating Nullable(Float32),
    minutes_played Nullable(Int32),
    passes_final_third Nullable(Int32),
    team_side Nullable(String),
    match_result LowCardinality(String),
    match_time_utc_date Nullable(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_tired_legs (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    goal_diff Int32,
    match_time_utc_date Nullable(String),
    total_goals UInt64,
    late_goals UInt64,
    late_goals_home UInt64,
    late_goals_away UInt64,
    late_goal_pct Nullable(Float64),
    total_shots UInt64,
    late_shots UInt64,
    late_shots_on_target UInt64,
    late_shot_pct Nullable(Float64),
    total_xg Nullable(Float32),
    late_xg_total Nullable(Float32),
    late_xg_pct Nullable(Float64),
    total_attacking_subs_60_75 UInt64,
    total_subs_after_75 UInt64,
    total_subs UInt64,
    chaos_score Nullable(Float64),
    trigger_type LowCardinality(String),
    winning_team Nullable(String),
    match_result LowCardinality(String),
    winning_side LowCardinality(String),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, winning_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_black_hole (
    match_id Int32,
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_name Nullable(String),
    team_id Nullable(Int32),
    minutes_played Nullable(Int32),
    total_shots Nullable(Int32),
    shots_on_target Nullable(Int32),
    goals Nullable(Int32),
    total_xg Nullable(Float32),
    avg_xg_per_shot Nullable(Float64),
    team_total_shots Nullable(Int64),
    shot_share_pct Nullable(Float64),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_high_line_trap (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    trapping_team_side LowCardinality(String),
    trapping_team_name Nullable(String),
    opponent_name Nullable(String),
    opponent_offsides_caught Nullable(Int32),
    opponent_xg Nullable(Float64),
    opponent_total_shots Nullable(Int32),
    opponent_shots_on_target Nullable(Int32),
    opponent_big_chances Nullable(Int32),
    opponent_xg_per_shot Nullable(Float64),
    opponent_final_third_passes Nullable(Int32),
    team_possession Nullable(Int32),
    team_passes Nullable(Int32),
    team_xg Nullable(Float64),
    team_total_shots Nullable(Int32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, trapping_team_side)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_ghost_poacher (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_name Nullable(String),
    team_id Nullable(Int32),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    touches Nullable(Int32),
    touches_opp_box Nullable(Int32),
    box_touch_concentration_pct Nullable(Float64),
    expected_goals Nullable(Float32),
    goals Nullable(Int32),
    shots_on_target Nullable(Int32),
    total_shots Nullable(Int32),
    xg_non_penalty Nullable(Float32),
    xg_per_shot Nullable(Float64),
    assists Nullable(Int32),
    expected_assists Nullable(Float32),
    chances_created Nullable(Int32),
    xg_plus_xa Nullable(Float64),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_route_one_masterclass (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    long_balls_accurate_home Nullable(Int32),
    long_ball_pct_home Nullable(Int32),
    long_balls_accurate_away Nullable(Int32),
    long_ball_pct_away Nullable(Int32),
    possession_home Nullable(Int32),
    possession_away Nullable(Int32),
    passes_home Nullable(Int32),
    passes_away Nullable(Int32),
    xg_home Nullable(Float64),
    xg_away Nullable(Float64),
    total_shots_home Nullable(Int32),
    total_shots_away Nullable(Int32),
    big_chances_home Nullable(Int32),
    big_chances_away Nullable(Int32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_total_suffocation (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    possession_home Nullable(Int32),
    possession_away Nullable(Int32),
    shots_on_target_home Nullable(Int32),
    shots_on_target_away Nullable(Int32),
    xg_home Nullable(Float64),
    xg_away Nullable(Float64),
    touches_opp_box_home Nullable(Int32),
    touches_opp_box_away Nullable(Int32),
    total_shots_home Nullable(Int32),
    total_shots_away Nullable(Int32),
    big_chances_home Nullable(Int32),
    big_chances_away Nullable(Int32),
    passes_home Nullable(Int32),
    passes_away Nullable(Int32),
    corners_home Nullable(Int32),
    corners_away Nullable(Int32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_territorial_suffocation (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    possession_home Nullable(Int32),
    possession_away Nullable(Int32),
    shots_on_target_home Nullable(Int32),
    shots_on_target_away Nullable(Int32),
    total_shots_home Nullable(Int32),
    total_shots_away Nullable(Int32),
    touches_opp_box_home Nullable(Int32),
    touches_opp_box_away Nullable(Int32),
    xg_home Nullable(Float64),
    xg_away Nullable(Float64),
    big_chances_home Nullable(Int32),
    big_chances_away Nullable(Int32),
    passes_home Nullable(Int32),
    passes_away Nullable(Int32),
    corners_home Nullable(Int32),
    corners_away Nullable(Int32),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id)
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));

CREATE TABLE IF NOT EXISTS gold_scenarios.scenario_clinical_pivot (
    match_id Int32,
    home_team_id Nullable(Int32),
    away_team_id Nullable(Int32),
    home_team_name Nullable(String),
    away_team_name Nullable(String),
    home_score Nullable(Int32),
    away_score Nullable(Int32),
    league_name Nullable(String),
    match_time_utc_date Nullable(String),
    player_id Nullable(Int32),
    player_name Nullable(String),
    team_id Nullable(Int32),
    team_name Nullable(String),
    minutes_played Nullable(Int32),
    fotmob_rating Nullable(Float32),
    total_passes Nullable(Int32),
    accurate_passes Nullable(Int32),
    pass_accuracy Nullable(Float32),
    passes_final_third Nullable(Int32),
    touches_opp_box Nullable(Int32),
    touches Nullable(Int32),
    expected_goals Nullable(Float32),
    expected_assists Nullable(Float32),
    chances_created Nullable(Int32),
    successful_dribbles Nullable(Int32),
    interceptions Nullable(Int32),
    recoveries Nullable(Int32),
    defensive_actions Nullable(Int32),
    xg_plus_xa Nullable(Float64),
    inserted_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY (match_id, assumeNotNull(player_id))
PARTITION BY toYYYYMM(assumeNotNull(toDateOrZero(match_time_utc_date)));
