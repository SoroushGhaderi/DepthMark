"""Deterministic, auditable Oddspedia-to-FotMob fixture resolution."""

import json
import re
import unicodedata
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Tuple

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
        self.home_ngrams: Dict[str, set] = {}
        self.away_ngrams: Dict[str, set] = {}
        self.home_token_frequencies: Counter = Counter()
        self.away_token_frequencies: Counter = Counter()
        for match in matches:
            home = resolver._normalize_team(match.home_team_name)
            away = resolver._normalize_team(match.away_team_name)
            self.exact.setdefault(
                (home.core, home.qualifiers, away.core, away.qualifiers), []
            ).append(match)
            for token in set(home.core.split()):
                self.home_tokens.setdefault(token, set()).add(match)
                self.home_token_frequencies[token] += 1
            for token in set(away.core.split()):
                self.away_tokens.setdefault(token, set()).add(match)
                self.away_token_frequencies[token] += 1
            for ngram in _team_ngrams(home.core):
                self.home_ngrams.setdefault(ngram, set()).add(match)
            for ngram in _team_ngrams(away.core):
                self.away_ngrams.setdefault(ngram, set()).add(match)

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
        token_candidates = home_candidates.intersection(away_candidates)
        return token_candidates.union(
            _ngram_candidates(home.core, self.home_ngrams).intersection(
                _ngram_candidates(away.core, self.away_ngrams)
            )
        )


