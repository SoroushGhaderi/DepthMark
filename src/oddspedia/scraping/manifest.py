import json
import os
import tempfile
import threading
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Callable, Dict, List, Optional

from src.oddspedia.scraping.logging import get_logger

logger = get_logger(__name__)

# Lock for thread-safe manifest read-modify-write operations inside this process.
_manifest_lock = threading.Lock()


@dataclass
class ScrapeManifest:
    """Manifest for tracking incremental scraping progress."""

    date: str
    sport: str = "football"
    total: int = 0
    done: List[str] = field(default_factory=list)
    failed: List[str] = field(default_factory=list)
    skipped: Dict[str, Dict] = field(default_factory=dict)
    incomplete: List[str] = field(default_factory=list)
    in_progress: Dict[str, str] = field(default_factory=dict)
    retries: Dict[str, Dict] = field(default_factory=dict)
    discovery: Dict = field(default_factory=dict)
    metrics: Dict = field(default_factory=dict)
    started_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())

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
        return len(self.done) + len(self.failed) + len(self.skipped) >= self.total and self.total > 0

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
        self.updated_at = datetime.now().isoformat()

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
        self.updated_at = datetime.now().isoformat()

    def mark_incomplete(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        if match_id in self.failed:
            self.failed.remove(match_id)
        if match_id not in self.incomplete:
            self.incomplete.append(match_id)
        self._clear_match_in_progress(match_id)
        self.updated_at = datetime.now().isoformat()

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
            "updated_at": datetime.now().isoformat(),
        }
        self._clear_match_in_progress(match_id)
        self.clear_retries(match_id)
        self.updated_at = datetime.now().isoformat()

    def mark_pending(self, match_id: str) -> None:
        match_id = str(match_id)
        if match_id in self.done:
            self.done.remove(match_id)
        self.updated_at = datetime.now().isoformat()

    def set_in_progress(self, match_id: str, worker_id: str = "main") -> None:
        self.in_progress[str(worker_id)] = str(match_id)
        self.updated_at = datetime.now().isoformat()

    def clear_in_progress(self, worker_id: Optional[str] = None) -> None:
        if worker_id is None:
            self.in_progress = {}
        else:
            self.in_progress.pop(str(worker_id), None)
        self.updated_at = datetime.now().isoformat()

    def record_retry(self, match_id: str, error: str) -> None:
        match_id = str(match_id)
        entry = self.retries.get(match_id, {"count": 0, "last_error": ""})
        entry["count"] += 1
        entry["last_error"] = str(error)[:500]
        self.retries[match_id] = entry
        self.updated_at = datetime.now().isoformat()

    def get_retry_count(self, match_id: str) -> int:
        entry = self.retries.get(str(match_id))
        return entry["count"] if entry else 0

    def clear_retries(self, match_id: str) -> None:
        self.retries.pop(str(match_id), None)
        self.updated_at = datetime.now().isoformat()

    def record_discovery(self, result: Dict) -> None:
        """Persist the acceptance or recovery state of event discovery."""
        previous = self.discovery or {}
        accepted = bool(result.get("complete"))
        now = datetime.now().isoformat()
        attempts = 0 if accepted else int(previous.get("attempts", 0)) + 1
        entry = {
            "status": "accepted" if accepted else "rescrape_candidate",
            "reasons": list(result.get("anomalies") or []),
            "expected_pages": result.get("expected_pages"),
            "observed_pages": result.get("observed_pages"),
            "match_count": result.get("match_count", 0),
            "dom_count": result.get("dom_count", 0),
            "attempts": attempts,
            "snapshot": result.get("snapshot", ""),
            "updated_at": now,
        }
        if not accepted:
            delay_minutes = min(60, 5 * (2 ** max(0, attempts - 1)))
            entry["next_attempt_at"] = result.get(
                "next_attempt_at", (datetime.now() + timedelta(minutes=delay_minutes)).isoformat()
            )
        self.discovery = entry
        self.updated_at = now

    def update_metrics(self, snapshot: Dict) -> None:
        """Store the latest in-memory run summary with this date's progress."""
        self.metrics = dict(snapshot)
        self.updated_at = datetime.now().isoformat()

    @property
    def in_progress_ids(self) -> List[str]:
        return list(self.in_progress.values())

    def _clear_match_in_progress(self, match_id: str) -> None:
        match_id = str(match_id)
        self.in_progress = {
            worker_id: active_id
            for worker_id, active_id in self.in_progress.items()
            if str(active_id) != match_id
        }

    def to_dict(self) -> Dict:
        return {
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
            "metrics": self.metrics,
            "completed_progress": self.completed_progress,
            "started_at": self.started_at,
            "updated_at": self.updated_at,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> "ScrapeManifest":
        return cls(
            date=data.get("date", ""),
            sport=data.get("sport", "football"),
            total=data.get("total", 0),
            done=data.get("done", []),
            failed=data.get("failed", []),
            skipped=data.get("skipped", {}),
            incomplete=data.get("incomplete", []),
            in_progress=_normalize_in_progress(data.get("in_progress")),
            retries=data.get("retries", {}),
            discovery=data.get("discovery", {}),
            metrics=data.get("metrics", {}),
            started_at=data.get("started_at", datetime.now().isoformat()),
            updated_at=data.get("updated_at", datetime.now().isoformat()),
        )


def get_manifest_path(date_str: str, sport: str = "football") -> str:
    """Return the path to the manifest file for a given date."""
    from src.oddspedia.scraping.config import get_manifest_file
    return get_manifest_file(date_str, sport=sport)


def _normalize_in_progress(value) -> Dict[str, str]:
    """Return worker-keyed in-progress state, accepting legacy manifests."""
    if not value:
        return {}
    if isinstance(value, dict):
        return {str(worker_id): str(match_id) for worker_id, match_id in value.items() if match_id}
    if isinstance(value, list):
        return {str(index): str(match_id) for index, match_id in enumerate(value) if match_id}
    return {"main": str(value)}


def load_manifest(date_str: str, sport: str = "football") -> Optional[ScrapeManifest]:
    """Load manifest from disk if it exists."""
    path = get_manifest_path(date_str, sport=sport)
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
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
    except Exception as e:
        logger.warning("manifest_load_failed", date=date_str, error=str(e))
        return None


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
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
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
) -> Optional[ScrapeManifest]:
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
