"""Audit saved match JSON files for missing or incomplete scrape output."""

import json
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List

from src.oddspedia.config import (
    get_match_links_file,
    get_match_file,
    get_matches_dir,
    normalize_sport,
)
from src.oddspedia.manifest import create_manifest, load_manifest, save_manifest


MIN_USEFUL_FILE_BYTES = 750
IDENTITY_FIELDS = ("id", "home", "away", "date", "url")
ACCEPTED_DATA_PRESENT = "accepted_data_present"
ACCEPTED_TERMINAL_NO_DATA = "accepted_terminal_no_data"

# These are the standard full-time selector markets exposed on rich football
# pages. A result already containing many markets should include every one.
_FOOTBALL_RICH_PAGE_MARKETS = {
    "full time result",
    "total goals",
    "asian handicap",
    "both teams to score",
    "double chance",
    "draw no bet",
    "first team to score",
    "correct score",
    "european handicap",
    "half time / full time",
    "next goal",
    "corners odd or even",
    "clean sheet",
    "to win both halves",
    "to score in both halves",
    "to score a penalty",
    "total corners",
}
TERMINAL_NO_DATA_STATUSES = {
    "canceled",
    "cancelled",
    "postponed",
    "walkover",
    "walk over",
    "abandoned",
    "retired",
    "suspended",
    "interrupted",
}


@dataclass
class MatchAudit:
    """Validation result for one expected or existing match JSON."""

    date: str
    match_id: str
    path: str
    status: str
    sport: str = "tennis"
    reasons: List[str] = field(default_factory=list)
    observations: List[str] = field(default_factory=list)
    bytes: int = 0

    @property
    def accepted(self) -> bool:
        return self.status in {ACCEPTED_DATA_PRESENT, ACCEPTED_TERMINAL_NO_DATA}


@dataclass
class DateAudit:
    """Audit result for one scrape date."""

    date: str
    sport: str = "tennis"
    expected: int = 0
    existing: int = 0
    accepted_data_present: int = 0
    accepted_terminal_no_data: int = 0
    missing: List[MatchAudit] = field(default_factory=list)
    incomplete: List[MatchAudit] = field(default_factory=list)
    invalid: List[MatchAudit] = field(default_factory=list)
    extra: List[MatchAudit] = field(default_factory=list)
    manifest_issues: List[str] = field(default_factory=list)
    coverage_observations: List[MatchAudit] = field(default_factory=list)

    @property
    def problems(self) -> int:
        return (
            len(self.missing)
            + len(self.incomplete)
            + len(self.invalid)
            + len(self.extra)
            + len(self.manifest_issues)
        )


def audit_date(date_str: str, sport: str = "football") -> DateAudit:
    """Audit one date against its match-link inventory and JSON outputs."""
    sport = normalize_sport(sport)
    result = DateAudit(date=date_str, sport=sport)
    links = _load_links(date_str, sport=sport)
    expected_ids = {str(item.get("id")) for item in links if item.get("id") is not None}
    result.expected = len(expected_ids)

    matches_dir = get_matches_dir(date_str, sport=sport)
    json_paths = _json_paths(matches_dir)
    existing_ids = {
        os.path.splitext(os.path.basename(path))[0].removeprefix("match_") for path in json_paths
    }
    result.existing = len(existing_ids)

    for match_id in sorted(expected_ids):
        path = get_match_file(date_str, match_id, sport=sport)
        if not os.path.exists(path):
            result.missing.append(
                MatchAudit(
                    date=date_str, sport=sport, match_id=match_id, path=path, status="missing"
                )
            )
            continue

        audit = audit_match_json(date_str, match_id, path, sport=sport)
        if audit.accepted:
            if audit.observations:
                result.coverage_observations.append(audit)
            if audit.status == ACCEPTED_TERMINAL_NO_DATA:
                result.accepted_terminal_no_data += 1
            else:
                result.accepted_data_present += 1
        elif audit.status == "invalid":
            result.invalid.append(audit)
        else:
            result.incomplete.append(audit)

    for match_id in sorted(existing_ids - expected_ids):
        path = get_match_file(date_str, match_id, sport=sport)
        audit = audit_match_json(date_str, match_id, path, sport=sport)
        audit.status = "extra"
        audit.reasons.insert(0, "not present in match links")
        result.extra.append(audit)

    return result


def audit_match_json(
    date_str: str, match_id: str, path: str, sport: str = "football"
) -> MatchAudit:
    """Classify one saved match JSON for rescrape decisions."""
    sport = normalize_sport(sport)
    size = os.path.getsize(path)
    audit = MatchAudit(
        date=date_str,
        sport=sport,
        match_id=match_id,
        path=path,
        status=ACCEPTED_DATA_PRESENT,
        bytes=size,
    )

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        audit.status = "invalid"
        audit.reasons.append(f"json parse error: {exc.msg}")
        return audit

    if not isinstance(data, dict):
        audit.status = "invalid"
        audit.reasons.append("top-level JSON is not an object")
        return audit

    if str(data.get("id", "")) != str(match_id):
        audit.reasons.append("id does not match file name")

    for field_name in IDENTITY_FIELDS:
        if _is_blank(data.get(field_name)):
            audit.reasons.append(f"missing {field_name}")

    status_val = _normalize_status(data.get("status", ""))
    is_terminal_no_data = status_val in TERMINAL_NO_DATA_STATUSES
    is_result_unavailable = data.get("result_unavailable", False) and status_val == "finished"

    if size < MIN_USEFUL_FILE_BYTES and not is_terminal_no_data and not is_result_unavailable:
        audit.observations.append(f"suspiciously small file ({size} bytes)")

    payload_reasons = _payload_reasons(data)
    audit.reasons.extend(payload_reasons)
    audit.observations.extend(_football_coverage_observations(data))

    if audit.reasons:
        audit.status = "incomplete"
    elif is_terminal_no_data or is_result_unavailable:
        audit.status = ACCEPTED_TERMINAL_NO_DATA

    return audit


