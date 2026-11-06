INSERT INTO fotmob_silver.player_match_stat
SELECT
    p.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    p.player_id,
    p.player_name,
    p.opta_id,
    ifNull(p.team_id, -1) AS team_id,
    p.team_name,
    ifNull(p.is_goalkeeper, 0) AS is_goalkeeper,
    p.fotmob_rating, p.minutes_played,
    p.goals, p.assists,
    p.total_shots, p.shots_on_target, p.shots_off_target, p.blocked_shots,
    p.expected_goals, p.expected_assists, p.xg_plus_xa, p.xg_non_penalty,
    p.chances_created, p.average_xg_per_shot, p.total_xg, p.shotmap_count,
    p.touches, p.touches_opp_box,
    p.successful_dribbles, p.dribble_attempts, p.dribble_success_rate,
    p.accurate_passes, p.total_passes, p.pass_accuracy, p.passes_final_third,
    p.accurate_crosses, p.cross_attempts, p.cross_success_rate,
    p.accurate_long_balls, p.long_ball_attempts, p.long_ball_success_rate,
    p.tackles_won, p.tackle_attempts, p.tackle_success_rate,
    p.interceptions, p.clearances, p.defensive_actions, p.recoveries, p.dribbled_past,
    p.duels_won, p.duels_lost,
    p.ground_duels_won, p.ground_duel_attempts, p.ground_duel_success_rate,
    p.aerial_duels_won, p.aerial_duel_attempts, p.aerial_duel_success_rate,
    p.fouls_committed, p.was_fouled,
    now() AS _loaded_at
FROM fotmob_bronze.player AS p FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON p.match_id = g.match_id
WHERE p.team_id IS NOT NULL;
