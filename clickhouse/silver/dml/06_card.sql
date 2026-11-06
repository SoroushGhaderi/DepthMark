INSERT INTO fotmob_silver.card
SELECT
    c.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    c.event_id,
    c.event_time AS card_minute,
    c.added_time,
    c.player_id, c.player_name,
    c.team AS team_side,
    c.card_type, c.description,
    toInt32OrNull(
        arrayElement(
            splitByChar('-', replaceAll(ifNull(c.score_at_event, ''), ' ', '')),
            1
        )
    ) AS score_home_at_time,
    toInt32OrNull(
        arrayElement(
            splitByChar('-', replaceAll(ifNull(c.score_at_event, ''), ' ', '')),
            2
        )
    ) AS score_away_at_time,
    now() AS _loaded_at
FROM fotmob_bronze.cards AS c FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON c.match_id = g.match_id;
