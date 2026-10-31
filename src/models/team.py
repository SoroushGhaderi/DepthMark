"""Team-related Pydantic models."""

from pydantic import BaseModel, ConfigDict, Field


class TeamFormMatch(BaseModel):
    """
    Represents a single past match in a team's recent form.

    Flattened structure with team_side field for easy querying.
    """

    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    match_id: int = Field(..., description="Current match identifier")
    team_side: str = Field(..., description="Team side in current match: 'home' or 'away'")
    team_id: int = Field(..., description="ID of the team whose form this represents")
    team_name: str | None = Field(None, description="Name of the team")

    form_position: int = Field(..., description="Position in form sequence (1-5, 1 is most recent)")

    result: int = Field(..., description="Match result: 1 = Win, 0 = Draw, -1 = Loss")
    result_string: str = Field(..., description="Result as string: 'W', 'D', or 'L'")
    score: str | None = Field(None, description="Match score (e.g., '2-1')")

    form_match_date: str | None = Field(None, description="Date when this past match was played")
    form_match_id: str | None = Field(None, description="ID of this past match")
    form_match_link: str | None = Field(None, description="Link to this past match")

    opponent_id: int | None = Field(None, description="Opponent team ID in past match")
    opponent_name: str | None = Field(None, description="Opponent team name")
    opponent_image_url: str | None = Field(None, description="Opponent team logo URL")

    is_home_match: bool | None = Field(
        None, description="Was team playing at home in this past match"
    )
    home_team_id: int | None = Field(None, description="Home team ID in past match")
    home_team_name: str | None = Field(None, description="Home team name in past match")
    home_score: str | None = Field(None, description="Home team score in past match")
    away_team_id: int | None = Field(None, description="Away team ID in past match")
    away_team_name: str | None = Field(None, description="Away team name in past match")
    away_score: str | None = Field(None, description="Away team score in past match")


class TeamForm(BaseModel):
    """Represents the recent form (list of matches) for a specific team."""

    model_config = ConfigDict(extra="ignore")

    team_id: int | None = Field(None, description="ID of the team whose form is being described")
    matches: list[TeamFormMatch] = Field(..., description="List of recent matches")


class TeamFormResponse(BaseModel):
    """Contains the recent form data for both the home and away teams of a match."""

    model_config = ConfigDict(extra="ignore")

    team_forms: list[TeamForm] = Field(..., description="Form data for home and away teams")
