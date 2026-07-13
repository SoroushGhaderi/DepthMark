"""Deterministic, auditable Oddspedia-to-FotMob fixture resolution."""

import json
import re
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import yaml

from src.integrations.clickhouse.client import ClickHouseClient
from src.common.logging import get_logger

logger = get_logger(__name__)


@dataclass(frozen=True)
class OddspediaEvent:
    oddspedia_match_id: str
    discovery_date: date
    kickoff_utc: Optional[datetime]
    home_team_name: str
    away_team_name: str
    league_name: str = ""


@dataclass(frozen=True)
class FotMobMatch:
    match_id: int
    match_date: date
    kickoff_utc: Optional[datetime]
    home_team_name: str
    away_team_name: str
    coverage_level: str = ""
    league_name: str = ""


@dataclass(frozen=True)
class TeamName:
    core: str
    qualifiers: Tuple[str, ...]
    alias_used: bool


@dataclass(frozen=True)
class Candidate:
    match: FotMobMatch
    score: float
    time_difference_minutes: Optional[int]
    home_rule: str
    away_rule: str


@dataclass(frozen=True)
class ResolutionResult:
    oddspedia_match_id: str
    discovery_date: date
    fotmob_match_id: Optional[int]
    resolution_status: str
    coverage_category: Optional[str]
    confidence: Optional[str]
    match_score: Optional[float]
    score_margin: Optional[float]
    time_difference_minutes: Optional[int]
    home_match_rule: Optional[str]
    away_match_rule: Optional[str]
    candidate_dates_checked: Tuple[date, ...]
    rule_version: str
    details: Dict[str, Any]

    def as_row(self) -> Dict[str, Any]:
        return {
            "oddspedia_match_id": self.oddspedia_match_id,
            "oddspedia_discovery_date": self.discovery_date,
            "fotmob_match_id": self.fotmob_match_id,
            "resolution_status": self.resolution_status,
            "coverage_category": self.coverage_category,
            "confidence": self.confidence,
            "match_score": self.match_score,
            "score_margin": self.score_margin,
            "time_difference_minutes": self.time_difference_minutes,
            "home_match_rule": self.home_match_rule,
            "away_match_rule": self.away_match_rule,
            "candidate_dates_checked": list(self.candidate_dates_checked),
            "resolution_rule_version": self.rule_version,
            "resolution_details_json": json.dumps(self.details, sort_keys=True),
        }


class FotMobCandidateIndex:
    """Precomputed team index that keeps month-scale resolution bounded."""

    def __init__(self, resolver: "OddspediaMatchResolver", matches: Iterable[FotMobMatch]):
        self.resolver = resolver
        self.exact: Dict[Tuple[str, Tuple[str, ...], str, Tuple[str, ...]], List[FotMobMatch]] = {}
        self.home_tokens: Dict[str, set] = {}
        self.away_tokens: Dict[str, set] = {}
        for match in matches:
            home = resolver._normalize_team(match.home_team_name)
            away = resolver._normalize_team(match.away_team_name)
            self.exact.setdefault(
                (home.core, home.qualifiers, away.core, away.qualifiers), []
            ).append(match)
            for token in home.core.split():
                self.home_tokens.setdefault(token, set()).add(match)
            for token in away.core.split():
                self.away_tokens.setdefault(token, set()).add(match)

    def candidates_for(self, event: OddspediaEvent) -> Iterable[FotMobMatch]:
        home = self.resolver._normalize_team(event.home_team_name)
        away = self.resolver._normalize_team(event.away_team_name)
        exact = self.exact.get((home.core, home.qualifiers, away.core, away.qualifiers))
        if exact:
            return exact
        home_candidates = set()
        away_candidates = set()
        for token in home.core.split():
            home_candidates.update(self.home_tokens.get(token, set()))
        for token in away.core.split():
            away_candidates.update(self.away_tokens.get(token, set()))
        return home_candidates.intersection(away_candidates)


