"""Build read-only operational reports from FotMob Bronze artifacts."""

from __future__ import annotations

import json
import re
import tarfile
from collections import Counter
from datetime import date, datetime
from pathlib import Path
from typing import Any

from config.settings import get_settings

PROJECT_ROOT = Path(__file__).resolve().parents[3]
_MATCH_FILE_RE = re.compile(r"(?:^|/)match_(\d+)\.json(?:\.gz)?$")


def build_run_report(
    date_str: str,
    bronze_root: Path | None = None,
    current_date: date | None = None,
) -> dict[str, Any]:
    """Reconcile one FotMob listing with its stored payloads without writing state."""
    date_id = _normalize_date(date_str)
    today = current_date or date.today()
    target_date = datetime.strptime(date_id, "%Y%m%d").date()
    if target_date > today:
        raise ValueError(f"future dates cannot be reported: {date_id}")

    aspect = "live" if target_date == today else "historical"
    root = _resolve_bronze_root(bronze_root)
    listing_path = root / aspect / "daily_listings" / date_id[:6] / date_id / "matches.json"
    matches_dir = root / aspect / "matches" / date_id[:6] / date_id
    archive_path = matches_dir / f"{date_id}_matches.tar"

    evidence = {
        "listing": _display_path(listing_path),
        "matches_directory": _display_path(matches_dir),
        "archive": _display_path(archive_path),
    }
    if not listing_path.is_file():
        summary = _summary()
        return {
            "schema_version": "v1",
            "source": "fotmob",
            "date": date_id,
            "aspect": aspect,
            "overall_status": "not_started",
            "summary": summary,
            "inventory": {
                "listing_present": False,
                "scraped_at": None,
                "total": 0,
                "duplicate_match_ids": [],
            },
            "storage": _storage_summary(matches_dir, set(), set()),
            "findings": ["No FotMob daily listing exists for this date."],
            "next_steps": [f"python3 scripts/bronze/scrape_fotmob.py {date_id}"],
            "evidence": evidence,
        }

    listing = _load_listing(listing_path)
    raw_ids = listing.get("match_ids") or []
    if not isinstance(raw_ids, list):
        raise ValueError(f"FotMob listing match_ids must be a list: {listing_path}")
    normalized_ids = [_normalize_match_id(value, listing_path) for value in raw_ids]
    expected_ids = set(normalized_ids)
    duplicate_ids = sorted(
        match_id for match_id, count in Counter(normalized_ids).items() if count > 1
    )
    listing_storage = listing.get("storage") or {}
    if not isinstance(listing_storage, dict):
        raise ValueError(f"FotMob listing storage must be an object: {listing_path}")
    unavailable_ids = {
        _normalize_match_id(value, listing_path)
        for value in listing_storage.get("unavailable_match_ids") or []
    }.intersection(expected_ids)

    storage = _storage_summary(matches_dir, expected_ids, unavailable_ids)
    stored_ids = set(storage["stored_match_ids"])
    failed_ids = {
        _normalize_match_id(value, listing_path)
        for value in listing_storage.get("failed_match_ids") or []
    }.intersection(expected_ids)
    completed_ids = stored_ids.intersection(expected_ids).union(unavailable_ids)
    missing_ids = expected_ids - completed_ids
    discovered = len(expected_ids)
    completed = len(completed_ids)
    progress_pct = _percentage(completed, discovered, empty_is_complete=True)

    findings: list[str] = []
    listed_date = str(listing.get("date") or "")
    declared_total = listing.get("total_matches")
    if listed_date and listed_date != date_id:
        findings.append(
            f"The listing date is {listed_date}, but its storage partition is {date_id}."
        )
    if duplicate_ids:
        findings.append(f"The listing contains {len(duplicate_ids)} duplicate match ID(s).")
    if declared_total is not None and declared_total != discovered:
        findings.append(
            f"The listing declares {declared_total} matches but contains {discovered} unique IDs."
        )
    if missing_ids:
        findings.append(
            f"{len(missing_ids)} listed match payload(s) are missing from FotMob storage."
        )
    if unavailable_ids:
        findings.append(
            f"{len(unavailable_ids)} match(es) are terminally unavailable and count as skipped."
        )
    if storage["extra_match_ids"]:
        findings.append(
            f"{len(storage['extra_match_ids'])} stored payload(s) are not present in the listing."
        )
    findings.extend(storage["read_errors"])
    if aspect == "live" and not missing_ids:
        findings.append(
            "The Live snapshot is complete for now, but only Historical artifacts are admitted "
            "to FotMob Bronze loading."
        )
    if not findings:
        findings.append("The FotMob listing and stored match payloads reconcile cleanly.")

    has_contract_issue = bool(
        duplicate_ids
        or (declared_total is not None and declared_total != discovered)
        or (listed_date and listed_date != date_id)
        or storage["extra_match_ids"]
        or storage["read_errors"]
    )
    bronze_ready = not missing_ids and aspect == "historical" and not has_contract_issue
    if storage["read_errors"]:
        overall_status = "error"
    elif missing_ids or has_contract_issue:
        overall_status = "attention_required"
    elif aspect == "live":
        overall_status = "live_complete"
    else:
        overall_status = "complete"

    next_steps: list[str] = []
    if missing_ids or has_contract_issue:
        next_steps.append(f"python3 scripts/bronze/scrape_fotmob.py {date_id}")
    if bronze_ready:
        next_steps.append(
            f"python3 scripts/bronze/load_fotmob_bronze.py --date {date_id} --dry-run"
        )
    elif aspect == "live" and not missing_ids:
        next_steps.append("Re-run the report after the date moves to Historical storage.")

    summary = _summary(
        discovered=discovered,
        completed=completed,
        failed=len(failed_ids),
        skipped=len(unavailable_ids),
        remaining=len(missing_ids),
        progress_pct=progress_pct,
        artifact_files=storage["artifact_files"],
        storage_size_mb=storage["storage_size_mb"],
        bronze_admission_ready=bronze_ready,
    )
    return {
        "schema_version": "v1",
        "source": "fotmob",
        "date": date_id,
        "aspect": aspect,
        "overall_status": overall_status,
        "summary": summary,
        "inventory": {
            "listing_present": True,
            "scraped_at": listing.get("scraped_at"),
            "total": discovered,
            "declared_total": declared_total,
            "duplicate_match_ids": duplicate_ids,
        },
        "storage": storage,
        "findings": findings,
        "next_steps": next_steps,
        "evidence": evidence,
    }


