"""Audit saved match JSON files for missing or incomplete scrape output."""

import json
import os
import unicodedata
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from src.oddspedia.scraping.config import (
    get_match_file,
    get_match_links_file,
    normalize_sport,
)
from src.oddspedia.scraping.manifest import (
    ScrapeManifest,
    create_manifest,
    load_manifest,
    save_manifest,
)
from src.oddspedia.scraping.storage import iter_match_payloads

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
    expected_matches = {str(item.get("id")): item for item in links if item.get("id") is not None}
    expected_ids = set(expected_matches)
    result.expected = len(expected_ids)

    existing_payloads = {item.match_id: item for item in iter_match_payloads(date_str, sport=sport)}
    existing_ids = set(existing_payloads)
    result.existing = len(existing_ids)

    for match_id in sorted(expected_ids):
        # ``iter_match_payloads`` has already indexed every plain JSON file and
        # archive member for this date. A second lookup would reopen and scan
        # the archive for every missing expected ID.
        stored = existing_payloads.get(match_id)
        if stored is None:
            result.missing.append(
                MatchAudit(
                    date=date_str,
                    sport=sport,
                    match_id=match_id,
                    path=get_match_file(date_str, match_id, sport=sport),
                    status="missing",
                )
            )
            continue

        audit = audit_match_payload(
            date_str,
            match_id,
            stored.payload,
            stored.source_file,
            stored.size_bytes,
            sport=sport,
            expected_match=expected_matches[match_id],
        )
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
        stored = existing_payloads[match_id]
        audit = audit_match_payload(
            date_str,
            match_id,
            stored.payload,
            stored.source_file,
            stored.size_bytes,
            sport=sport,
        )
        audit.status = "extra"
        audit.reasons.insert(0, "not present in match links")
        result.extra.append(audit)

    return result


def audit_match_json(
    date_str: str,
    match_id: str,
    path: str,
    sport: str = "football",
    expected_match: Optional[Dict[str, Any]] = None,
) -> MatchAudit:
    """Classify one saved match JSON for rescrape decisions."""
    sport = normalize_sport(sport)
    size = os.path.getsize(path)
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        return _invalid_audit(date_str, match_id, path, sport, size, f"json parse error: {exc.msg}")

    return audit_match_payload(
        date_str,
        match_id,
        data,
        path,
        size,
        sport=sport,
        expected_match=expected_match,
    )


def audit_match_payload(
    date_str: str,
    match_id: str,
    data: Any,
    source_file: str,
    size: int,
    sport: str = "football",
    expected_match: Optional[Dict[str, Any]] = None,
) -> MatchAudit:
    """Classify an already-loaded payload from JSON or a compressed archive."""
    sport = normalize_sport(sport)
    audit = MatchAudit(
        date=date_str,
        sport=sport,
        match_id=match_id,
        path=source_file,
        status=ACCEPTED_DATA_PRESENT,
        bytes=size,
    )

    if not isinstance(data, dict):
        audit.status = "invalid"
        audit.reasons.append("top-level JSON is not an object")
        return audit

    if str(data.get("id", "")) != str(match_id):
        audit.reasons.append("id does not match file name")

    for field_name in IDENTITY_FIELDS:
        if _is_blank(data.get(field_name)):
            audit.reasons.append(f"missing {field_name}")

    # A payload may only represent its requested listing event. Earlier
    # versions accepted same-team/different-date pages as market salvage,
    # which made odds, score, and stats belong to different fixtures.
    audit.reasons.extend(_listing_identity_reasons(data, expected_match))

    status_val = _normalize_status(data.get("status", ""))
    is_terminal_no_data = status_val in TERMINAL_NO_DATA_STATUSES
    is_result_unavailable = data.get("result_unavailable", False) and status_val == "finished"
    is_odds_unavailable = bool(data.get("odds_unavailable"))

    if (
        size < MIN_USEFUL_FILE_BYTES
        and not is_terminal_no_data
        and not is_result_unavailable
        and not is_odds_unavailable
    ):
        audit.observations.append(f"suspiciously small file ({size} bytes)")

    payload_reasons = _payload_reasons(data)
    audit.reasons.extend(payload_reasons)
    audit.reasons.extend(_football_odds_schema_reasons(data))
    audit.observations.extend(_football_coverage_observations(data))

    if audit.reasons:
        audit.status = "incomplete"
    elif is_terminal_no_data or is_result_unavailable:
        audit.status = ACCEPTED_TERMINAL_NO_DATA

    return audit


