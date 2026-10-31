"""Prioritize Oddspedia event links against canonical DepthMark fixtures."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

from src.common.dates import normalize_compact_date
from src.common.logging import get_logger
from src.oddspedia.scraping.config import (
    get_match_links_file,
    get_prioritized_match_links_file,
)
from src.oddspedia.silver.match_resolution import (
    FotMobMatch,
    FotMobReferenceWindowVerifier,
    OddspediaEvent,
    OddspediaMatchResolver,
    ResolutionResult,
)

logger = get_logger(__name__)

PRIORITY_SCHEMA_VERSION = "v6"
PRIORITY_TIERS = ("xG", "ratings", "lower", "unmatched")
_TIER_RANK = {tier: rank for rank, tier in enumerate(PRIORITY_TIERS)}


@dataclass(frozen=True)
class PriorityArtifact:
    """One deterministic, date-scoped links-layer priority decision."""

    payload: dict[str, Any]

    @property
    def links(self) -> list[dict[str, Any]]:
        return list(self.payload.get("links") or [])

    @property
    def source_checksum(self) -> str:
        source_inventory = self.payload.get("source_inventory") or {}
        return str(source_inventory.get("sha256") or "")


def source_inventory_checksum(links: Sequence[dict[str, Any]]) -> str:
    """Hash the exact accepted source inventory without mutating its records."""
    encoded = json.dumps(list(links), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def load_priority_artifact(date_str: str, sport: str = "football") -> PriorityArtifact | None:
    """Load a date priority artifact when it exists and has the expected shape."""
    path = Path(get_prioritized_match_links_file(date_str, sport=sport))
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as source:
        payload = json.load(source)
    if not isinstance(payload, dict) or not isinstance(payload.get("links"), list):
        raise ValueError(f"Priority artifact has invalid shape: {path}")
    return PriorityArtifact(payload=payload)


def priority_artifact_is_current(
    artifact: PriorityArtifact,
    date_str: str,
    links: Sequence[dict[str, Any]],
    matcher_rule_version: str | None = None,
) -> bool:
    """Return whether an artifact still describes the current source inventory."""
    matches_source = artifact.payload.get("prioritized_date") == normalize_compact_date(
        date_str
    ) and artifact.source_checksum == source_inventory_checksum(links)
    matches_matcher = (
        matcher_rule_version is None
        or artifact.payload.get("matcher", {}).get("rule_version") == matcher_rule_version
    )
    return (
        artifact.payload.get("schema_version") == PRIORITY_SCHEMA_VERSION
        and matches_source
        and matches_matcher
    )


def select_links_for_priority(
    artifact: PriorityArtifact,
    priority: str,
    source_links: Sequence[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Rehydrate priority-selected links from the immutable source inventory."""
    if priority not in _TIER_RANK:
        raise ValueError(f"Unknown priority tier: {priority}")
    maximum_rank = _TIER_RANK[priority]
    links_by_id = {str(link.get("id") or ""): link for link in source_links}
    selected = []
    for record in artifact.links:
        resolution = record.get("resolution") or {}
        record_priority = resolution.get("priority")
        if record_priority in _TIER_RANK and _TIER_RANK[record_priority] <= maximum_rank:
            oddspedia_id = str(record.get("oddspedia_id") or "")
            source_link = links_by_id.get(oddspedia_id)
            if source_link is None:
                raise ValueError(
                    f"Priority record references missing source link: oddspedia_id={oddspedia_id}"
                )
            selected.append(source_link)
    return selected


