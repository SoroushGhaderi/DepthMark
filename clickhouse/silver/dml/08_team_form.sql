INSERT INTO fotmob_silver.team_form
SELECT
    tf.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    tf.team_side, tf.team_id, tf.team_name, tf.form_position,
    tf.result AS result_code,
    tf.result_string,
    toInt32OrNull(tf.form_match_id) AS form_match_id,
    toDateOrNull(tf.form_match_date) AS form_match_date,
    tf.form_match_link,
    tf.opponent_id, tf.opponent_name, tf.is_home_match,
    tf.home_team_id, tf.home_team_name,
    toInt32OrNull(tf.home_score) AS home_score,
    tf.away_team_id, tf.away_team_name,
    toInt32OrNull(tf.away_score) AS away_score,
    now() AS _loaded_at
FROM fotmob_bronze.team_form AS tf FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON tf.match_id = g.match_id;
