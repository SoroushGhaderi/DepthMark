"""Venue and match information models."""

from pydantic import BaseModel, ConfigDict, Field


class MatchVenue(BaseModel):
    """
    Complete venue, stadium, and match information.

    Includes capacity, attendance, referee, and tournament details.
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    match_id: int = Field(..., description="Unique match identifier")

    stadium_name: str | None = Field(None, description="Full name of the stadium")
    stadium_city: str | None = Field(None, description="City where stadium is located")
    stadium_country: str | None = Field(None, description="Country where stadium is located")
    stadium_latitude: float | None = Field(None, description="GPS latitude coordinate")
    stadium_longitude: float | None = Field(None, description="GPS longitude coordinate")
    stadium_capacity: int | None = Field(None, description="Maximum stadium capacity")
    stadium_surface: str | None = Field(
        None, description="Playing surface type (e.g., grass, artificial)"
    )

    attendance: int | None = Field(None, description="Actual match attendance")
    referee_name: str | None = Field(None, description="Name of the match referee")
    referee_country: str | None = Field(None, description="Referee's country")
    referee_image_url: str | None = Field(None, description="URL to referee's image")

    match_date_utc: str | None = Field(None, description="Match date and time UTC")
    match_date_verified: bool | None = Field(None, description="Whether match date is confirmed")

    tournament_id: int | None = Field(None, description="Tournament/competition ID")
    tournament_name: str | None = Field(None, description="Name of the tournament")
    tournament_round: str | None = Field(None, description="Tournament round/matchday")
    tournament_parent_league_id: int | None = Field(None, description="Parent league ID")
    tournament_link: str | None = Field(None, description="Link to tournament page")
