import contextlib
import json
import os
import tempfile
import threading
from collections.abc import Callable, Mapping
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

from src.oddspedia.scraping.logging import get_logger

logger = get_logger(__name__)

# Lock for thread-safe manifest read-modify-write operations inside this process.
_manifest_lock = threading.Lock()

_MANIFEST_FIELDS = {
    "date",
    "sport",
    "total",
    "done",
    "failed",
    "skipped",
    "incomplete",
    "in_progress",
    "retries",
    "discovery",
    "priority_run",
    "metrics",
    "completed_progress",
    "started_at",
    "updated_at",
}


def _utc_now() -> datetime:
    return datetime.now(UTC)


class ManifestCorruptError(ValueError):
    """Raised when a persisted manifest cannot be trusted or reconstructed."""


@dataclass
class ScrapeManifest:
    """Manifest for tracking full-inventory and priority-selected progress.

    ``total`` is the full accepted discovery inventory. The currently selected
    scrape scope remains in ``priority_run.selected_count``. Unknown top-level
    fields are retained so a read-modify-write cycle cannot erase metadata
    authored by a newer compatible scraper.
    """

    date: str
    sport: str = "football"
    total: int = 0
    done: list[str] = field(default_factory=list)
    failed: list[str] = field(default_factory=list)
    skipped: dict[str, dict] = field(default_factory=dict)
    incomplete: list[str] = field(default_factory=list)
    in_progress: dict[str, str] = field(default_factory=dict)
    retries: dict[str, dict] = field(default_factory=dict)
    discovery: dict = field(default_factory=dict)
    priority_run: dict = field(default_factory=dict)
    metrics: dict = field(default_factory=dict)
    started_at: str = field(default_factory=lambda: _utc_now().isoformat())
    updated_at: str = field(default_factory=lambda: _utc_now().isoformat())
    extra_fields: dict[str, Any] = field(default_factory=dict, repr=False)

    @property
    def completed_count(self) -> int:
        return len(self.done)

    @property
    def failed_count(self) -> int:
        return len(self.failed)

    @property
    def incomplete_count(self) -> int:
        return len(self.incomplete)

    @property
    def skipped_count(self) -> int:
        return len(self.skipped)

    @property
    def completed_progress(self) -> float:
        if self.total == 0:
            return 0.0
        return round(((len(self.done) + len(self.skipped)) / self.total) * 100, 2)

    @property
    def remaining(self) -> int:
        return self.total - len(self.done) - len(self.failed) - len(self.skipped)

    @property
    def is_complete(self) -> bool:
        return (
            len(self.done) + len(self.failed) + len(self.skipped) >= self.total and self.total > 0
        )

    def mark_done(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id not in self.done:
            self.done.append(match_id)
        if match_id in self.failed:
            self.failed.remove(match_id)
        if match_id in self.incomplete:
            self.incomplete.remove(match_id)
        self.skipped.pop(match_id, None)
        self._clear_match_in_progress(match_id)
        self.clear_retries(match_id)
        self.updated_at = _utc_now().isoformat()

    def mark_failed(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        if match_id in self.incomplete:
            self.incomplete.remove(match_id)
        if match_id not in self.failed:
            self.failed.append(match_id)
        self.skipped.pop(match_id, None)
        self._clear_match_in_progress(match_id)
        self.updated_at = _utc_now().isoformat()

    def mark_incomplete(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        if match_id in self.failed:
            self.failed.remove(match_id)
        if match_id not in self.incomplete:
            self.incomplete.append(match_id)
        self._clear_match_in_progress(match_id)
        self.updated_at = _utc_now().isoformat()

    def mark_skipped(self, match_id: str, reason: str, **details) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        if match_id in self.failed:
            self.failed.remove(match_id)
        if match_id in self.incomplete:
            self.incomplete.remove(match_id)
        self.skipped[match_id] = {
            "reason": str(reason),
            "details": details,
            "updated_at": _utc_now().isoformat(),
        }
        self._clear_match_in_progress(match_id)
        self.clear_retries(match_id)
        self.updated_at = _utc_now().isoformat()

    def mark_pending(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        self.updated_at = _utc_now().isoformat()

    def set_in_progress(self, match_id: str, worker_id: str = "main") -> None:
        self.in_progress[str(worker_id)] = str(match_id)
        self.updated_at = _utc_now().isoformat()

    def clear_in_progress(self, worker_id: str | None = None) -> None:
        if worker_id is None:
            self.in_progress = {}
        else:
            self.in_progress.pop(str(worker_id), None)
        self.updated_at = _utc_now().isoformat()

    def record_retry(self, match_id: str, error: str) -> None:
        match_id = str(match_id)
        entry = self.retries.get(match_id, {"count": 0, "last_error": ""})
        entry["count"] += 1
        entry["last_error"] = str(error)[:500]
        self.retries[match_id] = entry
        self.updated_at = _utc_now().isoformat()

    def get_retry_count(self, match_id: str) -> int:
        entry = self.retries.get(str(match_id))
        return entry["count"] if entry else 0

    def clear_retries(self, match_id: str) -> None:
        self.retries.pop(str(match_id), None)
        self.updated_at = _utc_now().isoformat()

    def record_discovery(self, result: dict) -> None:
        """Persist the acceptance or recovery state of event discovery."""
        previous = self.discovery or {}
        accepted = bool(result.get("complete"))
        no_events = accepted and bool(result.get("empty_confirmed"))
        now = _utc_now().isoformat()
        attempts = 0 if accepted else int(previous.get("attempts", 0)) + 1
        entry = {
            "status": "no_events"
            if no_events
            else "accepted"
            if accepted
            else "rescrape_candidate",
            "reasons": list(result.get("anomalies") or []),
            "expected_pages": result.get("expected_pages"),
            "observed_pages": result.get("observed_pages"),
            "match_count": result.get("match_count", 0),
            "dom_count": result.get("dom_count", 0),
            "empty_confirmed": bool(result.get("empty_confirmed")),
            "source": result.get("source", "sport_component"),
            "inventory_checksum": result.get("inventory_checksum", ""),
            "attempts": attempts,
            "snapshot": result.get("snapshot", ""),
            "updated_at": now,
        }
        if not accepted:
            delay_minutes = min(60, 5 * (2 ** max(0, attempts - 1)))
            entry["next_attempt_at"] = result.get(
                "next_attempt_at", (_utc_now() + timedelta(minutes=delay_minutes)).isoformat()
            )
        self.discovery = entry
        self.updated_at = now

    def record_priority_run(self, summary: dict) -> None:
        """Persist the audit summary for the priority artifact used by a run."""
        self.priority_run = dict(summary)
        self.updated_at = _utc_now().isoformat()

    def update_metrics(self, snapshot: dict) -> None:
        """Store the latest in-memory run summary with this date's progress."""
        self.metrics = dict(snapshot)
        self.updated_at = _utc_now().isoformat()

    @property
    def in_progress_ids(self) -> list[str]:
        return list(self.in_progress.values())

    def _clear_match_in_progress(self, match_id: str) -> None:
        match_id = str(match_id)
        self.in_progress = {
            worker_id: active_id
            for worker_id, active_id in self.in_progress.items()
            if str(active_id) != match_id
        }

    def to_dict(self) -> dict:
        payload = deepcopy(self.extra_fields)
        payload.update(
            {
                "date": self.date,
                "sport": self.sport,
                "total": self.total,
                "done": self.done,
                "failed": self.failed,
                "skipped": self.skipped,
                "incomplete": self.incomplete,
                "in_progress": self.in_progress,
                "retries": self.retries,
                "discovery": self.discovery,
                "priority_run": self.priority_run,
                "metrics": self.metrics,
                "completed_progress": self.completed_progress,
                "started_at": self.started_at,
                "updated_at": self.updated_at,
            }
        )
        _validate_manifest_document(payload)
        return payload

    @classmethod
    def from_dict(cls, data: dict) -> "ScrapeManifest":
        _validate_manifest_document(data)
        return cls(
            date=str(data.get("date", "")),
            sport=str(data.get("sport", "football")),
            total=int(data.get("total", 0)),
            done=_normalize_id_list(data.get("done")),
            failed=_normalize_id_list(data.get("failed")),
            skipped=deepcopy(data.get("skipped", {})),
            incomplete=_normalize_id_list(data.get("incomplete")),
            in_progress=_normalize_in_progress(data.get("in_progress")),
            retries=deepcopy(data.get("retries", {})),
            discovery=deepcopy(data.get("discovery", {})),
            priority_run=deepcopy(data.get("priority_run", {})),
            metrics=deepcopy(data.get("metrics", {})),
            started_at=str(data.get("started_at", _utc_now().isoformat())),
            updated_at=str(data.get("updated_at", _utc_now().isoformat())),
            extra_fields={
                key: deepcopy(value) for key, value in data.items() if key not in _MANIFEST_FIELDS
            },
        )


def _validate_manifest_document(data: Mapping[str, Any]) -> None:
    """Fail early on malformed field types while accepting legacy state overlap."""
    if not isinstance(data, Mapping):
        raise TypeError("manifest root must be an object")
    if not isinstance(data.get("date"), str) or not str(data.get("date")).strip():
        raise ValueError("manifest date must be a non-empty string")
    if "sport" in data and not isinstance(data["sport"], str):
        raise TypeError("manifest sport must be a string")
    total = data.get("total", 0)
    if isinstance(total, bool) or not isinstance(total, int) or total < 0:
        raise TypeError("manifest total must be a non-negative integer")
    for field_name in ("done", "failed", "incomplete"):
        value = data.get(field_name, [])
        if not isinstance(value, list):
            raise TypeError(f"manifest {field_name} must be a list")
        if any(isinstance(item, (bool, dict, list)) or item is None for item in value):
            raise TypeError(f"manifest {field_name} values must be scalar event IDs")
    for field_name in ("skipped", "retries", "discovery", "priority_run", "metrics"):
        if not isinstance(data.get(field_name, {}), Mapping):
            raise TypeError(f"manifest {field_name} must be an object")
    in_progress = data.get("in_progress", {})
    if not isinstance(in_progress, (Mapping, list, str, int)) and in_progress is not None:
        raise TypeError("manifest in_progress must be an object or a supported legacy value")
    for field_name in ("started_at", "updated_at"):
        if field_name in data and not isinstance(data[field_name], str):
            raise TypeError(f"manifest {field_name} must be a string")
    completed_progress = data.get("completed_progress")
    if completed_progress is not None and (
        isinstance(completed_progress, bool) or not isinstance(completed_progress, (int, float))
    ):
        raise TypeError("manifest completed_progress must be numeric")


def _normalize_id_list(value) -> list[str]:
    if not value:
        return []
    return [str(item) for item in value]


def get_manifest_path(date_str: str, sport: str = "football") -> str:
    """Return the path to the manifest file for a given date."""
    from src.oddspedia.scraping.config import get_manifest_file

    return get_manifest_file(date_str, sport=sport)


def _normalize_in_progress(value) -> dict[str, str]:
    """Return worker-keyed in-progress state, accepting legacy manifests."""
    if not value:
        return {}
    if isinstance(value, dict):
        return {str(worker_id): str(match_id) for worker_id, match_id in value.items() if match_id}
    if isinstance(value, list):
        return {str(index): str(match_id) for index, match_id in enumerate(value) if match_id}
    return {"main": str(value)}


def load_manifest(date_str: str, sport: str = "football") -> ScrapeManifest | None:
    """Load manifest from disk if it exists."""
    path = get_manifest_path(date_str, sport=sport)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict) or not data.get("date"):
            raise ValueError("manifest root must be an object with a date")
        manifest = ScrapeManifest.from_dict(data)
        logger.info(
            "manifest_loaded",
            sport=sport,
            date=date_str,
            total=manifest.total,
            done=manifest.completed_count,
            failed=manifest.failed_count,
            incomplete=manifest.incomplete_count,
            completed_progress=manifest.completed_progress,
        )
        return manifest
    except Exception as exc:
        logger.error("manifest_load_failed", date=date_str, error=str(exc))
        raise ManifestCorruptError(f"Oddspedia manifest is corrupt: {path}") from exc


def save_manifest(manifest: ScrapeManifest) -> None:
    """Save manifest to disk atomically via write-then-replace."""
    path = get_manifest_path(manifest.date, sport=manifest.sport)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(manifest.to_dict(), f, indent=2)
            f.flush()
            os.fsync(fd)
        os.replace(tmp_path, path)
    except Exception:
        with contextlib.suppress(OSError):
            os.unlink(tmp_path)
        raise
    logger.debug("manifest_saved", path=path, completed_progress=manifest.completed_progress)


def create_manifest(date_str: str, total: int, sport: str = "football") -> ScrapeManifest:
    """Create a new manifest for a scraping run."""
    manifest = ScrapeManifest(date=date_str, sport=sport, total=total)
    save_manifest(manifest)
    logger.info("manifest_created", sport=sport, date=date_str, total=total)
    return manifest


def update_manifest(
    date_str: str,
    modifier: Callable[[ScrapeManifest], None],
    sport: str = "football",
) -> ScrapeManifest | None:
    """Thread-safe manifest update: load, apply *modifier*, save.

    Args:
        date_str: The target date string.
        modifier: A callable that receives the loaded ``ScrapeManifest``
                  and mutates it in-place.
    """
    with _manifest_lock:
        manifest = load_manifest(date_str, sport=sport)
        if manifest is None:
            logger.warning("manifest_not_found_during_update", date=date_str)
            return None
        modifier(manifest)
        save_manifest(manifest)
        return manifest
