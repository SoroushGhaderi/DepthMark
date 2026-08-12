"""Compatibility-preserving contracts for persisted Oddspedia JSON artifacts.

The models validate the source-owned shape at the persistence seam. Callers
must not serialize ``model_dump()`` as the artifact: validation is deliberately
separate from writing so defaults and coercions cannot rewrite source JSON.
"""

from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter, field_validator

OddsValue = Union[int, float]
ScoreValue = Union[int, float, str]


class _SourceArtifactModel(BaseModel):
    """Keep provider fields that are not yet represented by the typed contract."""

    model_config = ConfigDict(extra="allow")


class OddsLine(_SourceArtifactModel):
    type: str
    label: str
    home: Optional[OddsValue] = None
    draw: Optional[OddsValue] = None
    away: Optional[OddsValue] = None
    over: Optional[OddsValue] = None
    under: Optional[OddsValue] = None
    yes: Optional[OddsValue] = None
    no: Optional[OddsValue] = None
    odd: Optional[OddsValue] = None
    even: Optional[OddsValue] = None
    home_draw: Optional[OddsValue] = None
    draw_away: Optional[OddsValue] = None
    home_away: Optional[OddsValue] = None
    no_goal: Optional[OddsValue] = None
    combinations: Optional[Dict[str, OddsValue]] = None
    scores: Optional[Dict[str, OddsValue]] = None


class OddsMarket(_SourceArtifactModel):
    market: str
    lines: List[OddsLine]


class FootballScore(_SourceArtifactModel):
    home: ScoreValue
    away: ScoreValue
    winner: str = ""


class MatchResult(_SourceArtifactModel):
    """Current football payload plus optional legacy fields still readable by the repo."""

    sport: Literal["football"] = "football"
    id: str
    source_event_id: Optional[str] = ""
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
    odds_unavailable: bool = False
    odds_total_markets: Optional[int] = None
    odds_extracted_markets: Optional[int] = None
    odds_attempt: Optional[int] = None
    odds_max_attempts: Optional[int] = None
    odds_empty_attempts: Optional[int] = None
    score: Optional[FootballScore] = None
    stats_source: Optional[str] = ""
    result_unavailable: bool = False
    winner: Optional[str] = ""
    home_sets: Optional[str] = ""
    away_sets: Optional[str] = ""
    set_scores: Optional[Union[List[dict], str]] = None
    odds: List[OddsMarket]
    live_odds: List[OddsMarket] = Field(default_factory=list)
    stats: List[dict]
    point_by_point: List[dict] = Field(default_factory=list)
    overall_stats: Dict[str, Any] = Field(default_factory=dict)
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


class MatchLink(_SourceArtifactModel):
    sport: Literal["football"] = "football"
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


_MATCH_LINK_LIST_ADAPTER = TypeAdapter(List[MatchLink])
_MATCH_RESULT_LIST_ADAPTER = TypeAdapter(List[MatchResult])


def validate_match_result(data: dict) -> MatchResult:
    """Validate match data against Pydantic schema."""
    return MatchResult(**data)


def validate_match_links(data: dict) -> MatchLink:
    """Validate one match link; retain the historical plural function name."""
    return MatchLink(**data)


def validate_match_link_list(data: List[dict]) -> List[MatchLink]:
    """Validate a complete listing, including an accepted empty inventory."""
    return _MATCH_LINK_LIST_ADAPTER.validate_python(data)


def validate_match_result_list(data: List[dict]) -> List[MatchResult]:
    """Validate a list of match payloads without changing the input objects."""
    return _MATCH_RESULT_LIST_ADAPTER.validate_python(data)