def _invalid_audit(
    date_str: str, match_id: str, path: str, sport: str, size: int, reason: str
) -> MatchAudit:
    return MatchAudit(
        date=date_str,
        sport=normalize_sport(sport),
        match_id=match_id,
        path=path,
        status="invalid",
        reasons=[reason],
        bytes=size,
    )


def sync_manifest_incomplete(result: DateAudit) -> Optional[ScrapeManifest]:
    """Persist incomplete/invalid IDs into the date manifest.

    Missing files are intentionally not stored in ``incomplete``. The scraper
    already treats missing expected JSON files as pending work. This field is
    for files that exist but should be re-scraped because the saved payload is
    structurally bad.
    """
    if result.expected == 0:
        return None

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
    return manifest


def _payload_reasons(data: Dict[str, Any]) -> List[str]:
    """Return reasons when data has missing or incomplete scrape content.

    Status is required for every match — a blank status always triggers a
    re-scrape regardless of how much other data was extracted.
    """
    reasons = []

    status_val = _normalize_status(data.get("status", ""))
    is_terminal_no_data = status_val in TERMINAL_NO_DATA_STATUSES
    is_result_unavailable = data.get("result_unavailable", False) and status_val == "finished"
    is_odds_unavailable = bool(data.get("odds_unavailable"))

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

    if (
        not is_terminal_no_data
        and not is_result_unavailable
        and not is_odds_unavailable
        and not has_payload
    ):
        if not reasons:
            reasons.append(
                "no status, score, odds, stats, point-by-point, or overall tabs extracted"
            )

    return reasons


def _football_coverage_observations(data: Dict[str, Any]) -> List[str]:
    """Report optional odds gaps without turning accepted data into work."""
    if data.get("sport") != "football":
        return []
    if data.get("odds_unavailable"):
        return ["football odds not yet available from bookies at scrape time"]
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


def _listing_identity_reasons(
    data: Dict[str, Any], expected_match: Optional[Dict[str, Any]]
) -> List[str]:
    """Return mismatches between a payload and its discovery inventory row."""
    if not expected_match:
        return []
    reasons = []
    expected_id = str(expected_match.get("id") or "").strip()
    source_event_id = str(data.get("source_event_id") or "").strip()
    if expected_id and source_event_id and expected_id != source_event_id:
        reasons.append(
            f"source_event_id does not match listing "
            f"(expected {expected_id!r}, found {source_event_id!r})"
        )
    for field_name in ("home", "away"):
        expected = _identity_key(expected_match.get(field_name))
        actual = _identity_key(data.get(field_name))
        if expected and actual and expected != actual:
            reasons.append(
                f"{field_name} does not match listing "
                f"(expected {expected_match.get(field_name)!r}, found {data.get(field_name)!r})"
            )

    expected_date = _date_key(expected_match.get("date"))
    actual_date = _date_key(data.get("date"))
    if expected_date and actual_date and expected_date != actual_date:
        reasons.append(
            "date does not match listing "
            f"(expected {expected_match.get('date')!r}, found {data.get('date')!r})"
        )
    return reasons


def _football_odds_schema_reasons(data: Dict[str, Any]) -> List[str]:
    """Reject ambiguous football odds lines instead of accepting lossy Bronze."""
    if data.get("sport") != "football":
        return []
    reasons = []
    for market in data.get("odds") or []:
        if not isinstance(market, dict):
            continue
        market_name = str(market.get("market", "")).strip() or "<unknown>"
        if market.get("schema_status") == "unmatched":
            reasons.append(f"unmatched odds market schema: {market_name}")
        for line_index, line in enumerate(market.get("lines") or []):
            if not isinstance(line, dict):
                continue
            if _is_blank(line.get("label")):
                reasons.append(f"blank odds line label: {market_name}[{line_index}]")
            if line.get("schema_status") == "unmatched":
                reasons.append(f"unmatched odds line schema: {market_name}[{line_index}]")
    return reasons


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


def _identity_key(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode("ascii")
    return "".join(character for character in text.lower() if character.isalnum())


def _date_key(value: Any) -> str:
    text = str(value or "").strip()
    return text[:10] if len(text) >= 10 and text[4] == "-" and text[7] == "-" else ""


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
