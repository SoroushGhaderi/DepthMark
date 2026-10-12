"""Event-related Pydantic models."""

from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict


class GoalEventHeader(BaseModel):
    """Represents a goal event as detailed in the match header."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True, populate_by_name=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    event_id: int = Field(..., description="Unique identifier for the goal event")
    goal_time: int = Field(..., description="Timestamp or minute of the goal")
    goal_overload_time: Optional[int] = Field(
        None, description="Stoppage time minute"
    )
    home_score: int = Field(
        ..., description="Score of the home team after the goal"
    )
    away_score: int = Field(
        ..., description="Score of the away team after the goal"
    )
    is_home: bool = Field(
        ..., description="True if the goal was scored by the home team"
    )
    is_own_goal: Optional[bool] = Field(
        False, description="True if the goal was an own goal"
    )
    goal_description: Optional[str] = Field(
        None, description="Text description of the goal type"
    )
    assist_player_id: Optional[int] = Field(
        None, description="ID of the player who assisted"
    )
    assist_player_name: Optional[str] = Field(
        None, description="Name of the assisting player"
    )
    player_id: Optional[int] = Field(
        None, description="Unique identifier for the scoring player"
    )
    player_name: Optional[str] = Field(
        None, description="Name of the scoring player"
    )
    shot_event_id: Optional[int] = Field(
        None, description="Unique identifier for the shotmap event"
    )
    shot_x_loc: Optional[float] = Field(
        None, description="X-coordinate of the shot location"
    )
    shot_y_loc: Optional[float] = Field(
        None, description="Y-coordinate of the shot location"
    )
    shot_minute: Optional[int] = Field(
        None, description="Minute of the match when the shot occurred", alias="shot_min"
    )
    shot_minute_added: Optional[int] = Field(
        None, description="Added/stoppage time minute for the shot", alias="shot_min_added"
    )
    shot_expected_goal: Optional[float] = Field(
        None, description="xG value of the shot"
    )
    shot_expected_goal_on_target: Optional[float] = Field(
        None, description="xGOT value"
    )
    shot_type: Optional[str] = Field(None, description="Type of shot")
    shot_situation: Optional[str] = Field(
        None, description="Game situation of the shot"
    )
    shot_period: Optional[str] = Field(
        None, description="Period of the match when the shot occurred"
    )
    shot_from_inside_box: Optional[bool] = Field(
        None, description="Whether shot originated inside penalty box", alias="shot_from_sidebox"
    )


class RedCardEvent(BaseModel):
    """Represents a red card event during a match."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the game")
    event_id: int = Field(
        ..., description="Unique identifier for the red card event"
    )
    red_card_time: int = Field(
        ..., description="Timestamp or minute of the red card"
    )
    red_card_overload_time: Optional[int] = Field(
        None, description="Stoppage time minute"
    )
    player_id: Optional[int] = Field(
        None, description="Unique identifier for the red card player"
    )
    player_name: Optional[str] = Field(
        None, description="Name of the red card player"
    )
    home_score: int = Field(
        ..., description="Score of the home team at the red card"
    )
    away_score: int = Field(
        ..., description="Score of the away team at the red card"
    )
    is_home: bool = Field(
        ..., description="True if the red card was given to home team"
    )


class GoalEventMatchFacts(BaseModel):
    """Represents a goal event from the match facts section."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    event_id: int = Field(..., description="Unique identifier for the goal event")
    time: int = Field(..., description="Minute when goal was scored")
    added_time: Optional[int] = Field(None, description="Stoppage time minute")
    player_id: Optional[int] = Field(
        None, description="Player ID of goal scorer"
    )
    player_name: Optional[str] = Field(
        None, description="Player name of goal scorer"
    )
    player_profile_url: Optional[str] = Field(
        None, description="Player profile URL"
    )
    team: str = Field(..., description="Home or Away team")
    score: str = Field(..., description="Score at time of goal")
    new_score: List[int] = Field(..., description="Updated score after goal")
    shot_type: Optional[str] = Field(None, description="Type of shot")
    xg: Optional[float] = Field(None, description="Expected goals value")
    xg_ot: Optional[float] = Field(
        None, description="Expected goals on target value"
    )
    situation: Optional[str] = Field(None, description="Game situation")
    assist_player: Optional[str] = Field(
        None, description="Name of assisting player"
    )
    assist_id: Optional[int] = Field(
        None, description="ID of assisting player"
    )
    shot_x: Optional[float] = Field(None, description="X coordinate of the shot")
    shot_y: Optional[float] = Field(None, description="Y coordinate of the shot")


class CardEventMatchFacts(BaseModel):
    """Represents a card event (yellow or red) from the match facts section."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    event_id: int = Field(
        ..., description="Unique identifier for the card event"
    )
    event_time: int = Field(..., description="Minute when card was given")
    added_time: Optional[int] = Field(None, description="Stoppage time minute")
    player_id: Optional[int] = Field(
        None, description="Player ID who received card"
    )
    player_name: Optional[str] = Field(
        None, description="Player name who received card"
    )
    player_profile_url: Optional[str] = Field(
        None, description="Player profile URL"
    )
    team: str = Field(..., description="Home or Away team")
    card_type: str = Field(..., description="Type of card (Yellow, Red)")
    description: Optional[str] = Field(None, description="Card description")
    score_at_event: str = Field(..., description="Score at time of card")


class SubstitutionEvent(BaseModel):
    """Represents a player substitution event during a match."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    time: int = Field(..., description="Minute when substitution occurred")
    added_time: Optional[int] = Field(None, description="Stoppage time minute")
    team: str = Field(..., description="Home or Away team")
    player__id: Optional[int] = Field(
        None, description="Player ID coming in"
    )
    player__name: Optional[str] = Field(
        None, description="Player name coming in"
    )
    player__profile_url: Optional[str] = Field(
        None, description="Player profile URL coming in"
    )
    player_out_id: Optional[int] = Field(
        None, description="Player ID going out"
    )
    player_out_name: Optional[str] = Field(
        None, description="Player name going out"
    )
    player_out_profile_url: Optional[str] = Field(
        None, description="Player profile URL going out"
    )
    injured: bool = Field(
        False, description="Whether substitution was due to injury"
    )
    score: str = Field(..., description="Score at time of substitution")


class AddedTimeEvent(BaseModel):
    """Represents an announcement of added time at the end of a half."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    time: int = Field(..., description="Minute when added time was announced")
    mutes_added: int = Field(..., description="Number of minutes added")
    description: Optional[str] = Field(
        None, description="Added time description"
    )
    score: str = Field(..., description="Score at time of announcement")


class HalfTimeEvent(BaseModel):
    """Represents a half-time or full-time event."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True)

    match_id: int = Field(..., description="Unique identifier for the match")
    time: int = Field(..., description="Minute when half occurred")
    half: str = Field(..., description="HT or FT")
    description: Optional[str] = Field(
        None, description="Half time description"
    )
    score: str = Field(..., description="Score at time of half")
