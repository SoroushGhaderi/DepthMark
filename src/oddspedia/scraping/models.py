"""Compatibility-preserving contracts for persisted Oddspedia JSON artifacts.

The models validate the source-owned shape at the persistence seam. Callers
must not serialize ``model_dump()`` as the artifact: validation is deliberately
separate from writing so defaults and coercions cannot rewrite source JSON.
"""

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter, field_validator

OddsValue = int | float
ScoreValue = int | float | str


class _SourceArtifactModel(BaseModel):
    """Keep provider fields that are not yet represented by the typed contract."""

    model_config = ConfigDict(extra="allow")


class OddsLine(_SourceArtifactModel):
    type: str
    label: str
    home: OddsValue | None = None
    draw: OddsValue | None = None
    away: OddsValue | None = None
    over: OddsValue | None = None
    under: OddsValue | None = None
    yes: OddsValue | None = None
    no: OddsValue | None = None
    odd: OddsValue | None = None
    even: OddsValue | None = None
    home_draw: OddsValue | None = None
    draw_away: OddsValue | None = None
    home_away: OddsValue | None = None
    no_goal: OddsValue | None = None
    combinations: dict[str, OddsValue] | None = None
    scores: dict[str, OddsValue] | None = None


class OddsMarket(_SourceArtifactModel):
    market: str
    lines: list[OddsLine]


class FootballScore(_SourceArtifactModel):
    home: ScoreValue
    away: ScoreValue
    winner: str = ""


class MatchResult(_SourceArtifactModel):
    """Current football payload plus optional legacy fields still readable by the repo."""

    sport: Literal["football"] = "football"
    id: str
    source_event_id: str | None = ""
    home: str
    away: str
    tournament: str
    round: str | None = ""
    date: str | None = ""
    url: str | None = ""
    home_rank: str | None = ""
    away_rank: str | None = ""
    category: str | None = ""
    status: str = ""
    odds_unavailable: bool = False
    odds_unavailable_reason: Literal["source_notice", "empty_attempts_exhausted"] | None = None
    odds_total_markets: int | None = None
    odds_extracted_markets: int | None = None
    odds_attempt: int | None = None
    odds_max_attempts: int | None = None
    odds_empty_attempts: int | None = None
    score: FootballScore | None = None
    stats_source: str | None = ""
    result_unavailable: bool = False
    winner: str | None = ""
    home_sets: str | None = ""
    away_sets: str | None = ""
    set_scores: list[dict] | str | None = None
    odds: list[OddsMarket]
    live_odds: list[OddsMarket] = Field(default_factory=list)
    stats: list[dict]
    point_by_point: list[dict] = Field(default_factory=list)
    overall_stats: dict[str, Any] = Field(default_factory=dict)
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
    league_name: str | None = ""
    league_slug: str | None = ""
    country: str | None = ""
    country_slug: str | None = ""
    date: str
    url: str
    full_url: str | None = None
    status: str | None = ""


_MATCH_LINK_LIST_ADAPTER = TypeAdapter(list[MatchLink])
_MATCH_RESULT_LIST_ADAPTER = TypeAdapter(list[MatchResult])


def validate_match_result(data: dict) -> MatchResult:
    """Validate match data against Pydantic schema."""
    return MatchResult(**data)


def validate_match_links(data: dict) -> MatchLink:
    """Validate one match link; retain the historical plural function name."""
    return MatchLink(**data)


def validate_match_link_list(data: list[dict]) -> list[MatchLink]:
    """Validate a complete listing, including an accepted empty inventory."""
    return _MATCH_LINK_LIST_ADAPTER.validate_python(data)


def validate_match_result_list(data: list[dict]) -> list[MatchResult]:
    """Validate a list of match payloads without changing the input objects."""
    return _MATCH_RESULT_LIST_ADAPTER.validate_python(data)
