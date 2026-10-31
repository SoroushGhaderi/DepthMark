"""Player-related Pydantic models."""

from pydantic import BaseModel, ConfigDict, Field


class FlatPlayerStats(BaseModel):
    """Represents comprehensive statistics for an individual player in a match."""

    model_config = ConfigDict(extra="ignore", validate_assignment=True, populate_by_name=True)

    match_id: int = Field(..., description="Unique match identifier")
    player_id: int | None = Field(None, alias="id", description="Unique identifier for the player")
    player_name: str | None = Field(None, alias="name", description="Name of the player")
    opta_id: str | None = Field(None, description="Opta ID for the player")
    team_id: int | None = Field(None, description="ID of the team the player belongs to")
    team_name: str | None = Field(None, description="Name of the team the player belongs to")
    is_goalkeeper: bool | None = Field(None, description="True if the player is a goalkeeper")
    fotmob_rating: float | None = Field(None, description="FotMob's performance rating")
    minutes_played: int | None = Field(None, description="Total minutes played by the player")
    goals: int | None = Field(None, description="Goals scored by the player")
    assists: int | None = Field(None, description="Assists provided by the player")
    total_shots: int | None = Field(None, description="Total shots attempted by the player")
    shots_on_target: int | None = Field(None, description="Shots on target by the player")
    shots_off_target: int | None = Field(None, description="Shots off target by the player")
    blocked_shots: int | None = Field(None, description="Blocked shots by the player")
    expected_goals: float | None = Field(None, description="Expected goals (xG)")
    expected_assists: float | None = Field(None, description="Expected assists (xA)")
    xg_plus_xa: float | None = Field(None, description="Expected goals plus expected assists")
    xg_non_penalty: float | None = Field(None, description="Expected goals excluding penalties")
    chances_created: int | None = Field(None, description="Chances created by the player")
    touches: int | None = Field(None, description="Total touches of the ball")
    touches_opp_box: int | None = Field(None, description="Touches in the opposition's penalty box")
    successful_dribbles: int | None = Field(None, description="Successful dribbles completed")
    dribble_attempts: int | None = Field(None, description="Total dribble attempts")
    dribble_success_rate: float | None = Field(None, description="Success rate of dribbles")
    accurate_passes: int | None = Field(None, description="Accurate passes completed")
    total_passes: int | None = Field(None, description="Total passes attempted")
    pass_accuracy: float | None = Field(None, description="Accuracy percentage of passes")
    passes_final_third: int | None = Field(None, description="Passes completed to the final third")
    accurate_crosses: int | None = Field(None, description="Accurate crosses completed")
    cross_attempts: int | None = Field(None, description="Total cross attempts")
    cross_success_rate: float | None = Field(None, description="Success rate of crosses")
    accurate_long_balls: int | None = Field(None, description="Accurate long balls completed")
    long_ball_attempts: int | None = Field(None, description="Total long ball attempts")
    long_ball_success_rate: float | None = Field(None, description="Success rate of long balls")
    tackles_won: int | None = Field(None, description="Successful tackles made")
    tackle_attempts: int | None = Field(None, description="Total tackle attempts")
    tackle_success_rate: float | None = Field(None, description="Success rate of tackles")
    interceptions: int | None = Field(None, description="Interceptions made")
    clearances: int | None = Field(None, description="Clearances made")
    defensive_actions: int | None = Field(None, description="Total defensive actions")
    recoveries: int | None = Field(None, description="Ball recoveries made")
    dribbled_past: int | None = Field(None, description="Number of times dribbled past")
    duels_won: int | None = Field(None, description="Total duels won")
    duels_lost: int | None = Field(None, description="Total duels lost")
    ground_duels_won: int | None = Field(None, description="Ground duels won")
    ground_duel_attempts: int | None = Field(None, description="Total ground duel attempts")
    ground_duel_success_rate: float | None = Field(None, description="Success rate of ground duels")
    aerial_duels_won: int | None = Field(None, description="Aerial duels won")
    aerial_duel_attempts: int | None = Field(None, description="Total aerial duel attempts")
    aerial_duel_success_rate: float | None = Field(None, description="Success rate of aerial duels")
    fouls_committed: int | None = Field(None, description="Fouls committed by the player")
    was_fouled: int | None = Field(None, description="Number of times the player was fouled")
    shotmap_count: int | None = Field(None, description="Number of shots recorded in shotmap")
    average_xg_per_shot: float | None = Field(None, description="Average xG per shot")
    total_xg: float | None = Field(None, description="Total xG from all shots")
    fun_facts: list[str] | None = Field(None, description="List of notable facts")


