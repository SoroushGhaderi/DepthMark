"""Signals repository for DepthMark content catalog."""

from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional

from pymongo.collection import Collection
from pymongo.database import Database

from ..collections import SIGNALS_COLLECTION


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


class SignalsRepository:
    """Mirror-style operations for signal documents synced from catalogs."""

    def __init__(self, database: Database):
        self.collection: Collection = database[SIGNALS_COLLECTION]

    def list_signal_states(self) -> Dict[str, Dict[str, Any]]:
        """Return each stored signal's ``content_sha256`` and ``created_at`` by id."""
        projection = {"_id": 0, "signal_id": 1, "content_sha256": 1, "created_at": 1}
        return {
            document["signal_id"]: document
            for document in self.collection.find({}, projection)
            if "signal_id" in document
        }

    def replace_signal(
        self, document: Dict[str, Any], *, created_at: Optional[datetime] = None
    ) -> None:
        """Replace one signal document whole, keeping its original ``created_at``."""
        now = _now_utc()
        replacement = {**document, "created_at": created_at or now, "updated_at": now}
        self.collection.replace_one({"signal_id": document["signal_id"]}, replacement, upsert=True)

    def delete_signals(self, signal_ids: Iterable[str]) -> int:
        """Delete the documents of signals that no longer have a catalog."""
        signal_ids = list(signal_ids)
        if not signal_ids:
            return 0
        return self.collection.delete_many({"signal_id": {"$in": signal_ids}}).deleted_count

    def get_signal(self, signal_id: str) -> Optional[Dict[str, Any]]:
        return self.collection.find_one({"signal_id": signal_id}, {"_id": 0})

    def list_signals(self, status: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        query: Dict[str, Any] = {}
        if status:
            query["status"] = status
        cursor = self.collection.find(query, {"_id": 0}).sort("updated_at", -1).limit(limit)
        return list(cursor)
