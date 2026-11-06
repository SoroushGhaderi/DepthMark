INSERT INTO fotmob_silver.period_stat
SELECT
    p.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    p.period,
    p.ball_possession_home, p.ball_possession_away,
    p.expected_goals_home, p.expected_goals_away,
    p.expected_goals_open_play_home, p.expected_goals_open_play_away,
    p.expected_goals_set_play_home, p.expected_goals_set_play_away,
    p.expected_goals_non_penalty_home, p.expected_goals_non_penalty_away,
    p.expected_goals_on_target_home, p.expected_goals_on_target_away,
    p.distance_covered_home, p.distance_covered_away,
    p.walking_distance_home, p.walking_distance_away,
    p.running_distance_home, p.running_distance_away,
    p.sprinting_distance_home, p.sprinting_distance_away,
    p.number_of_sprints_home, p.number_of_sprints_away,
    p.top_speed_home, p.top_speed_away,
    p.total_shots_home, p.total_shots_away,
    p.shots_on_target_home, p.shots_on_target_away,
    p.shots_off_target_home, p.shots_off_target_away,
    p.blocked_shots_home, p.blocked_shots_away,
    p.shots_woodwork_home, p.shots_woodwork_away,
    p.shots_inside_box_home, p.shots_inside_box_away,
    p.shots_outside_box_home, p.shots_outside_box_away,
    p.big_chances_home, p.big_chances_away,
    p.big_chances_missed_home, p.big_chances_missed_away,
    p.passes_home, p.passes_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_passes_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.accurate_passes_home, ''), '^\\s*(\\d+)'))
    ) AS accurate_passes_home,
    coalesce(
        p.passes_home,
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_passes_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.accurate_passes_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.accurate_passes_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.accurate_passes_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.accurate_passes_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS pass_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_passes_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.accurate_passes_away, ''), '^\\s*(\\d+)'))
    ) AS accurate_passes_away,
    coalesce(
        p.passes_away,
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_passes_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.accurate_passes_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.accurate_passes_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.accurate_passes_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.accurate_passes_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS pass_attempts_away,
    p.own_half_passes_home, p.own_half_passes_away,
    p.opposition_half_passes_home, p.opposition_half_passes_away,
    p.player_throws_home, p.player_throws_away,
    p.touches_opp_box_home, p.touches_opp_box_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.long_balls_accurate_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.long_balls_accurate_home, ''), '^\\s*(\\d+)'))
    ) AS accurate_long_balls_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.long_balls_accurate_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.long_balls_accurate_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.long_balls_accurate_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.long_balls_accurate_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.long_balls_accurate_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS long_ball_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.long_balls_accurate_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.long_balls_accurate_away, ''), '^\\s*(\\d+)'))
    ) AS accurate_long_balls_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.long_balls_accurate_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.long_balls_accurate_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.long_balls_accurate_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.long_balls_accurate_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.long_balls_accurate_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS long_ball_attempts_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_crosses_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.accurate_crosses_home, ''), '^\\s*(\\d+)'))
    ) AS accurate_crosses_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_crosses_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.accurate_crosses_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.accurate_crosses_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.accurate_crosses_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.accurate_crosses_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS cross_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_crosses_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.accurate_crosses_away, ''), '^\\s*(\\d+)'))
    ) AS accurate_crosses_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.accurate_crosses_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.accurate_crosses_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.accurate_crosses_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.accurate_crosses_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.accurate_crosses_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS cross_attempts_away,
    p.interceptions_home, p.interceptions_away,
    p.clearances_home, p.clearances_away,
    p.shot_blocks_home, p.shot_blocks_away,
    p.keeper_saves_home, p.keeper_saves_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.tackles_succeeded_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.tackles_succeeded_home, ''), '^\\s*(\\d+)'))
    ) AS tackles_succeeded_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.tackles_succeeded_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.tackles_succeeded_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.tackles_succeeded_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.tackles_succeeded_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.tackles_succeeded_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS tackle_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.tackles_succeeded_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.tackles_succeeded_away, ''), '^\\s*(\\d+)'))
    ) AS tackles_succeeded_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.tackles_succeeded_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.tackles_succeeded_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.tackles_succeeded_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.tackles_succeeded_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.tackles_succeeded_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS tackle_attempts_away,
    p.duels_won_home, p.duels_won_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.ground_duels_won_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.ground_duels_won_home, ''), '^\\s*(\\d+)'))
    ) AS ground_duels_won_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.ground_duels_won_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.ground_duels_won_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.ground_duels_won_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.ground_duels_won_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.ground_duels_won_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS ground_duel_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.ground_duels_won_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.ground_duels_won_away, ''), '^\\s*(\\d+)'))
    ) AS ground_duels_won_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.ground_duels_won_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.ground_duels_won_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.ground_duels_won_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.ground_duels_won_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.ground_duels_won_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS ground_duel_attempts_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.aerials_won_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.aerials_won_home, ''), '^\\s*(\\d+)'))
    ) AS aerials_won_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.aerials_won_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.aerials_won_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.aerials_won_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.aerials_won_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.aerials_won_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS aerial_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.aerials_won_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.aerials_won_away, ''), '^\\s*(\\d+)'))
    ) AS aerials_won_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.aerials_won_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.aerials_won_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.aerials_won_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.aerials_won_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.aerials_won_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS aerial_attempts_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.dribbles_succeeded_home, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.dribbles_succeeded_home, ''), '^\\s*(\\d+)'))
    ) AS dribbles_succeeded_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.dribbles_succeeded_home, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.dribbles_succeeded_home, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.dribbles_succeeded_home, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.dribbles_succeeded_home, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.dribbles_succeeded_home, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS dribble_attempts_home,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.dribbles_succeeded_away, ''))[1], '')),
        toInt32OrNull(extract(ifNull(p.dribbles_succeeded_away, ''), '^\\s*(\\d+)'))
    ) AS dribbles_succeeded_away,
    coalesce(
        toInt32OrNull(nullIf(splitByChar('/', ifNull(p.dribbles_succeeded_away, ''))[2], '')),
        if(
            toInt32OrNull(extract(ifNull(p.dribbles_succeeded_away, ''), '\\((\\d+)%\\)')) > 0
            AND toInt32OrNull(extract(ifNull(p.dribbles_succeeded_away, ''), '^\\s*(\\d+)')) IS NOT NULL,
            toInt32(
                round(
                    toFloat64(toInt32OrNull(extract(ifNull(p.dribbles_succeeded_away, ''), '^\\s*(\\d+)'))) * 100.0
                    / toFloat64(toInt32OrNull(extract(ifNull(p.dribbles_succeeded_away, ''), '\\((\\d+)%\\)')))
                )
            ),
            NULL
        )
    ) AS dribble_attempts_away,
    p.yellow_cards_home, p.yellow_cards_away,
    p.red_cards_home, p.red_cards_away,
    p.fouls_home, p.fouls_away,
    p.corners_home, p.corners_away,
    p.offsides_home, p.offsides_away,
    now() AS _loaded_at
FROM fotmob_bronze.period AS p FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON p.match_id = g.match_id;