class OddspediaMatchResolver:
    """Resolve an Oddspedia Source Event to at most one FotMob reference row."""

    def __init__(self, policy_path: Path, aliases_path: Path):
        policy = _load_yaml(policy_path)
        aliases = _load_yaml(aliases_path).get("aliases", {})
        self.rule_version = str(policy.get("rule_version", "v1"))
        self.candidate_window_days = int(policy.get("candidate_window_days", 1))
        self.team_name_match_score = float(policy.get("team_name_match_score", 90))
        self.automatic_match_margin = float(policy.get("automatic_match_margin", 8))
        self.team_similarity_minimum = float(policy.get("team_similarity_minimum", 0.88))
        self.approximate_token_min_length = int(policy.get("approximate_token_min_length", 7))
        self.approximate_token_containment_score = float(
            policy.get("approximate_token_containment_score", 0.92)
        )
        self.unique_token_min_length = int(policy.get("unique_token_min_length", 7))
        self.unique_token_similarity_score = float(
            policy.get("unique_token_similarity_score", 0.92)
        )
        self.qualifier_tokens = frozenset(policy.get("qualifier_tokens", []))
        self.generic_tokens = frozenset(policy.get("generic_tokens", []))
        self.club_designator_tokens = frozenset(policy.get("club_designator_tokens", []))
        self.qualifier_aliases = {
            _simple_text(key): _simple_text(value)
            for key, value in (policy.get("qualifier_aliases") or {}).items()
            if key and value
        }
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

    def resolve_from_index(
        self,
        event: OddspediaEvent,
        index: FotMobCandidateIndex,
        reference_window_complete: bool = False,
    ) -> ResolutionResult:
        """Resolve from an index while retaining its date-window token frequencies."""
        return self.resolve(
            event,
            index.candidates_for(event),
            reference_window_complete=reference_window_complete,
            home_token_frequencies=index.home_token_frequencies,
            away_token_frequencies=index.away_token_frequencies,
        )

    def resolve(
        self,
        event: OddspediaEvent,
        fotmob_matches: Iterable[FotMobMatch],
        reference_window_complete: bool = False,
        home_token_frequencies: Optional[Mapping[str, int]] = None,
        away_token_frequencies: Optional[Mapping[str, int]] = None,
    ) -> ResolutionResult:
        candidate_dates = self.candidate_dates(event.discovery_date)
        candidates = []
        for match in fotmob_matches:
            if match.match_date not in candidate_dates:
                continue
            candidate = self._score_candidate(
                event,
                match,
                home_token_frequencies=home_token_frequencies,
                away_token_frequencies=away_token_frequencies,
            )
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
        if best.score >= self.team_name_match_score and margin >= self.automatic_match_margin:
            confidence = "exact" if best.home_rule == best.away_rule == "exact" else "alias"
            if confidence == "alias" and any(
                rule.startswith("fuzzy") for rule in (best.home_rule, best.away_rule)
            ):
                confidence = "high_similarity"
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

    def _score_candidate(
        self,
        event: OddspediaEvent,
        match: FotMobMatch,
        home_token_frequencies: Optional[Mapping[str, int]] = None,
        away_token_frequencies: Optional[Mapping[str, int]] = None,
    ) -> Optional[Candidate]:
        home_similarity, home_rule = self._team_similarity(
            event.home_team_name, match.home_team_name, home_token_frequencies
        )
        away_similarity, away_rule = self._team_similarity(
            event.away_team_name, match.away_team_name, away_token_frequencies
        )
        if (
            home_similarity < self.team_similarity_minimum
            or away_similarity < self.team_similarity_minimum
        ):
            return None
        if not _unique_token_rescue_has_anchor(home_rule, away_rule):
            return None
        return Candidate(
            match=match,
            score=round(50 * home_similarity + 50 * away_similarity, 2),
            time_difference_minutes=None,
            home_rule=home_rule,
            away_rule=away_rule,
        )

    def _team_similarity(
        self,
        source_name: str,
        reference_name: str,
        token_frequencies: Optional[Mapping[str, int]] = None,
    ) -> Tuple[float, str]:
        source = self._normalize_team(source_name)
        reference = self._normalize_team(reference_name)
        if not source.core or not reference.core or source.qualifiers != reference.qualifiers:
            return 0.0, "qualifier_mismatch"
        if source.core == reference.core:
            return 1.0, "alias" if source.alias_used or reference.alias_used else "exact"
        character_similarity = SequenceMatcher(None, source.core, reference.core).ratio()
        source_tokens = tuple(source.core.split())
        reference_tokens = tuple(reference.core.split())
        if sorted(source_tokens) == sorted(reference_tokens):
            return 1.0, "fuzzy_token_reordered"
        if _has_distinctive_token_containment(
            source_tokens, reference_tokens, self.approximate_token_min_length
        ):
            return self.approximate_token_containment_score, "fuzzy_token_containment"
        if character_similarity < self.team_similarity_minimum and _has_unique_shared_token(
            source_tokens,
            reference_tokens,
            token_frequencies,
            self.unique_token_min_length,
        ):
            return self.unique_token_similarity_score, "fuzzy_unique_token"
        return character_similarity, "fuzzy_character"

    def _normalize_team(self, value: str) -> TeamName:
        text = _simple_text(value)
        alias_used = text in self.aliases
        text = self.aliases.get(text, text)
        tokens = [self.qualifier_aliases.get(token, token) for token in text.split()]
        qualifiers = tuple(sorted(token for token in tokens if token in self.qualifier_tokens))
        core = " ".join(
            token
            for token in tokens
            if token not in self.qualifier_tokens
            and token not in self.generic_tokens
            and token not in self.club_designator_tokens
        )
        return TeamName(core=core, qualifiers=qualifiers, alias_used=alias_used)

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
            self.resolver.resolve_from_index(
                event, index, reference_window_complete=reference_window_complete
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
    value = str(value or "").translate(
        str.maketrans(
            {
                "ß": "ss",
                "æ": "ae",
                "Æ": "AE",
                "œ": "oe",
                "Œ": "OE",
                "ø": "o",
                "Ø": "O",
                "ð": "d",
                "Ð": "D",
                "þ": "th",
                "Þ": "TH",
                "ł": "l",
                "Ł": "L",
                "ı": "i",
                "İ": "I",
            }
        )
    )
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", normalized.casefold())).strip()


def _coverage_category(value: str) -> Optional[str]:
    normalized = _simple_text(value)
    return {"xg": "xG", "ratings": "ratings", "lower": "lower"}.get(normalized)


def _team_ngrams(value: str) -> Tuple[str, ...]:
    """Return distinctive character n-grams for controlled spelling fallbacks."""
    compact = value.replace(" ", "")
    if len(compact) < 3:
        return ()
    return tuple({compact[index : index + 3] for index in range(len(compact) - 2)})


def _has_distinctive_token_containment(
    source_tokens: Tuple[str, ...], reference_tokens: Tuple[str, ...], minimum_length: int
) -> bool:
    """Recognize a provider abbreviation only when its remaining token is distinctive."""
    source_set = set(source_tokens)
    reference_set = set(reference_tokens)
    if source_set == reference_set or not source_set or not reference_set:
        return False
    shorter, longer = (
        (source_set, reference_set)
        if len(source_set) < len(reference_set)
        else (reference_set, source_set)
    )
    return shorter.issubset(longer) and all(len(token) >= minimum_length for token in shorter)


def _has_unique_shared_token(
    source_tokens: Tuple[str, ...],
    reference_tokens: Tuple[str, ...],
    token_frequencies: Optional[Mapping[str, int]],
    minimum_length: int,
) -> bool:
    """Return whether a shared team token is unique on this fixture side/window."""
    if not token_frequencies:
        return False
    return any(
        len(token) >= minimum_length and token_frequencies.get(token) == 1
        for token in set(source_tokens).intersection(reference_tokens)
    )


def _unique_token_rescue_has_anchor(home_rule: str, away_rule: str) -> bool:
    """Require exact or reviewed-alias evidence opposite a unique-token rescue."""
    unique_rule = "fuzzy_unique_token"
    anchor_rules = {"exact", "alias"}
    return not (
        (home_rule == unique_rule and away_rule not in anchor_rules)
        or (away_rule == unique_rule and home_rule not in anchor_rules)
    )


def _ngram_candidates(core: str, index: Dict[str, set]) -> set:
    """Find candidates sharing at least two spelling fragments with a team name."""
    ngrams = _team_ngrams(core)
    minimum_shared = min(2, len(ngrams))
    if not minimum_shared:
        return set()
    counts: Counter = Counter()
    for ngram in ngrams:
        counts.update(index.get(ngram, set()))
    return {match for match, count in counts.items() if count >= minimum_shared}