class OddspediaMatchResolver:
    """Resolve an Oddspedia Source Event to at most one FotMob reference row."""

    def __init__(self, policy_path: Path, aliases_path: Path):
        policy = _load_yaml(policy_path)
        aliases = _load_yaml(aliases_path).get("aliases", {})
        self.rule_version = str(policy.get("rule_version", "v1"))
        self.candidate_window_days = int(policy.get("candidate_window_days", 1))
        self.exact_time_minutes = int(policy.get("exact_time_minutes", 15))
        self.alias_time_minutes = int(policy.get("alias_time_minutes", 60))
        self.maximum_time_minutes = int(policy.get("maximum_time_minutes", 720))
        self.automatic_match_score = float(policy.get("automatic_match_score", 95))
        self.automatic_match_margin = float(policy.get("automatic_match_margin", 8))
        self.team_similarity_minimum = float(policy.get("team_similarity_minimum", 0.88))
        self.qualifier_tokens = frozenset(policy.get("qualifier_tokens", []))
        self.generic_tokens = frozenset(policy.get("generic_tokens", []))
        self.aliases = {
            _simple_text(key): _simple_text(value)
            for key, value in aliases.items()
            if key and value
        }

    def candidate_dates(self, discovery_date: date) -> Tuple[date, ...]:
        return tuple(
            discovery_date + timedelta(days=offset)
            for offset in range(-self.candidate_window_days, self.candidate_window_days + 1)
        )

    def candidate_index(self, matches: Iterable[FotMobMatch]) -> FotMobCandidateIndex:
        """Build one reusable candidate index for a date-scoped resolution batch."""
        return FotMobCandidateIndex(self, matches)

    def resolve(
        self,
        event: OddspediaEvent,
        fotmob_matches: Iterable[FotMobMatch],
        reference_window_complete: bool = False,
    ) -> ResolutionResult:
        candidate_dates = self.candidate_dates(event.discovery_date)
        candidates = []
        for match in fotmob_matches:
            if match.match_date not in candidate_dates:
                continue
            candidate = self._score_candidate(event, match)
            if candidate is not None:
                candidates.append(candidate)
        candidates.sort(key=lambda item: (-item.score, item.match.match_id))

        if not candidates:
            status = "unmatched" if reference_window_complete else "unresolved"
            category = "not_covered" if status == "unmatched" else None
            return self._result(
                event,
                candidate_dates,
                status=status,
                category=category,
                details={
                    "candidate_count": 0,
                    "reference_window_complete": reference_window_complete,
                },
            )

        best = candidates[0]
        margin = best.score - candidates[1].score if len(candidates) > 1 else best.score
        automatic = (
            best.score >= self.automatic_match_score and margin >= self.automatic_match_margin
        )
        if automatic:
            confidence = "exact" if best.home_rule == best.away_rule == "exact" else "alias"
            return self._result(
                event,
                candidate_dates,
                status="matched",
                category=_coverage_category(best.match.coverage_level),
                confidence=confidence,
                candidate=best,
                margin=margin,
                details={
                    "candidate_count": len(candidates),
                    "reference_window_complete": reference_window_complete,
                },
            )

        return self._result(
            event,
            candidate_dates,
            status="ambiguous",
            candidate=best,
            margin=margin,
            details={
                "candidate_count": len(candidates),
                "reference_window_complete": reference_window_complete,
                "top_candidate_ids": [item.match.match_id for item in candidates[:3]],
            },
        )

    def _score_candidate(self, event: OddspediaEvent, match: FotMobMatch) -> Optional[Candidate]:
        home_similarity, home_rule = self._team_similarity(
            event.home_team_name, match.home_team_name
        )
        away_similarity, away_rule = self._team_similarity(
            event.away_team_name, match.away_team_name
        )
        if (
            home_similarity < self.team_similarity_minimum
            or away_similarity < self.team_similarity_minimum
        ):
            return None
        time_difference = _minutes_between(event.kickoff_utc, match.kickoff_utc)
        if time_difference is not None and time_difference > self.maximum_time_minutes:
            return None
        score = (45 * home_similarity) + (45 * away_similarity) + self._time_points(time_difference)
        if (
            event.league_name
            and match.league_name
            and _simple_text(event.league_name) == _simple_text(match.league_name)
        ):
            score += 5
        return Candidate(
            match=match,
            score=round(score, 2),
            time_difference_minutes=time_difference,
            home_rule=home_rule,
            away_rule=away_rule,
        )

    def _team_similarity(self, source_name: str, reference_name: str) -> Tuple[float, str]:
        source = self._normalize_team(source_name)
        reference = self._normalize_team(reference_name)
        if not source.core or not reference.core or source.qualifiers != reference.qualifiers:
            return 0.0, "qualifier_mismatch"
        if source.core == reference.core:
            return 1.0, "alias" if source.alias_used or reference.alias_used else "exact"
        return SequenceMatcher(None, source.core, reference.core).ratio(), "fuzzy"

    def _normalize_team(self, value: str) -> TeamName:
        text = _simple_text(value)
        alias_used = text in self.aliases
        text = self.aliases.get(text, text)
        tokens = text.split()
        qualifiers = tuple(sorted(token for token in tokens if token in self.qualifier_tokens))
        core = " ".join(
            token
            for token in tokens
            if token not in self.qualifier_tokens and token not in self.generic_tokens
        )
        return TeamName(core=core, qualifiers=qualifiers, alias_used=alias_used)

    def _time_points(self, difference_minutes: Optional[int]) -> float:
        if difference_minutes is None:
            return 0.0
        if difference_minutes <= self.exact_time_minutes:
            return 10.0
        if difference_minutes <= self.alias_time_minutes:
            return 8.0
        if difference_minutes <= 180:
            return 4.0
        return 1.0

    def _result(
        self,
        event: OddspediaEvent,
        candidate_dates: Tuple[date, ...],
        status: str,
        category: Optional[str] = None,
        confidence: Optional[str] = None,
        candidate: Optional[Candidate] = None,
        margin: Optional[float] = None,
        details: Optional[Dict[str, Any]] = None,
    ) -> ResolutionResult:
        return ResolutionResult(
            oddspedia_match_id=event.oddspedia_match_id,
            discovery_date=event.discovery_date,
            fotmob_match_id=candidate.match.match_id if candidate else None,
            resolution_status=status,
            coverage_category=category,
            confidence=confidence,
            match_score=candidate.score if candidate else None,
            score_margin=round(margin, 2) if margin is not None else None,
            time_difference_minutes=candidate.time_difference_minutes if candidate else None,
            home_match_rule=candidate.home_rule if candidate else None,
            away_match_rule=candidate.away_rule if candidate else None,
            candidate_dates_checked=candidate_dates,
            rule_version=self.rule_version,
            details=details or {},
        )


