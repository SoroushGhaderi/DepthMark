INSERT INTO fotmob_silver.momentum
SELECT
    m.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    m.minute,
    m.value,
    m.momentum_team,
    now() AS _loaded_at
FROM fotmob_bronze.momentum AS m FINAL
LEFT JOIN fotmob_bronze.general AS g FINAL ON m.match_id = g.match_id;