class LinkPriorityService:
    """Build a source-link priority artifact using the shared resolver policy."""

    def __init__(self, client, resolver: OddspediaMatchResolver):
        self.client = client
        self.resolver = resolver

    def prioritize(
        self, date_str: str, links: Sequence[dict[str, Any]], sport: str = "football"
    ) -> PriorityArtifact:
        """Produce a complete decision ledger for one accepted source inventory."""
        date_id = normalize_compact_date(date_str)
        discovery_date = datetime.strptime(date_id, "%Y%m%d").date()
        reference_dates = self.resolver.candidate_dates(discovery_date)
        reference_verification = FotMobReferenceWindowVerifier(self.client).require_complete(
            reference_dates
        )
        fotmob_matches = self._load_fotmob_matches(reference_dates)
        matches_by_id = {match.match_id: match for match in fotmob_matches}
        index = self.resolver.candidate_index(fotmob_matches)
        records = []
        for source_link in links:
            event = _event_from_link(source_link, discovery_date)
            result = self.resolver.resolve_from_index(event, index, reference_window_complete=True)
            records.append(
                {
                    "oddspedia_id": str(source_link.get("id") or ""),
                    "providers": _provider_pair_payload(source_link, result, matches_by_id),
                    "resolution": _resolution_payload(result),
                }
            )

        payload = {
            "schema_version": PRIORITY_SCHEMA_VERSION,
            "prioritized_date": date_id,
            "source_inventory": {
                "path": get_match_links_file(date_id, sport=sport),
                "sha256": source_inventory_checksum(links),
            },
            "reference_window": {
                "dates": [candidate_date.strftime("%Y%m%d") for candidate_date in reference_dates],
                "verification": reference_verification.as_dict(),
            },
            "matcher": {"rule_version": self.resolver.rule_version},
            "generated_at": datetime.now(UTC).isoformat(),
            "links": records,
        }
        logger.info(
            "link_priority_reference_loaded",
            date=date_id,
            reference_dates=[
                candidate_date.strftime("%Y%m%d") for candidate_date in reference_dates
            ],
            fotmob_matches=len(fotmob_matches),
            fotmob_matches_without_kickoff=sum(
                match.kickoff_utc is None for match in fotmob_matches
            ),
            coverage_counts=dict(
                Counter(match.coverage_level or "unknown" for match in fotmob_matches)
            ),
        )
        logger.info(
            "link_priorities_calculated",
            date=date_id,
            links=len(records),
            statuses=dict(Counter(record["resolution"]["status"] for record in records)),
            priority_counts=dict(
                Counter(record["resolution"].get("priority") or "none" for record in records)
            ),
            confidence_counts=dict(
                Counter(record["resolution"].get("confidence") or "none" for record in records)
            ),
            team_match_rule_counts=_team_match_rule_counts(
                record["resolution"] for record in records
            ),
            no_candidate_count=sum(
                record["resolution"]["status"] == "unmatched" for record in records
            ),
        )
        return PriorityArtifact(payload=payload)

    def _load_fotmob_matches(self, reference_dates: Iterable[date]) -> list[FotMobMatch]:
        dates = tuple(reference_dates)
        if len(dates) != 3:
            raise ValueError("Link priority requires exactly a three-day reference window")
        query = """
            SELECT match_id, match_date, match_time_utc, home_team_name,
                   away_team_name, coverage_level, league_name
            FROM silver.match FINAL
            WHERE match_date >= {start_date:Date} AND match_date <= {end_date:Date}
        """
        rows = self.client.execute(
            query,
            parameters={
                "start_date": dates[0].isoformat(),
                "end_date": dates[-1].isoformat(),
            },
        ).result_rows
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


