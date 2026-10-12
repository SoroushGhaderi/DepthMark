"""Shot-related Pydantic models."""

from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class ShotEvent(BaseModel):
    """Represents a single shot event in the match, including location and expected goals."""

    model_config = ConfigDict(extra='ignore', validate_assignment=True, populate_by_name=True)

    match_id: int = Field(..., description="Unique match identifier")
    shot_id: Optional[int] = Field(
        None, description="Unique identifier for the shot event"
    )
    event_type: Optional[str] = Field(None, description="Type of event ('Shot')")
    team_id: Optional[int] = Field(
        None, description="ID of the team that took the shot"
    )
    player_id: Optional[int] = Field(
        None, description="ID of the player who took the shot"
    )
    player_name: Optional[str] = Field(
        None, description="Name of the player who took the shot"
    )
    x: Optional[float] = Field(None, description="X-coordinate of the shot origin")
    y: Optional[float] = Field(None, description="Y-coordinate of the shot origin")
    minute: Optional[int] = Field(None, description="Match minute when the shot occurred")
    minute_added: Optional[int] = Field(None, description="Stoppage time minute")
    is_blocked: Optional[bool] = Field(
        None, description="True if the shot was blocked"
    )
    is_on_target: Optional[bool] = Field(
        None, description="True if the shot was on target"
    )
    blocked_x: Optional[float] = Field(
        None, description="X-coordinate where the shot was blocked"
    )
    blocked_y: Optional[float] = Field(
        None, description="Y-coordinate where the shot was blocked"
    )
    goal_crossed_y: Optional[float] = Field(
        None, description="Y-coordinate where shot crossed goal line"
    )
    goal_crossed_z: Optional[float] = Field(
        None, description="Z-coordinate (height) where shot crossed goal line"
    )
    expected_goals: Optional[float] = Field(
        None, description="Expected goals (xG) value of the shot"
    )
    expected_goals_on_target: Optional[float] = Field(
        None, description="Expected goals on target (xGOT) value"
    )
    shot_type: Optional[str] = Field(
        None, description="Type of shot (LeftFoot, RightFoot, Header)"
    )
    situation: Optional[str] = Field(
        None, description="Game situation (OpenPlay, FromCorner, SetPiece)"
    )
    period: Optional[str] = Field(
        None, description="Match period when the shot occurred"
    )
    is_own_goal: Optional[bool] = Field(
        None, description="True if the shot resulted in an own goal"
    )
    on_goal_shot_x: Optional[float] = Field(
        None, description="X-coordinate of the shot on goal face"
    )
    on_goal_shot_y: Optional[float] = Field(
        None, description="Y-coordinate of the shot on goal face"
    )
    on_goal_shot_zoom_ratio: Optional[float] = Field(
        None, description="Zoom ratio used for on-goal shot coordinates"
    )
    is_saved_off_line: Optional[bool] = Field(
        None, description="True if the shot was saved off the goal line"
    )
    is_from_inside_box: Optional[bool] = Field(
        None, description="True if shot originated from inside penalty box", alias="is_from_sidebox"
    )
    keeper_id: Optional[int] = Field(
        None, description="ID of the goalkeeper involved in the shot"
    )
    first_name: Optional[str] = Field(
        None, description="First name of the player who took the shot"
    )
    last_name: Optional[str] = Field(
        None, description="Last name of the player who took the shot"
    )
    full_name: Optional[str] = Field(
        None, description="Full name of the player who took the shot"
    )
    team_color: Optional[str] = Field(
        None, description="Color associated with the team"
    )
