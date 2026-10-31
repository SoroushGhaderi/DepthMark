"""Match-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MatchTimeline(BaseModel):
    """Represents the timeline and status of a football match."""

    model_config = ConfigDict(
        extra="ignore",
        validate_assignment=True,
        str_strip_whitespace=True,
    )

    match_id: int | None = Field(None, description="Unique match identifier")
    match_time_utc: datetime | None = Field(None, description="Scheduled match start time UTC")
    first_half_started: str | None = Field(None, description="Actual first half start time")
    first_half_ended: str | None = Field(None, description="First half end time")
    second_half_started: str | None = Field(None, description="Second half start time")
    second_half_ended: str | None = Field(None, description="Second half end time")
    first_extra_half_started: str | None = Field(
        None, description="First extra time half start time"
    )
    second_extra_half_started: str | None = Field(
        None, description="Second extra time half start time"
    )
    game_ended: str | None = Field(None, description="Final match end time")
    game_finished: bool | None = Field(False, description="Whether the match completed normally")
    game_started: bool | None = Field(False, description="Whether the match started")
    game_cancelled: bool | None = Field(False, description="Whether the match was cancelled")


class GeneralMatchStats(BaseModel):
    """Represents general statistics and information about a match."""

    model_config = ConfigDict(
        extra="ignore",
        validate_assignment=True,
        str_strip_whitespace=True,
    )

    match_id: int | None = Field(None, description="Unique match identifier")
    match_round: str | None = Field(None, description="Current round of the match")
    team_color_dark_mode_home: str | None = Field(None, description="Home team color dark mode")
    team_color_dark_mode_away: str | None = Field(None, description="Away team color dark mode")
    team_color_light_mode_home: str | None = Field(None, description="Home team color light mode")
    team_color_light_mode_away: str | None = Field(None, description="Away team color light mode")
    league_id: int | None = Field(None, description="League ID")
    league_name: str | None = Field(None, description="League name")
    league_round_name: str | None = Field(None, description="Name of the league round")
    parent_league_id: int | None = Field(None, description="Parent league ID")
    country_code: str | None = Field(None, description="Country code of the league")
    parent_league_name: str | None = Field(None, description="Parent league name")
    parent_league_season: str | None = Field(None, description="Parent league season")
    parent_league_tournament_id: int | None = Field(None, description="Parent league tournament ID")
    home_team_name: str | None = Field(None, description="Home team name")
    home_team_id: int | None = Field(None, description="Home team ID")
    away_team_name: str | None = Field(None, description="Away team name")
    away_team_id: int | None = Field(None, description="Away team ID")
    coverage_level: str | None = Field(None, description="Match coverage level")
    match_time_utc: str | None = Field(None, description="Scheduled match time UTC")
    match_time_utc_date: str | None = Field(None, description="Match date UTC")
    match_started: bool = Field(False, description="Whether match has started")
    match_finished: bool = Field(False, description="Whether match has finished")
    full_score: str | None = Field(None, description="Full match score as string (e.g., '2-1')")
    home_score: int | None = Field(None, description="Home team score parsed from full score")
    away_score: int | None = Field(None, description="Away team score parsed from full score")


class InfoBox(BaseModel):
    """Represents general information details about the match, stadium, and referee."""

    model_config = ConfigDict(
        extra="ignore",
        validate_assignment=True,
        str_strip_whitespace=True,
    )

    match_id: int | None = Field(None, description="Unique identifier for the match")
    match_date_utc: datetime | None = Field(None, description="Match date and time UTC")
    match_date_verified: bool | None = Field(
        None, description="Flag indicating if date is verified"
    )
    tournament_id: int | None = Field(None, description="Tournament ID")
    parent_league_id: int | None = Field(None, description="Parent league ID")
    league_name: str | None = Field(None, description="Name of the league")
    round_name: str | None = Field(None, description="Name of the round")
    round_number: str | None = Field(None, description="Round number")
    season: str | None = Field(None, description="Current season")
    stadium_name: str | None = Field(None, description="Stadium name")
    stadium_city: str | None = Field(None, description="City where stadium is located")
    stadium_country: str | None = Field(None, description="Country where stadium is located")
    stadium_lat: float | None = Field(None, description="Latitude coordinate")
    stadium_long: float | None = Field(None, description="Longitude coordinate")
    referee_name: str | None = Field(None, description="Referee name")
    referee_country: str | None = Field(None, description="Referee nationality")
    attendance: int | None = Field(None, description="Number of attendees")


class MomentumDataPoint(BaseModel):
    """Represents a single data point in the match momentum chart."""

    model_config = ConfigDict(extra="ignore")

    match_id: int = Field(..., description="Unique match identifier")
    minute: float | None = Field(..., description="Match minute timestamp")
    value: int | None = Field(..., description="Momentum value (-100 to 100)")
    momentum_team: str | None = Field(..., description="Which team has momentum")


class PeriodStats(BaseModel):
    """Represents aggregated statistics for a specific period of the match."""

    model_config = ConfigDict(
        extra="ignore",
        validate_assignment=True,
    )

    match_id: int = Field(..., description="Unique match identifier")
    period: str = Field(..., description="Match period")
    ball_possession_home: int | None = Field(None, description="Ball possession % for home team")
    ball_possession_away: int | None = Field(None, description="Ball possession % for away team")
    expected_goals_home: float | None = Field(None, description="xG for home team")
    expected_goals_away: float | None = Field(None, description="xG for away team")
    expected_goals_open_play_home: float | None = Field(
        None, description="xG from open play for home"
    )
    expected_goals_open_play_away: float | None = Field(
        None, description="xG from open play for away"
    )
    expected_goals_set_play_home: float | None = Field(
        None, description="xG from set play for home"
    )
    expected_goals_set_play_away: float | None = Field(
        None, description="xG from set play for away"
    )
    expected_goals_non_penalty_home: float | None = Field(
        None, description="xG excluding penalties for home"
    )
    expected_goals_non_penalty_away: float | None = Field(
        None, description="xG excluding penalties for away"
    )
    expected_goals_on_target_home: float | None = Field(None, description="xGOT for home team")
    expected_goals_on_target_away: float | None = Field(None, description="xGOT for away team")
    distance_covered_home: float | None = Field(
        None, description="Distance covered by home team (meters)"
    )
    distance_covered_away: float | None = Field(
        None, description="Distance covered by away team (meters)"
    )
    walking_distance_home: float | None = Field(
        None, description="Walking distance by home team (meters)"
    )
    walking_distance_away: float | None = Field(
        None, description="Walking distance by away team (meters)"
    )
    running_distance_home: float | None = Field(
        None, description="Running distance by home team (meters)"
    )
    running_distance_away: float | None = Field(
        None, description="Running distance by away team (meters)"
    )
    sprinting_distance_home: float | None = Field(
        None, description="Sprinting distance by home team (meters)"
    )
    sprinting_distance_away: float | None = Field(
        None, description="Sprinting distance by away team (meters)"
    )
    number_of_sprints_home: int | None = Field(None, description="Number of sprints by home team")
    number_of_sprints_away: int | None = Field(None, description="Number of sprints by away team")
    physical_metrics_distance_covered_home: float | None = Field(
        None, description="Distance covered by home team (source alias)"
    )
    physical_metrics_distance_covered_away: float | None = Field(
        None, description="Distance covered by away team (source alias)"
    )
    physical_metrics_walking_home: float | None = Field(
        None, description="Walking distance by home team (source alias)"
    )
    physical_metrics_walking_away: float | None = Field(
        None, description="Walking distance by away team (source alias)"
    )
    physical_metrics_running_home: float | None = Field(
        None, description="Running distance by home team (source alias)"
    )
    physical_metrics_running_away: float | None = Field(
        None, description="Running distance by away team (source alias)"
    )
    physical_metrics_sprinting_home: float | None = Field(
        None, description="Sprinting distance by home team (source alias)"
    )
    physical_metrics_sprinting_away: float | None = Field(
        None, description="Sprinting distance by away team (source alias)"
    )
    physical_metrics_number_of_sprints_home: int | None = Field(
        None, description="Number of sprints by home team (source alias)"
    )
    physical_metrics_number_of_sprints_away: int | None = Field(
        None, description="Number of sprints by away team (source alias)"
    )
    top_speed_home: float | None = Field(None, description="Top speed by home team (km/h)")
    top_speed_away: float | None = Field(None, description="Top speed by away team (km/h)")
    total_shots_home: int | None = Field(None, description="Total shots by home team")
    total_shots_away: int | None = Field(None, description="Total shots by away team")
    shots_on_target_home: int | None = Field(None, description="Shots on target by home")
    shots_on_target_away: int | None = Field(None, description="Shots on target by away")
    shots_off_target_home: int | None = Field(None, description="Shots off target by home")
    shots_off_target_away: int | None = Field(None, description="Shots off target by away")
    blocked_shots_home: int | None = Field(None, description="Blocked shots by home")
    blocked_shots_away: int | None = Field(None, description="Blocked shots by away")
    shots_woodwork_home: int | None = Field(None, description="Shots hitting woodwork by home")
    shots_woodwork_away: int | None = Field(None, description="Shots hitting woodwork by away")
    shots_sidebox_home: int | None = Field(None, description="Shots from inside box by home")
    shots_sidebox_away: int | None = Field(None, description="Shots from inside box by away")
    shots_inside_box_home: int | None = Field(None, description="Shots from inside box by home")
    shots_inside_box_away: int | None = Field(None, description="Shots from inside box by away")
    shots_outside_box_home: int | None = Field(None, description="Shots from outside box by home")
    shots_outside_box_away: int | None = Field(None, description="Shots from outside box by away")
    big_chances_home: int | None = Field(None, description="Big chances by home")
    big_chances_away: int | None = Field(None, description="Big chances by away")
    big_chances_missed_home: int | None = Field(None, description="Big chances missed by home")
    big_chances_missed_away: int | None = Field(None, description="Big chances missed by away")
    fouls_home: int | None = Field(None, description="Fouls committed by home")
    fouls_away: int | None = Field(None, description="Fouls committed by away")
    corners_home: int | None = Field(None, description="Corners by home")
    corners_away: int | None = Field(None, description="Corners by away")
    shots_home: int | None = Field(None, description="Shots by home (alternative)")
    shots_away: int | None = Field(None, description="Shots by away (alternative)")
    passes_home: int | None = Field(None, description="Total passes by home")
    passes_away: int | None = Field(None, description="Total passes by away")
    accurate_passes_home: str | None = Field(
        None, description="Accurate passes for home (ratio or count)"
    )
    accurate_passes_away: str | None = Field(
        None, description="Accurate passes for away (ratio or count)"
    )
    own_half_passes_home: int | None = Field(None, description="Passes in own half by home")
    own_half_passes_away: int | None = Field(None, description="Passes in own half by away")
    opposition_half_passes_home: int | None = Field(
        None, description="Passes in opposition half by home"
    )
    opposition_half_passes_away: int | None = Field(
        None, description="Passes in opposition half by away"
    )
    long_balls_accurate_home: str | None = Field(
        None, description="Accurate long balls for home (ratio or count)"
    )
    long_balls_accurate_away: str | None = Field(
        None, description="Accurate long balls for away (ratio or count)"
    )
    accurate_crosses_home: str | None = Field(
        None, description="Accurate crosses for home (ratio or count)"
    )
    accurate_crosses_away: str | None = Field(
        None, description="Accurate crosses for away (ratio or count)"
    )
    player_throws_home: int | None = Field(None, description="Throw-ins by home")
    player_throws_away: int | None = Field(None, description="Throw-ins by away")
    touches_opp_box_home: int | None = Field(None, description="Touches in opp box by home")
    touches_opp_box_away: int | None = Field(None, description="Touches in opp box by away")
    tackles_succeeded_home: str | None = Field(
        None, description="Successful tackles for home (ratio or count)"
    )
    tackles_succeeded_away: str | None = Field(
        None, description="Successful tackles for away (ratio or count)"
    )
    interceptions_home: int | None = Field(None, description="Interceptions by home")
    interceptions_away: int | None = Field(None, description="Interceptions by away")
    shot_blocks_home: int | None = Field(None, description="Shot blocks by home")
    shot_blocks_away: int | None = Field(None, description="Shot blocks by away")
    clearances_home: int | None = Field(None, description="Clearances by home")
    clearances_away: int | None = Field(None, description="Clearances by away")
    keeper_saves_home: int | None = Field(None, description="Keeper saves by home")
    keeper_saves_away: int | None = Field(None, description="Keeper saves by away")
    duels_won_home: int | None = Field(None, description="Duels won by home")
    duels_won_away: int | None = Field(None, description="Duels won by away")
    ground_duels_won_home: str | None = Field(
        None, description="Ground duels won by home (ratio or count)"
    )
    ground_duels_won_away: str | None = Field(
        None, description="Ground duels won by away (ratio or count)"
    )
    aerials_won_home: str | None = Field(None, description="Aerials won by home (ratio or count)")
    aerials_won_away: str | None = Field(None, description="Aerials won by away (ratio or count)")
    dribbles_succeeded_home: str | None = Field(
        None, description="Successful dribbles by home (ratio or count)"
    )
    dribbles_succeeded_away: str | None = Field(
        None, description="Successful dribbles by away (ratio or count)"
    )
    yellow_cards_home: int | None = Field(None, description="Yellow cards for home")
    yellow_cards_away: int | None = Field(None, description="Yellow cards for away")
    red_cards_home: int | None = Field(None, description="Red cards for home")
    red_cards_away: int | None = Field(None, description="Red cards for away")
    offsides_home: int | None = Field(None, description="Offsides by home")
    offsides_away: int | None = Field(None, description="Offsides by away")
    home_color: str | None = Field(None, description="Home team color for display")
    away_color: str | None = Field(None, description="Away team color for display")
