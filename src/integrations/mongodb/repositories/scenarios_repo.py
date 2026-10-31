"""Scenarios repository for DepthMark content catalog."""

from datetime import UTC, datetime
from typing import Any

from pymongo.collection import Collection
from pymongo.database import Database

from ..collections import SCENARIOS_COLLECTION


def _now_utc() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


class ScenariosRepository:
    """CRUD-like operations for scenario documents."""

    def __init__(self, database: Database):
        self.collection: Collection = database[SCENARIOS_COLLECTION]

    def upsert_scenario(self, scenario_id: str, payload: dict[str, Any]) -> None:
        update_doc = {
            "$set": {
                **payload,
                "scenario_id": scenario_id,
                "updated_at": _now_utc(),
            },
            "$setOnInsert": {"created_at": _now_utc()},
        }
        self.collection.update_one({"scenario_id": scenario_id}, update_doc, upsert=True)

    def get_scenario(self, scenario_id: str) -> dict[str, Any] | None:
        return self.collection.find_one({"scenario_id": scenario_id}, {"_id": 0})

    def list_scenarios(self, status: str | None = None, limit: int = 100) -> list[dict[str, Any]]:
        query: dict[str, Any] = {}
        if status:
            query["status"] = status
        cursor = self.collection.find(query, {"_id": 0}).sort("updated_at", -1).limit(limit)
        return list(cursor)
