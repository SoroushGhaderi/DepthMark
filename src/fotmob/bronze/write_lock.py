"""The single FotMob Bronze write lock (ADR 0032).

Every command that writes FotMob Bronze (load, replace, rebuild, removal) holds
this exclusive, non-blocking lock for its whole run. A second writer fails
immediately, naming the holder, instead of interleaving with it: a rebuild would
otherwise swap away rows a concurrent load inserted, and a removal could delete
rows a concurrent load just wrote. ``--dry-run`` writes nothing and takes no lock.
"""

import fcntl
import json
import os
import socket
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Optional

DEFAULT_LOCK_PATH = Path(__file__).resolve().parents[3] / "data" / "locks" / "fotmob_bronze.lock"


class BronzeWriteLockedError(RuntimeError):
    """Raised when another process holds the FotMob Bronze write lock."""


@contextmanager
def fotmob_bronze_write_lock(operation: str, lock_path: Optional[Path] = None) -> Iterator[Path]:
    """Hold the FotMob Bronze write lock until the context exits, or fail at once."""
    path = Path(lock_path) if lock_path is not None else DEFAULT_LOCK_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = path.open("a+", encoding="utf-8")
    try:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            lock_file.seek(0)
            holder = lock_file.read().strip() or "an unknown process"
            raise BronzeWriteLockedError(
                f"FotMob Bronze is being written by {holder}; "
                f"{operation} did not start. Retry when that run finishes."
            ) from error
        lock_file.seek(0)
        lock_file.truncate()
        json.dump(
            {
                "operation": operation,
                "pid": os.getpid(),
                "host": socket.gethostname(),
                "started_at": datetime.now(timezone.utc).isoformat(),
            },
            lock_file,
            sort_keys=True,
        )
        lock_file.flush()
        os.fsync(lock_file.fileno())
        yield path
    finally:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        finally:
            lock_file.close()
