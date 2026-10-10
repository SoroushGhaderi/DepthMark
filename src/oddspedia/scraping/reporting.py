"""Build read-only operational reports from Oddspedia run artifacts."""

from __future__ import annotations

import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

from src.common.logging import get_logger
from src.oddspedia.scraping.audit import DateAudit, audit_date
from src.oddspedia.scraping.config import (
    get_manifest_file,
    get_match_links_file,
    get_prioritized_match_links_file,
    get_run_logs_dir,
    get_storage_aspect,
    normalize_date,
    normalize_sport,
)
from src.oddspedia.scraping.link_prioritization import PRIORITY_TIERS, source_inventory_checksum
from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.storage import iter_match_payloads

logger = get_logger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parents[3]
_ANSI_ESCAPE_RE = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
_PRIORITY_RANK = {tier: rank for rank, tier in enumerate(PRIORITY_TIERS)}


def build_run_report(date_str: str, sport: str = "football") -> Dict[str, Any]:
    """Build a JSON-serializable report without acquiring locks or writing state."""
    date_id = normalize_date(date_str)
    sport_id = normalize_sport(sport)
    links_path = Path(get_match_links_file(date_id, sport=sport_id))
    source_links = _load_links(links_path)
    manifest_path = Path(get_manifest_file(date_id, sport=sport_id))
    manifest = _load_manifest_quiet(manifest_path)
    inventory_summary = _inventory_summary(source_links, links_path, manifest)
    priority_path = Path(get_prioritized_match_links_file(date_id, sport=sport_id))
    priority_payload = _load_optional_json(priority_path)
    priority_summary, selected_ids = _priority_summary(
        priority_payload,
        source_links,
        date_id,
        manifest,
        priority_path,
    )
    audit = audit_date(date_id, sport=sport_id)
    payloads = list(iter_match_payloads(date_id, sport=sport_id))
    log_summary = _log_summary(date_id, sport_id, manifest)
    scrape_summary = _scrape_summary(manifest, selected_ids)
    audit_summary = _audit_summary(audit, selected_ids)
    payload_summary = _payload_summary(payloads)
    warehouse_summary = _warehouse_summary(scrape_summary, audit_summary)
    overall_status = _overall_status(scrape_summary, audit_summary, priority_summary)
    summary = {
        "discovered": inventory_summary["total"],
        "completed": scrape_summary["completed"] + scrape_summary["skipped"],
        "failed": scrape_summary["failed"] + scrape_summary["incomplete"],
        "skipped": scrape_summary["skipped"],
        "remaining": scrape_summary["remaining"],
        "progress_pct": scrape_summary["progress_pct"],
        "artifact_files": payload_summary["count"],
        "storage_size_mb": payload_summary["storage_size_mb"],
        "bronze_admission_ready": warehouse_summary["bronze_admission_ready"],
    }
    report = {
        "schema_version": "v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "oddspedia",
        "date": date_id,
        "sport": sport_id,
        "aspect": get_storage_aspect(date_id),
        "overall_status": overall_status,
        "summary": summary,
        "inventory": inventory_summary,
        "priority": priority_summary,
        "scrape": scrape_summary,
        "payload_audit": audit_summary,
        "payloads": payload_summary,
        "operations": log_summary,
        "warehouse": warehouse_summary,
        "evidence": {
            "match_links": _display_path(links_path),
            "manifest": _display_path(manifest_path),
            "priority_artifact": _display_path(priority_path),
        },
    }
    report["findings"] = _findings(report)
    report["next_steps"] = _next_steps(report)
    return report


