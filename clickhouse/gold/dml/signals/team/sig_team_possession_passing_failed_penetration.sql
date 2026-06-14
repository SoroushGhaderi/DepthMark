INSERT INTO gold.sig_team_possession_passing_failed_penetration (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    triggered_team_touches_opposition_box,
    triggered_team_shots_inside_box,
    opponent_touches_opposition_box,
    opponent_shots_inside_box,
    triggered_team_touches_per_box_shot,
    opponent_touches_per_box_shot,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    triggered_team_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances,
    opponent_big_chances_missed,
    triggered_team_accurate_crosses,
    triggered_team_cross_attempts,
    triggered_team_cross_accuracy_pct,
    opponent_accurate_crosses,
    opponent_cross_attempts,
    opponent_cross_accuracy_pct,
    triggered_team_dribbles_succeeded,
    triggered_team_dribble_attempts,
    opponent_dribbles_succeeded,
    opponent_dribble_attempts,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_corners,
    opponent_corners,
    box_touch_delta,
    xg_delta,
    corners_delta
)
-- Signal: sig_team_possession_passing_failed_penetration
-- Trigger: touches_opp_box >= 30 with shots_inside_box < 10 for the triggered side.
-- Intent: identify territorial dominance that fails to become high-quality box shooting output.
-- === sig_team_possession_passing_failed_penetration ===
-- Detects matches where a team achieves >= 30 touches in the opponent penalty box
-- yet records < 5 shots from inside the box — indicating high territorial penetration
-- without the cutting edge to generate meaningful shooting opportunities.
-- Signals final-third decision-making failure: overcrowding, crossing dependency,
-- or defensive compactness neutralising presence despite positional dominance.

WITH candidates AS (
    -- Unpivot home / away into one triggered row per qualifying team
    SELECT
        ps.match_id,
        'home'                                                       AS triggered_side,
        coalesce(ps.touches_opp_box_home,      0)                   AS triggered_team_touches_opposition_box,
        coalesce(ps.shots_inside_box_home,      0)                   AS triggered_team_shots_inside_box,
        coalesce(ps.total_shots_home,           0)                   AS triggered_team_total_shots,
        coalesce(ps.expected_goals_home,        0)                   AS triggered_team_xg,
        coalesce(ps.big_chances_home,           0)                   AS triggered_team_big_chances,
        coalesce(ps.big_chances_missed_home,    0)                   AS triggered_team_big_chances_missed,
        coalesce(ps.accurate_crosses_home,      0)                   AS triggered_team_accurate_crosses,
        coalesce(ps.cross_attempts_home,        0)                   AS triggered_team_cross_attempts,
        coalesce(ps.dribbles_succeeded_home,    0)                   AS triggered_team_dribbles_succeeded,
        coalesce(ps.dribble_attempts_home,      0)                   AS triggered_team_dribble_attempts,
        coalesce(ps.opposition_half_passes_home,0)                   AS triggered_team_opposition_half_passes,
        coalesce(ps.corners_home,               0)                   AS triggered_team_corners,
        -- Opponent symmetric values
        coalesce(ps.touches_opp_box_away,      0)                   AS opponent_touches_opposition_box,
        coalesce(ps.shots_inside_box_away,      0)                   AS opponent_shots_inside_box,
        coalesce(ps.total_shots_away,           0)                   AS opponent_total_shots,
        coalesce(ps.expected_goals_away,        0)                   AS opponent_xg,
        coalesce(ps.big_chances_away,           0)                   AS opponent_big_chances,
        coalesce(ps.big_chances_missed_away,    0)                   AS opponent_big_chances_missed,
        coalesce(ps.accurate_crosses_away,      0)                   AS opponent_accurate_crosses,
        coalesce(ps.cross_attempts_away,        0)                   AS opponent_cross_attempts,
        coalesce(ps.dribbles_succeeded_away,    0)                   AS opponent_dribbles_succeeded,
        coalesce(ps.dribble_attempts_away,      0)                   AS opponent_dribble_attempts,
        coalesce(ps.opposition_half_passes_away,0)                   AS opponent_opposition_half_passes,
        coalesce(ps.corners_away,               0)                   AS opponent_corners
    FROM silver.period_stat AS ps
    WHERE ps.period = 'All'
      AND coalesce(ps.touches_opp_box_home, 0) >= 30
      AND coalesce(ps.shots_inside_box_home, 0) < 10

    UNION ALL

    SELECT
        ps.match_id,
        'away'                                                       AS triggered_side,
        coalesce(ps.touches_opp_box_away,      0),
        coalesce(ps.shots_inside_box_away,      0),
        coalesce(ps.total_shots_away,           0),
        coalesce(ps.expected_goals_away,        0),
        coalesce(ps.big_chances_away,           0),
        coalesce(ps.big_chances_missed_away,    0),
        coalesce(ps.accurate_crosses_away,      0),
        coalesce(ps.cross_attempts_away,        0),
        coalesce(ps.dribbles_succeeded_away,    0),
        coalesce(ps.dribble_attempts_away,      0),
        coalesce(ps.opposition_half_passes_away,0),
        coalesce(ps.corners_away,               0),
        -- Opponent symmetric values
        coalesce(ps.touches_opp_box_home,      0),
        coalesce(ps.shots_inside_box_home,      0),
        coalesce(ps.total_shots_home,           0),
        coalesce(ps.expected_goals_home,        0),
        coalesce(ps.big_chances_home,           0),
        coalesce(ps.big_chances_missed_home,    0),
        coalesce(ps.accurate_crosses_home,      0),
        coalesce(ps.cross_attempts_home,        0),
        coalesce(ps.dribbles_succeeded_home,    0),
        coalesce(ps.dribble_attempts_home,      0),
        coalesce(ps.opposition_half_passes_home,0),
        coalesce(ps.corners_home,               0)
    FROM silver.period_stat AS ps
    WHERE ps.period = 'All'
      AND coalesce(ps.touches_opp_box_away, 0) >= 30
      AND coalesce(ps.shots_inside_box_away, 0) < 10
)