class OddspediaResolutionService:
    """Read source/reference rows and persist date-scoped resolution results."""

    def __init__(self, client: ClickHouseClient, resolver: OddspediaMatchResolver):
        self.client = client
        self.resolver = resolver

    def resolve_date(
        self,
        discovery_date: date,
        reference_window_complete: bool,
        persist: bool = True,
    ) -> List[ResolutionResult]:
        events = self._load_events(discovery_date)
        matches = self._load_fotmob_matches(self.resolver.candidate_dates(discovery_date))
        index = self.resolver.candidate_index(matches)
        results = [
            self.resolver.resolve(
                event,
                index.candidates_for(event),
                reference_window_complete=reference_window_complete,
            )
            for event in events
        ]
        if persist:
            self._persist(results)
        return results

    def _load_events(self, discovery_date: date) -> List[OddspediaEvent]:
        query = """
            SELECT oddspedia_match_id, discovery_date, scheduled_kickoff_utc,
                   home_team_name, away_team_name, league_name
            FROM oddspedia_bronze.event FINAL
            WHERE discovery_date = {date:Date}
        """
        rows = self.client.execute(
            query, parameters={"date": discovery_date.isoformat()}
        ).result_rows
        return [
            OddspediaEvent(
                oddspedia_match_id=str(row[0]),
                discovery_date=row[1],
                kickoff_utc=row[2],
                home_team_name=row[3] or "",
                away_team_name=row[4] or "",
                league_name=row[5] or "",
            )
            for row in rows
        ]

    def _load_fotmob_matches(self, dates: Tuple[date, ...]) -> List[FotMobMatch]:
        start, end = min(dates).isoformat(), max(dates).isoformat()
        query = """
            SELECT match_id, match_date, match_time_utc, home_team_name,
                   away_team_name, coverage_level, league_name
            FROM silver.match FINAL
            WHERE match_date BETWEEN {start:Date} AND {end:Date}
        """
        rows = self.client.execute(query, parameters={"start": start, "end": end}).result_rows
        return [
            FotMobMatch(
                match_id=int(row[0]),
                match_date=row[1],
                kickoff_utc=row[2],
                home_team_name=row[3] or "",
                away_team_name=row[4] or "",
                coverage_level=row[5] or "",
                league_name=row[6] or "",
            )
            for row in rows
        ]

    def _persist(self, results: List[ResolutionResult]) -> None:
        if not results:
            return
        import pandas as pd

        self.client.insert_dataframe(
            "oddspedia_match_resolution",
            pd.DataFrame([result.as_row() for result in results]),
            database="silver",
        )


def _load_yaml(path: Path) -> Dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        return yaml.safe_load(source) or {}


def _simple_text(value: str) -> str:
    value = str(value or "").replace("ß", "ss")
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", normalized.casefold())).strip()


def _minutes_between(first: Optional[datetime], second: Optional[datetime]) -> Optional[int]:
    if first is None or second is None:
        return None
    if first.tzinfo is not None:
        first = first.replace(tzinfo=None)
    if second.tzinfo is not None:
        second = second.replace(tzinfo=None)
    return int(abs((first - second).total_seconds()) // 60)


def _coverage_category(value: str) -> Optional[str]:
    normalized = _simple_text(value)
    return {"xg": "xG", "ratings": "ratings", "lower": "lower"}.get(normalized)
