"""Signals repository for DepthMark content catalog."""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from pymongo.collection import Collection
from pymongo.database import Database

from ..collections import SIGNALS_COLLECTION


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


class SignalsRepository:
    """CRUD-like operations for signal documents."""

    def __init__(self, database: Database):
        self.collection: Collection = database[SIGNALS_COLLECTION]

    def upsert_signal(self, signal_id: str, payload: Dict[str, Any]) -> None:
        update_doc = {
            "$set": {
                **payload,
                "signal_id": signal_id,
                "updated_at": _now_utc(),
            },
            "$setOnInsert": {"created_at": _now_utc()},
        }
        self.collection.update_one({"signal_id": signal_id}, update_doc, upsert=True)

    def get_signal(self, signal_id: str) -> Optional[Dict[str, Any]]:
        return self.collection.find_one({"signal_id": signal_id}, {"_id": 0})

    def list_signals(self, status: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        query: Dict[str, Any] = {}
        if status:
            query["status"] = status
        cursor = self.collection.find(query, {"_id": 0}).sort("updated_at", -1).limit(limit)
        return list(cursor)

