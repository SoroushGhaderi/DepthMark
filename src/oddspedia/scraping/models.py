from pydantic import BaseModel, field_validator, ConfigDict
from typing import Optional, List, Union, Any, Dict


class OddsLine(BaseModel):
    model_config = ConfigDict(extra="allow")

    type: str
    label: str
    home: Optional[float] = None
    draw: Optional[float] = None
    away: Optional[float] = None
    over: Optional[float] = None
    under: Optional[float] = None


class OddsMarket(BaseModel):
    model_config = ConfigDict(extra="allow")

    market: str
    lines: List[OddsLine]


class MatchResult(BaseModel):
    model_config = ConfigDict(extra="allow")

    sport: Optional[str] = "football"
    id: str
    home: str
    away: str
    tournament: str
    round: Optional[str] = ""
    date: Optional[str] = ""
    url: Optional[str] = ""
    home_rank: Optional[str] = ""
    away_rank: Optional[str] = ""
    category: Optional[str] = ""
    status: str = ""
    winner: Optional[str] = ""
    home_sets: Optional[str] = ""
    away_sets: Optional[str] = ""
    set_scores: Optional[Union[List[dict], str]] = None
    odds: List[OddsMarket] = []
    live_odds: List[OddsMarket] = []
    stats: List[dict] = []
    point_by_point: List[dict] = []
    overall_stats: Dict[str, Any] = {}
    scraped_at: str

    @field_validator("winner", "home_sets", "away_sets", mode="before")
    @classmethod
    def coerce_to_str(cls, v: Any) -> str:
        if v is None:
            return ""
        return str(v)

    @field_validator("odds", "live_odds", mode="before")
    @classmethod
    def ensure_list(cls, v):
        if v is None:
            return []
        return v


class MatchLink(BaseModel):
    model_config = ConfigDict(extra="allow")

    sport: Optional[str] = "football"
    id: str
    home: str
    away: str
    league_name: Optional[str] = ""
    league_slug: Optional[str] = ""
    country: Optional[str] = ""
    country_slug: Optional[str] = ""
    date: str
    url: str
    full_url: Optional[str] = None
    status: Optional[str] = ""


def validate_match_result(data: dict) -> MatchResult:
    """Validate match data against Pydantic schema."""
    return MatchResult(**data)


def validate_match_links(data: dict) -> MatchLink:
    """Validate match link data against Pydantic schema."""
    return MatchLink(**data)