class LineupPlayer(BaseModel):
    """Represents a starting player in a team's lineup."""

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    match_id: int = Field(..., description="Unique match identifier")
    team_side: str = Field(..., description="Team side: 'home' or 'away'")
    player_id: int = Field(..., description="Unique identifier for the player")
    age: int | None = Field(None, description="Age of the player")
    name: str | None = Field(None, description="Name of the player")
    first_name: str | None = Field(None, description="First name of the player")
    last_name: str | None = Field(None, description="Last name of the player")
    position_id: int | None = Field(None, description="Position ID of the player in this match")
    usual_playing_position_id: int | None = Field(None, description="Usual playing position ID")
    shirt_number: str | None = Field(None, description="Shirt number worn by the player")
    is_captain: bool | None = Field(False, description="True if the player is the team captain")
    country_name: str | None = Field(None, description="Country of origin of the player")
    country_code: str | None = Field(None, description="Country code of origin")
    horizontal_x: float | None = Field(None, description="X-coordinate for horizontal lineup")
    horizontal_y: float | None = Field(None, description="Y-coordinate for horizontal lineup")
    horizontal_height: float | None = Field(
        None, description="Height for horizontal lineup element"
    )
    horizontal_width: float | None = Field(None, description="Width for horizontal lineup element")
    vertical_x: float | None = Field(None, description="X-coordinate for vertical lineup")
    vertical_y: float | None = Field(None, description="Y-coordinate for vertical lineup")
    vertical_height: float | None = Field(None, description="Height for vertical lineup element")
    vertical_width: float | None = Field(None, description="Width for vertical lineup element")
    performance_rating: float | None = Field(None, description="Performance rating for this match")
    substitution_time: int | None = Field(
        None, description="Minute at which player was substituted off"
    )
    substitution_type: str | None = Field(None, description="Type of substitution")
    substitution_reason: str | None = Field(None, description="Reason for substitution")


class SubstitutePlayer(BaseModel):
    """Represents a substitute player in a team's lineup."""

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    match_id: int = Field(..., description="Unique match identifier")
    team_side: str = Field(..., description="Team side: 'home' or 'away'")
    player_id: int = Field(..., description="Unique identifier for the player")
    age: int | None = Field(None, description="Age of the player")
    name: str | None = Field(None, description="Name of the player")
    first_name: str | None = Field(None, description="First name of the player")
    last_name: str | None = Field(None, description="Last name of the player")
    usual_playing_position_id: int | None = Field(None, description="Usual playing position ID")
    shirt_number: str | None = Field(None, description="Shirt number worn by the player")
    country_name: str | None = Field(None, description="Country of origin of the player")
    country_code: str | None = Field(None, description="Country code of origin")
    performance_rating: float | None = Field(None, description="Performance rating if they played")
    substitution_time: int | None = Field(None, description="Minute substituted in")
    substitution_type: str | None = Field(None, description="Type of substitution")
    substitution_reason: str | None = Field(None, description="Reason for substitution")


class TeamCoach(BaseModel):
    """Represents the coach for a team in a match."""

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    match_id: int = Field(..., description="Unique match identifier")
    team_side: str = Field(..., description="Team side: 'home' or 'away'")
    coach_id: int = Field(..., description="Unique identifier for the coach")
    age: int | None = Field(None, description="Age of the coach")
    name: str | None = Field(None, description="Name of the coach")
    first_name: str | None = Field(None, description="First name of the coach")
    last_name: str | None = Field(None, description="Last name of the coach")
    country_name: str | None = Field(None, description="Country of origin of the coach")
    country_code: str | None = Field(None, description="Country code of origin")
    primary_team_id: int | None = Field(None, description="ID of the primary team")
    primary_team_name: str | None = Field(None, description="Name of the primary team")
    is_coach: bool | None = Field(True, description="Flag indicating this is a coach")
