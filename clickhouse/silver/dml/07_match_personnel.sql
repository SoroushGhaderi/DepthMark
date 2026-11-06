INSERT INTO fotmob_silver.match_personnel
SELECT
    s.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    s.team_side,
    'starter' AS role,
    s.player_id AS person_id,
    s.name, s.first_name, s.last_name, s.age,
    s.country_name, s.country_code,
    toInt32OrNull(s.shirt_number) AS shirt_number,
    s.position_id, s.usual_playing_position_id,
    s.is_captain, s.performance_rating,
    s.substitution_time, s.substitution_type, s.substitution_reason,
    NULL AS primary_team_id, NULL AS primary_team_name,
    now() AS _loaded_at
FROM fotmob_bronze.starters AS s FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON s.match_id = g.match_id
WHERE s.match_id > 0
  AND s.player_id > 0
  AND length(trim(BOTH ' ' FROM s.team_side)) > 0;

INSERT INTO fotmob_silver.match_personnel
SELECT
    s.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    s.team_side,
    'substitute' AS role,
    s.player_id AS person_id,
    s.name, s.first_name, s.last_name, s.age,
    s.country_name, s.country_code,
    toInt32OrNull(s.shirt_number) AS shirt_number,
    NULL AS position_id,
    s.usual_playing_position_id,
    NULL AS is_captain,
    s.performance_rating,
    s.substitution_time, s.substitution_type, s.substitution_reason,
    NULL AS primary_team_id, NULL AS primary_team_name,
    now() AS _loaded_at
FROM fotmob_bronze.substitutes AS s FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON s.match_id = g.match_id
WHERE s.match_id > 0
  AND s.player_id > 0
  AND length(trim(BOTH ' ' FROM s.team_side)) > 0;

INSERT INTO fotmob_silver.match_personnel
SELECT
    c.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    c.team_side,
    'coach' AS role,
    c.coach_id AS person_id,
    c.name, c.first_name, c.last_name, c.age,
    c.country_name, c.country_code,
    NULL AS shirt_number,
    NULL AS position_id,
    NULL AS usual_playing_position_id,
    NULL AS is_captain,
    NULL AS performance_rating,
    NULL AS substitution_time,
    NULL AS substitution_type,
    NULL AS substitution_reason,
    c.primary_team_id, c.primary_team_name,
    now() AS _loaded_at
FROM fotmob_bronze.coaches AS c FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON c.match_id = g.match_id
WHERE c.match_id > 0
  AND c.coach_id > 0
  AND length(trim(BOTH ' ' FROM c.team_side)) > 0;