def save_priority_artifact(
    artifact: PriorityArtifact, date_str: str, sport: str = "football"
) -> str:
    """Atomically save one priority artifact and return its absolute path."""
    path = Path(get_prioritized_match_links_file(date_str, sport=sport))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_suffix(".tmp")
    temporary_path.write_text(
        json.dumps(artifact.payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    temporary_path.replace(path)
    logger.info("link_priorities_saved", path=str(path), date=normalize_compact_date(date_str))
    return str(path)


def priority_run_summary(
    artifact: PriorityArtifact, artifact_path: str, selected_priority: str = "lower"
) -> dict[str, Any]:
    """Return the manifest-sized audit summary for a priority decision."""
    resolutions = [record.get("resolution") or {} for record in artifact.links]
    statuses = Counter(resolution.get("status") or "unknown" for resolution in resolutions)
    priorities = Counter(resolution.get("priority") or "none" for resolution in resolutions)
    confidences = Counter(resolution.get("confidence") or "none" for resolution in resolutions)
    selected_count = _selected_record_count(artifact, selected_priority)
    no_candidate_count = sum(resolution.get("status") == "unmatched" for resolution in resolutions)
    return {
        "artifact_path": artifact_path,
        "artifact_checksum": _artifact_checksum(artifact.payload),
        "source_inventory_checksum": artifact.source_checksum,
        "prioritized_date": artifact.payload["prioritized_date"],
        "matcher_rule_version": artifact.payload["matcher"]["rule_version"],
        "selected_priority": selected_priority,
        "selected_count": selected_count,
        "validation_status_counts": dict(statuses),
        "priority_counts": dict(priorities),
        "match_confidence_counts": dict(confidences),
        "team_match_rule_counts": _team_match_rule_counts(resolutions),
        "no_candidate_count": no_candidate_count,
        "updated_at": datetime.now(UTC).isoformat(),
    }


def _event_from_link(source_link: dict[str, Any], discovery_date: date) -> OddspediaEvent:
    return OddspediaEvent(
        oddspedia_match_id=str(source_link.get("id") or ""),
        discovery_date=discovery_date,
        kickoff_utc=None,
        home_team_name=str(source_link.get("home") or ""),
        away_team_name=str(source_link.get("away") or ""),
        league_name=str(source_link.get("league_name") or ""),
    )


def _resolution_payload(result: ResolutionResult) -> dict[str, Any]:
    priority = _priority_for(result)
    return {
        "status": result.resolution_status,
        "coverage_category": result.coverage_category,
        "priority": priority,
        "confidence": result.confidence,
        "score": result.match_score,
        "margin": result.score_margin,
        "rules": {
            "home": result.home_match_rule,
            "away": result.away_match_rule,
        },
    }


def _provider_pair_payload(
    source_link: dict[str, Any],
    result: ResolutionResult,
    matches_by_id: dict[int, FotMobMatch],
) -> dict[str, dict[str, Any] | None]:
    """Return provider rows with an identical field contract for direct comparison."""
    match = matches_by_id.get(result.fotmob_match_id) if result.fotmob_match_id else None
    return {
        "oddspedia": _oddspedia_provider_row(source_link),
        "fotmob": _fotmob_provider_row(match) if match else None,
    }


def _oddspedia_provider_row(source_link: dict[str, Any]) -> dict[str, Any]:
    scheduled_at = source_link.get("date")
    return {
        "id": str(source_link.get("id") or ""),
        "home_team": str(source_link.get("home") or ""),
        "away_team": str(source_link.get("away") or ""),
        "scheduled_at_utc": str(scheduled_at) if scheduled_at else None,
        "competition": str(source_link.get("league_name") or "") or None,
        "coverage_level": None,
        "url": source_link.get("full_url") or source_link.get("url") or None,
    }


def _fotmob_provider_row(match: FotMobMatch) -> dict[str, Any]:
    return {
        "id": str(match.match_id),
        "home_team": match.home_team_name,
        "away_team": match.away_team_name,
        "scheduled_at_utc": match.kickoff_utc.isoformat() if match.kickoff_utc else None,
        "competition": match.league_name or None,
        "coverage_level": match.coverage_level or None,
        "url": None,
    }


def _priority_for(result: ResolutionResult) -> str | None:
    if result.resolution_status == "matched" and result.coverage_category in _TIER_RANK:
        return result.coverage_category
    if result.resolution_status == "unmatched":
        return "unmatched"
    return None


def _team_match_rule_counts(resolutions: Iterable[dict[str, Any]]) -> dict[str, int]:
    """Count home/away comparison methods used by confirmed approximate matches."""
    rules = Counter()
    for resolution in resolutions:
        if resolution.get("status") != "matched":
            continue
        for rule in (resolution.get("rules") or {}).values():
            if rule:
                rules[rule] += 1
    return dict(rules)


def _selected_record_count(artifact: PriorityArtifact, priority: str) -> int:
    if priority not in _TIER_RANK:
        raise ValueError(f"Unknown priority tier: {priority}")
    maximum_rank = _TIER_RANK[priority]
    return sum(
        (record.get("resolution") or {}).get("priority") in _TIER_RANK
        and _TIER_RANK[(record.get("resolution") or {})["priority"]] <= maximum_rank
        for record in artifact.links
    )


def _artifact_checksum(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()