def sync_manifest_incomplete(result: DateAudit) -> None:
    """Persist incomplete/invalid IDs into the date manifest.

    Missing files are intentionally not stored in ``incomplete``. The scraper
    already treats missing expected JSON files as pending work. This field is
    for files that exist but should be re-scraped because the saved payload is
    structurally bad.
    """
    if result.expected == 0:
        return

    manifest = load_manifest(result.date, sport=result.sport)
    if manifest is None:
        manifest = create_manifest(result.date, result.expected, sport=result.sport)
    elif manifest.total != result.expected:
        manifest.total = result.expected

    incomplete_ids = sorted({item.match_id for item in result.incomplete + result.invalid})
    manifest.incomplete = []
    for match_id in incomplete_ids:
        manifest.mark_incomplete(match_id)

    valid_bad_ids = set(incomplete_ids)
    manifest.done = [match_id for match_id in manifest.done if str(match_id) not in valid_bad_ids]
    manifest.failed = [
        match_id for match_id in manifest.failed if str(match_id) not in valid_bad_ids
    ]
    save_manifest(manifest)


def _payload_reasons(data: Dict[str, Any]) -> List[str]:
    """Return reasons when data has missing or incomplete scrape content.

    Status is required for every match — a blank status always triggers a
    re-scrape regardless of how much other data was extracted.
    """
    reasons = []

    status_val = _normalize_status(data.get("status", ""))
    is_terminal_no_data = status_val in TERMINAL_NO_DATA_STATUSES
    is_result_unavailable = data.get("result_unavailable", False) and status_val == "finished"

    if not status_val:
        reasons.append("status is missing")

    has_scores = isinstance(data.get("set_scores"), list) and len(data["set_scores"]) > 0
    score = data.get("score") if isinstance(data.get("score"), dict) else {}
    has_football_score = bool(score.get("home") != "" or score.get("away") != "")
    has_odds = _market_line_count(data.get("odds")) > 0
    has_live_odds = _market_line_count(data.get("live_odds")) > 0
    has_stats = _list_count(data.get("stats")) > 0
    has_pbp = _list_count(data.get("point_by_point")) > 0
    has_overall_tabs = len(data.get("overall_stats", {}).get("tabs", [])) > 0

    has_payload = any(
        (
            has_scores,
            has_football_score,
            has_odds,
            has_live_odds,
            has_stats,
            has_pbp,
            has_overall_tabs,
        )
    )

    if (
        data.get("sport") == "football"
        and status_val in {"finished", "ft", "aet", "ot", "pen"}
        and not is_result_unavailable
        and not has_football_score
    ):
        reasons.append("finished football match is missing a final score")

    if not is_terminal_no_data and not is_result_unavailable and not has_payload:
        if not reasons:
            reasons.append(
                "no status, score, odds, stats, point-by-point, or overall tabs extracted"
            )

    return reasons


def _football_coverage_observations(data: Dict[str, Any]) -> List[str]:
    """Report optional odds gaps without turning accepted data into work."""
    if data.get("sport") != "football":
        return []
    markets = data.get("odds", []) if isinstance(data.get("odds"), list) else []
    market_count = len(markets)
    market_names = {
        str(market.get("market", "")).strip().lower()
        for market in markets
        if isinstance(market, dict)
    }
    observations = []
    if 0 < market_count <= 2:
        observations.append(f"limited football odds coverage ({market_count} markets)")

    has_other_corners_market = any(
        "corner" in market_name and market_name != "total corners" for market_name in market_names
    )
    if has_other_corners_market and "total corners" not in market_names:
        observations.append("Total Corners missing while other corners markets are present")

    if market_count >= 15:
        missing_markets = sorted(_FOOTBALL_RICH_PAGE_MARKETS - market_names)
        if missing_markets:
            observations.append("football rich-page markets missing: " + ", ".join(missing_markets))
    return observations


def _market_line_count(markets: Any) -> int:
    if not isinstance(markets, list):
        return 0
    total = 0
    for market in markets:
        if isinstance(market, dict) and isinstance(market.get("lines"), list):
            total += len(market["lines"])
    return total


def _list_count(value: Any) -> int:
    return len(value) if isinstance(value, list) else 0


def _is_blank(value: Any) -> bool:
    return value is None or str(value).strip() == ""


def _normalize_status(value: Any) -> str:
    return "" if value is None else str(value).strip().lower()


def _load_links(date_str: str, sport: str = "football") -> List[Dict[str, Any]]:
    path = get_match_links_file(date_str, sport=sport)
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def _json_paths(matches_dir: str) -> List[str]:
    if not os.path.isdir(matches_dir):
        return []
    return [
        os.path.join(matches_dir, name)
        for name in os.listdir(matches_dir)
        if name.endswith(".json") and os.path.isfile(os.path.join(matches_dir, name))
    ]