SELECT
    -- ── Identifiers ─────────────────────────────────────────────────────────
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- ── Triggered team identity ──────────────────────────────────────────────
    c.triggered_side                                                         AS triggered_side,
    if(c.triggered_side = 'home', m.home_team_id,   assumeNotNull(m.away_team_id))
                                                                             AS triggered_team_id,
    if(c.triggered_side = 'home', m.home_team_name, m.away_team_name)       AS triggered_team_name,

    -- ── Opponent identity ────────────────────────────────────────────────────
    if(c.triggered_side = 'home', assumeNotNull(m.away_team_id),   m.home_team_id)
                                                                             AS opponent_team_id,
    if(c.triggered_side = 'home', m.away_team_name, m.home_team_name)       AS opponent_team_name,

    -- ── Signal: box touches & inside-box shots (core signal pair) ───────────
    c.triggered_team_touches_opposition_box                                              AS triggered_team_touches_opposition_box,
    c.triggered_team_shots_inside_box                                             AS triggered_team_shots_inside_box,
    c.opponent_touches_opposition_box                                               AS opponent_touches_opposition_box,
    c.opponent_shots_inside_box                                              AS opponent_shots_inside_box,

    -- ── Box entry-to-shot conversion ratio (bilateral) ──────────────────────
    -- How many box touches were needed to generate each inside-box shot
    round(if(c.triggered_team_shots_inside_box > 0,
             c.triggered_team_touches_opposition_box / c.triggered_team_shots_inside_box,
             NULL), 2)                                                       AS triggered_team_touches_per_box_shot,
    round(if(c.opponent_shots_inside_box > 0,
             c.opponent_touches_opposition_box / c.opponent_shots_inside_box,
             NULL), 2)                                                       AS opponent_touches_per_box_shot,

    -- ── Total shot volume (bilateral) ────────────────────────────────────────
    c.triggered_team_total_shots                                                  AS triggered_team_total_shots,
    c.opponent_total_shots                                                   AS opponent_total_shots,

    -- ── xG (bilateral) — quantifies if presence translated to quality ────────
    c.triggered_team_xg                                                           AS triggered_team_xg,
    c.opponent_xg                                                            AS opponent_xg,

    -- ── Big chances created and missed (bilateral) ───────────────────────────
    c.triggered_team_big_chances                                                  AS triggered_team_big_chances,
    c.triggered_team_big_chances_missed                                           AS triggered_team_big_chances_missed,
    c.opponent_big_chances                                                   AS opponent_big_chances,
    c.opponent_big_chances_missed                                            AS opponent_big_chances_missed,

    -- ── Crossing volume & accuracy (bilateral) — primary failed-penetration route
    c.triggered_team_accurate_crosses                                             AS triggered_team_accurate_crosses,
    c.triggered_team_cross_attempts                                               AS triggered_team_cross_attempts,
    round(if(c.triggered_team_cross_attempts > 0,
             c.triggered_team_accurate_crosses * 100.0 / c.triggered_team_cross_attempts, 0), 1)
                                                                             AS triggered_team_cross_accuracy_pct,
    c.opponent_accurate_crosses                                              AS opponent_accurate_crosses,
    c.opponent_cross_attempts                                                AS opponent_cross_attempts,
    round(if(c.opponent_cross_attempts > 0,
             c.opponent_accurate_crosses * 100.0 / c.opponent_cross_attempts, 0), 1)
                                                                             AS opponent_cross_accuracy_pct,

    -- ── Dribble success (bilateral) — individual carrying into box ───────────
    c.triggered_team_dribbles_succeeded                                           AS triggered_team_dribbles_succeeded,
    c.triggered_team_dribble_attempts                                             AS triggered_team_dribble_attempts,
    c.opponent_dribbles_succeeded                                            AS opponent_dribbles_succeeded,
    c.opponent_dribble_attempts                                              AS opponent_dribble_attempts,

    -- ── Opposition-half passing volume (bilateral) — measures sustained pressure phase
    c.triggered_team_opposition_half_passes                                              AS triggered_team_opposition_half_passes,
    c.opponent_opposition_half_passes                                               AS opponent_opposition_half_passes,

    -- ── Corners (bilateral) — often product of failed box entries ────────────
    c.triggered_team_corners                                                      AS triggered_team_corners,
    c.opponent_corners                                                       AS opponent_corners,

    -- ── Net / delta columns (bilateral by construction) ─────────────────────
    -- Positive = triggered team outpressed in final third
    (c.triggered_team_touches_opposition_box - c.opponent_touches_opposition_box)              AS box_touch_delta,
    -- Positive = triggered team generated more xG despite shot failure
    round(c.triggered_team_xg - c.opponent_xg, 3)                                AS xg_delta,
    -- Positive = triggered team forced more corner situations
    (c.triggered_team_corners - c.opponent_corners)                               AS corners_delta

FROM silver.match AS m
INNER JOIN candidates AS c
        ON c.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
ORDER BY c.triggered_team_touches_opposition_box DESC;