def _resolve_bronze_root(bronze_root: Path | None) -> Path:
    configured = Path(bronze_root or get_settings().fotmob.storage.bronze_path)
    return configured if configured.is_absolute() else PROJECT_ROOT / configured


def _load_listing(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        payload = json.load(source)
    if not isinstance(payload, dict):
        raise ValueError(f"FotMob listing must be a JSON object: {path}")
    return payload


def _storage_summary(
    matches_dir: Path, expected_ids: set[str], unavailable_ids: set[str]
) -> dict[str, Any]:
    individual_ids: set[str] = set()
    archived_ids: set[str] = set()
    read_errors: list[str] = []
    physical_size_bytes = 0

    if matches_dir.is_dir():
        for path in sorted(matches_dir.glob("match_*.json")) + sorted(
            matches_dir.glob("match_*.json.gz")
        ):
            match_id = _match_id_from_name(path.name)
            if match_id is None:
                continue
            individual_ids.add(match_id)
            try:
                physical_size_bytes += path.stat().st_size
            except OSError as exc:
                read_errors.append(f"Unable to inspect {path.name}: {exc}")

        archive_path = matches_dir / f"{matches_dir.name}_matches.tar"
        if archive_path.is_file():
            try:
                physical_size_bytes += archive_path.stat().st_size
                with tarfile.open(archive_path, "r") as archive:
                    for member in archive.getmembers():
                        match_id = _match_id_from_name(member.name)
                        if match_id is not None:
                            archived_ids.add(match_id)
            except (OSError, tarfile.TarError) as exc:
                read_errors.append(f"Unable to inspect {archive_path.name}: {exc}")

    stored_ids = individual_ids.union(archived_ids)
    expected_stored_ids = stored_ids.intersection(expected_ids)
    missing_ids = expected_ids - expected_stored_ids - unavailable_ids
    return {
        "directory_present": matches_dir.is_dir(),
        "artifact_files": len(expected_stored_ids),
        "individual_files": len(individual_ids),
        "archived_files": len(archived_ids),
        "storage_size_bytes": physical_size_bytes,
        "storage_size_mb": round(physical_size_bytes / (1024**2), 2),
        "stored_match_ids": sorted(stored_ids),
        "missing_match_ids": sorted(missing_ids),
        "unavailable_match_ids": sorted(unavailable_ids),
        "extra_match_ids": sorted(stored_ids - expected_ids),
        "read_errors": read_errors,
    }


def _match_id_from_name(name: str) -> str | None:
    match = _MATCH_FILE_RE.search(name)
    return match.group(1) if match else None


def _normalize_match_id(value: Any, path: Path) -> str:
    match_id = str(value).strip()
    if not match_id.isdigit():
        raise ValueError(f"FotMob listing contains an invalid match ID {value!r}: {path}")
    return match_id


def _normalize_date(value: str) -> str:
    date_id = str(value).strip()
    if len(date_id) != 8 or not date_id.isdigit():
        raise ValueError(f"date must use YYYYMMDD format: {value}")
    datetime.strptime(date_id, "%Y%m%d")
    return date_id


def _summary(
    discovered: int = 0,
    completed: int = 0,
    failed: int = 0,
    skipped: int = 0,
    remaining: int = 0,
    progress_pct: float = 0.0,
    artifact_files: int = 0,
    storage_size_mb: float = 0.0,
    bronze_admission_ready: bool = False,
) -> dict[str, Any]:
    return {
        "discovered": discovered,
        "completed": completed,
        "failed": failed,
        "skipped": skipped,
        "remaining": remaining,
        "progress_pct": progress_pct,
        "artifact_files": artifact_files,
        "storage_size_mb": storage_size_mb,
        "bronze_admission_ready": bronze_admission_ready,
    }


def _percentage(numerator: int, denominator: int, empty_is_complete: bool = False) -> float:
    if denominator:
        return round((numerator / denominator) * 100, 2)
    return 100.0 if empty_is_complete else 0.0


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(PROJECT_ROOT))
    except ValueError:
        return str(path)