def _load_links(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    payload = _load_json(path)
    if not isinstance(payload, list):
        raise ValueError(f"Oddspedia match-links artifact must be a list: {path}")
    return [item for item in payload if isinstance(item, dict)]


def _load_optional_json(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    payload = _load_json(path)
    if not isinstance(payload, dict):
        raise ValueError(f"Oddspedia artifact must be an object: {path}")
    return payload


def _load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def _load_manifest_quiet(path: Path) -> Optional[ScrapeManifest]:
    """Load the manifest without emitting the status logger's console event."""
    if not path.exists():
        return None
    payload = _load_json(path)
    if not isinstance(payload, dict) or not payload.get("date"):
        raise ValueError(f"Oddspedia manifest root is invalid: {path}")
    return ScrapeManifest.from_dict(payload)


def _inventory_summary(
    links: Sequence[Dict[str, Any]], path: Path, manifest: Optional[ScrapeManifest]
) -> Dict[str, Any]:
    ids = [str(link.get("id")) for link in links if link.get("id") is not None]
    discovery = (manifest.discovery if manifest else {}) or {}
    return {
        "path": _display_path(path),
        "total": len(links),
        "unique_ids": len(set(ids)),
        "duplicate_ids": len(ids) - len(set(ids)),
        "status_counts": dict(Counter(str(link.get("status") or "unknown") for link in links)),
        "discovery_status": discovery.get("status"),
        "discovery_pages": {
            "expected": discovery.get("expected_pages"),
            "observed": discovery.get("observed_pages"),
        },
        "inventory_checksum": discovery.get("inventory_checksum"),
    }


def _priority_summary(
    payload: Optional[Dict[str, Any]],
    source_links: Sequence[Dict[str, Any]],
    date_id: str,
    manifest: Optional[ScrapeManifest],
    path: Path,
) -> Tuple[Dict[str, Any], Set[str]]:
    if payload is None:
        return (
            {
                "artifact_present": False,
                "path": _display_path(path),
                "selected_priority": (manifest.priority_run if manifest else {}).get(
                    "selected_priority", "lower"
                ),
                "selected_count": 0,
                "matched_count": 0,
                "unmatched_count": 0,
                "priority_counts": {},
                "confidence_counts": {},
                "reference_window_verified": False,
                "source_checksum_matches_inventory": False,
            },
            set(),
        )

    records = [record for record in payload.get("links", []) if isinstance(record, dict)]
    resolutions = [record.get("resolution") or {} for record in records]
    priority_run = (manifest.priority_run if manifest else {}) or {}
    selected_priority = str(priority_run.get("selected_priority") or "lower")
    maximum_rank = _PRIORITY_RANK.get(selected_priority, _PRIORITY_RANK["lower"])
    selected_ids = {
        str(record.get("oddspedia_id"))
        for record in records
        if _PRIORITY_RANK.get((record.get("resolution") or {}).get("priority"), 99) <= maximum_rank
    }
    reference_window = payload.get("reference_window") or {}
    verification = reference_window.get("verification") or {}
    source_checksum = str((payload.get("source_inventory") or {}).get("sha256") or "")
    return (
        {
            "artifact_present": True,
            "path": _display_path(path),
            "schema_version": payload.get("schema_version"),
            "prioritized_date": payload.get("prioritized_date"),
            "generated_at": payload.get("generated_at"),
            "links": len(records),
            "selected_priority": selected_priority,
            "selected_count": len(selected_ids),
            "matched_count": sum(
                resolution.get("status") == "matched" for resolution in resolutions
            ),
            "unmatched_count": sum(
                resolution.get("status") == "unmatched" for resolution in resolutions
            ),
            "priority_counts": dict(
                Counter(resolution.get("priority") or "none" for resolution in resolutions)
            ),
            "confidence_counts": dict(
                Counter(resolution.get("confidence") or "none" for resolution in resolutions)
            ),
            "reference_dates": reference_window.get("dates") or [],
            "reference_window_verified": bool(verification.get("verified")),
            "source_checksum_matches_inventory": source_checksum
            == source_inventory_checksum(source_links),
            "source_checksum": source_checksum,
            "matcher_rule_version": (payload.get("matcher") or {}).get("rule_version"),
            "date_matches_artifact": payload.get("prioritized_date") == date_id,
        },
        selected_ids,
    )


def _scrape_summary(manifest: Optional[ScrapeManifest], selected_ids: Set[str]) -> Dict[str, Any]:
    if manifest is None:
        return {
            "manifest_present": False,
            "total": 0,
            "completed": 0,
            "failed": 0,
            "incomplete": 0,
            "skipped": 0,
            "remaining": 0,
            "progress_pct": 0.0,
            "selected_completed": 0,
            "selected_skipped": 0,
            "selected_scope_complete": False,
            "full_date_scope_complete": False,
            "metrics": {},
        }

    done_ids = {str(match_id) for match_id in manifest.done}
    skipped_ids = {str(match_id) for match_id in manifest.skipped}
    discovery_status = (manifest.discovery or {}).get("status")
    full_date_complete = (manifest.total == 0 and discovery_status == "no_events") or (
        manifest.total > 0
        and len(done_ids) + len(skipped_ids) >= manifest.total
        and not manifest.failed
        and not manifest.incomplete
        and not manifest.in_progress
    )
    selected_completed = len(done_ids.intersection(selected_ids))
    selected_skipped = len(skipped_ids.intersection(selected_ids))
    progress_pct = (
        100.0
        if manifest.total == 0 and discovery_status == "no_events"
        else manifest.completed_progress
    )
    return {
        "manifest_present": True,
        "total": manifest.total,
        "completed": len(done_ids),
        "failed": len(manifest.failed),
        "incomplete": len(manifest.incomplete),
        "skipped": len(skipped_ids),
        "remaining": max(
            manifest.total - len(done_ids) - len(manifest.failed) - len(skipped_ids), 0
        ),
        "progress_pct": progress_pct,
        "selected_completed": selected_completed,
        "selected_skipped": selected_skipped,
        "selected_scope_complete": bool(selected_ids)
        and selected_completed + selected_skipped >= len(selected_ids),
        "full_date_scope_complete": full_date_complete,
        "run_id": (manifest.metrics or {}).get("run_id"),
        "duration_seconds": ((manifest.metrics or {}).get("run") or {}).get("duration_seconds"),
        "metrics": _metrics_summary(manifest.metrics or {}),
    }


def _metrics_summary(metrics: Dict[str, Any]) -> Dict[str, Any]:
    keys = (
        "run",
        "match_detail_extraction",
        "performance",
        "cloudflare",
        "odds",
        "live_odds",
        "errors",
        "validation_failures",
        "circuit_breaker",
    )
    return {key: metrics.get(key) for key in keys if key in metrics}


def _audit_summary(audit: DateAudit, selected_ids: Set[str]) -> Dict[str, Any]:
    observation_counts = Counter(
        observation for item in audit.coverage_observations for observation in item.observations
    )
    accepted = audit.accepted_data_present + audit.accepted_terminal_no_data
    missing_ids = {item.match_id for item in audit.missing}
    incomplete_ids = {item.match_id for item in audit.incomplete}
    invalid_ids = {item.match_id for item in audit.invalid}
    selected_missing = len(selected_ids.intersection(missing_ids))
    selected_incomplete = len(selected_ids.intersection(incomplete_ids))
    selected_invalid = len(selected_ids.intersection(invalid_ids))
    selected_problem_count = selected_missing + selected_incomplete + selected_invalid
    selected_accepted = max(len(selected_ids) - selected_problem_count, 0)
    return {
        "expected": audit.expected,
        "existing": audit.existing,
        "accepted": accepted,
        "accepted_data_present": audit.accepted_data_present,
        "accepted_terminal_no_data": audit.accepted_terminal_no_data,
        "missing": len(audit.missing),
        "incomplete": len(audit.incomplete),
        "invalid": len(audit.invalid),
        "extra": len(audit.extra),
        "manifest_issues": list(audit.manifest_issues),
        "problem_count": audit.problems,
        "accepted_rate_pct": _percentage(accepted, audit.expected),
        "selected_expected": len(selected_ids),
        "selected_accepted": selected_accepted,
        "selected_missing": selected_missing,
        "selected_incomplete": selected_incomplete,
        "selected_invalid": selected_invalid,
        "selected_problem_count": selected_problem_count,
        "selected_accepted_rate_pct": _percentage(selected_accepted, len(selected_ids)),
        "coverage_observation_payloads": len(audit.coverage_observations),
        "observation_counts": dict(observation_counts),
    }


def _payload_summary(payloads: Iterable[Any]) -> Dict[str, Any]:
    payload_list = list(payloads)
    odds_unavailable_ids = sorted(
        str(payload.match_id) for payload in payload_list if payload.payload.get("odds_unavailable")
    )
    status_counts = Counter(
        str(payload.payload.get("status") or "unknown") for payload in payload_list
    )
    odds_attempt_counts = Counter(
        str(payload.payload.get("odds_attempt") or "unknown") for payload in payload_list
    )
    market_counts = [
        len(payload.payload.get("odds") or [])
        for payload in payload_list
        if isinstance(payload.payload.get("odds"), list)
    ]
    storage_size_bytes = sum(int(payload.size_bytes) for payload in payload_list)
    return {
        "count": len(payload_list),
        "storage_size_bytes": storage_size_bytes,
        "storage_size_mb": round(storage_size_bytes / (1024**2), 2),
        "status_counts": dict(status_counts),
        "odds_unavailable_count": len(odds_unavailable_ids),
        "odds_unavailable_ids": odds_unavailable_ids,
        "odds_attempt_counts": dict(odds_attempt_counts),
        "market_count_min": min(market_counts) if market_counts else 0,
        "market_count_max": max(market_counts) if market_counts else 0,
        "market_count_average": round(sum(market_counts) / len(market_counts), 2)
        if market_counts
        else 0.0,
    }


def _log_summary(date_id: str, sport: str, manifest: Optional[ScrapeManifest]) -> Dict[str, Any]:
    logs_dir = Path(get_run_logs_dir(date_id, sport=sport))
    paths = sorted(logs_dir.glob("*.log")) if logs_dir.exists() else []
    summaries = [_summarize_log(path) for path in paths]
    scrape_runs = [
        item for item in summaries if item["status"] in {"success", "failed", "incomplete"}
    ]
    status_inspections = [item for item in summaries if item["status"] == "status_only"]
    primary_path = ((manifest.metrics if manifest else {}) or {}).get("log_path")
    return {
        "logs_dir": _display_path(logs_dir),
        "primary_log": _display_path(Path(primary_path)) if primary_path else None,
        "scrape_runs": scrape_runs,
        "status_inspections": status_inspections,
        "other_logs": [item for item in summaries if item not in scrape_runs + status_inspections],
    }


def _summarize_log(path: Path) -> Dict[str, Any]:
    content = _ANSI_ESCAPE_RE.sub("", path.read_text(encoding="utf-8", errors="replace"))
    has_scraper_start = "scraper_start" in content
    has_scrape_complete = "scrape_json_complete" in content
    has_fatal_error = "fatal_error" in content
    has_status_event = "manifest_status_shown" in content
    if has_scrape_complete:
        status = "success"
    elif has_fatal_error:
        status = "failed"
    elif has_status_event and not has_scraper_start:
        status = "status_only"
    elif has_scraper_start:
        status = "incomplete"
    else:
        status = "other"
    return {
        "path": _display_path(path),
        "status": status,
        "retry_events": content.count("match_retry"),
        "cloudflare_waits": content.count("cloudflare_wait_start"),
        "cloudflare_timeouts": content.count("cloudflare_wait_timeout"),
        "fatal_errors": content.count("fatal_error"),
        "scrape_complete_events": content.count("scrape_json_complete"),
    }


def _warehouse_summary(scrape: Dict[str, Any], audit: Dict[str, Any]) -> Dict[str, Any]:
    ready = bool(
        scrape.get("full_date_scope_complete")
        and audit.get("problem_count") == 0
        and audit.get("manifest_issues") == []
    )
    if ready:
        reason = "The full inventory is terminal and all saved payloads pass the artifact audit."
    else:
        reason = (
            "The full inventory is not terminal for Bronze admission: "
            f"completed={scrape.get('completed', 0)}/{scrape.get('total', 0)}, "
            f"remaining={scrape.get('remaining', 0)}, "
            f"audit_missing={audit.get('missing', 0)}, "
            f"audit_incomplete={audit.get('incomplete', 0)}, "
            f"audit_invalid={audit.get('invalid', 0)}."
        )
    return {"bronze_admission_ready": ready, "reason": reason}


def _overall_status(scrape: Dict[str, Any], audit: Dict[str, Any], priority: Dict[str, Any]) -> str:
    if not scrape.get("manifest_present"):
        return "not_started"
    if (
        scrape.get("total") == 0
        and scrape.get("full_date_scope_complete")
        and audit.get("problem_count") == 0
    ):
        return "complete"
    if (
        priority.get("selected_count", 0)
        and scrape.get("selected_scope_complete")
        and not audit.get("selected_problem_count", audit.get("problem_count"))
    ):
        if scrape.get("full_date_scope_complete"):
            return "complete"
        return "priority_scope_complete"
    if not priority.get("artifact_present"):
        return "priority_artifact_missing"
    return "attention_required"


def _findings(report: Dict[str, Any]) -> List[str]:
    inventory = report["inventory"]
    priority = report["priority"]
    scrape = report["scrape"]
    audit = report["payload_audit"]
    payloads = report["payloads"]
    operations = report["operations"]
    findings = []
    manifest_present = scrape.get("manifest_present", True)
    if not manifest_present:
        findings.append(
            "**Warning — scrape not started:** no Oddspedia manifest exists for this date."
        )
    if priority["selected_count"] < inventory["total"]:
        findings.append(
            "**Warning — full-date scope is incomplete:** "
            f"{priority['selected_count']}/{inventory['total']} inventory events were selected "
            f"through `{priority['selected_priority']}`. The "
            f"{inventory['total'] - priority['selected_count']} "
            "unmatched events are outside the selected scrape scope by design."
        )
    if priority["unmatched_count"]:
        findings.append(
            "**Warning — resolution coverage:** "
            f"{priority['unmatched_count']} inventory events have no FotMob candidate. "
            "This is a matching/coverage gap, not a detail-scrape failure."
        )
    if manifest_present and not scrape["full_date_scope_complete"]:
        findings.append(
            "**Warning — Bronze admission is blocked:** the full inventory has not reached a "
            f"terminal state ({scrape['completed']}/{scrape['total']} complete; "
            f"{scrape['remaining']} remaining)."
        )
    if audit.get("selected_problem_count", audit["problem_count"]):
        findings.append(
            "**Warning — selected payload audit problems:** "
            f"missing={audit.get('selected_missing', audit['missing'])}, "
            f"incomplete={audit.get('selected_incomplete', audit['incomplete'])}, "
            f"invalid={audit.get('selected_invalid', audit['invalid'])}."
        )
    if payloads["odds_unavailable_count"]:
        findings.append(
            "**Suggestion — odds availability:** "
            f"{payloads['odds_unavailable_count']} accepted payload(s) were marked terminal "
            "odds-unavailable: " + ", ".join(payloads["odds_unavailable_ids"]) + "."
        )
    if audit["coverage_observation_payloads"]:
        findings.append(
            "**Suggestion — optional market coverage:** "
            f"{audit['coverage_observation_payloads']} accepted payloads recorded rich-page market "
            "observations; these did not fail the current audit contract."
        )
    failed_runs = [run for run in operations["scrape_runs"] if run["status"] == "failed"]
    if failed_runs:
        findings.append(
            "**Suggestion — transient operational failure:** "
            f"{len(failed_runs)} scrape attempt failed before recovery; inspect the failed log(s) "
            "and consider alerting on this pattern."
        )
    return findings


def _next_steps(report: Dict[str, Any]) -> List[str]:
    """Return actionable commands without changing report state."""
    date_id = report["date"]
    inventory = report["inventory"]
    priority = report["priority"]
    scrape = report["scrape"]
    warehouse = report["warehouse"]
    steps: List[str] = []
    if not scrape["manifest_present"] and not inventory["total"]:
        steps.append(f"python3 scripts/oddspedia/discover_oddspedia_events.py --date {date_id}")
    elif inventory["total"] and not priority["artifact_present"]:
        steps.append(
            "python3 scripts/oddspedia/prioritize_oddspedia_events.py "
            f"--date {date_id} --silver-reference-window-ready"
        )
    elif priority["selected_count"] and not scrape["selected_scope_complete"]:
        steps.append(
            "python3 scripts/oddspedia/scrape_oddspedia_matches.py "
            f"--date {date_id} --priority-tier {priority['selected_priority']}"
        )
    if warehouse["bronze_admission_ready"]:
        steps.extend(
            [
                "python3 scripts/oddspedia/load_oddspedia_bronze.py " f"--date {date_id} --dry-run",
                "python3 scripts/oddspedia/resolve_oddspedia_events.py "
                f"--date {date_id} --dry-run",
            ]
        )
    elif scrape.get("selected_scope_complete") and not scrape.get("full_date_scope_complete"):
        steps.append("Review unmatched event coverage before treating this date as Bronze-ready.")
    return steps


def _percentage(numerator: int, denominator: int) -> float:
    return round((numerator / denominator) * 100, 2) if denominator else 0.0


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(PROJECT_ROOT))
    except ValueError:
        return str(path)
