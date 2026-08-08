"""Cross-process overlap protection for one Oddspedia sport/date workflow."""

import fcntl
import json
import os
import socket
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Optional

from src.oddspedia.scraping.config import DATA_DIR, normalize_date, normalize_sport


class OddspediaRunLockedError(RuntimeError):
    """Raised when another process owns the requested sport/date workflow."""


@contextmanager
def oddspedia_date_lock(
    date_str: str,
    *,
    sport: str = "football",
    operation: str,
    timeout_seconds: float = 0,
    lock_root: Optional[Path] = None,
) -> Iterator[Path]:
    """Hold an exclusive process lock for one sport/date until the context exits."""
    date_id = normalize_date(date_str)
    sport_id = normalize_sport(sport)
    if not operation or not operation.replace("-", "_").isidentifier():
        raise ValueError(f"invalid Oddspedia lock operation: {operation!r}")
    root = Path(lock_root) if lock_root is not None else Path(DATA_DIR) / "locks"
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / f"{sport_id}_{date_id}.lock"
    lock_file = lock_path.open("a+", encoding="utf-8")
    deadline = time.monotonic() + max(0.0, timeout_seconds)
    try:
        while True:
            try:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError as exc:
                if time.monotonic() >= deadline:
                    lock_file.seek(0)
                    owner = lock_file.read().strip() or "unknown owner"
                    raise OddspediaRunLockedError(
                        f"Oddspedia {sport_id} {date_id} is already active: {owner}"
                    ) from exc
                time.sleep(0.1)

        metadata = {
            "date": date_id,
            "sport": sport_id,
            "operation": operation,
            "pid": os.getpid(),
            "host": socket.gethostname(),
            "started_at": datetime.now(timezone.utc).isoformat(),
        }
        lock_file.seek(0)
        lock_file.truncate()
        json.dump(metadata, lock_file, sort_keys=True)
        lock_file.flush()
        os.fsync(lock_file.fileno())
        yield lock_path
    finally:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        finally:
            lock_file.close()
