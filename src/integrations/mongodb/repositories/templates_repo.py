"""Channel template repository for DepthMark content catalog."""

from datetime import UTC, datetime
from typing import Any

from pymongo.collection import Collection
from pymongo.database import Database

from ..collections import CHANNEL_TEMPLATES_COLLECTION


def _now_utc() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


class TemplatesRepository:
    """CRUD-like operations for template documents."""

    def __init__(self, database: Database):
        self.collection: Collection = database[CHANNEL_TEMPLATES_COLLECTION]

    def upsert_template(self, template_id: str, payload: dict[str, Any]) -> None:
        update_doc = {
            "$set": {
                **payload,
                "template_id": template_id,
                "updated_at": _now_utc(),
            },
            "$setOnInsert": {"created_at": _now_utc()},
        }
        self.collection.update_one({"template_id": template_id}, update_doc, upsert=True)

    def get_template(self, template_id: str) -> dict[str, Any] | None:
        return self.collection.find_one({"template_id": template_id}, {"_id": 0})

    def list_templates(
        self,
        channel: str | None = None,
        content_type: str | None = None,
        status: str | None = None,
        limit: int = 200,
    ) -> list[dict[str, Any]]:
        query: dict[str, Any] = {}
        if channel:
            query["channel"] = channel
        if content_type:
            query["content_type"] = content_type
        if status:
            query["status"] = status
        cursor = self.collection.find(query, {"_id": 0}).sort("updated_at", -1).limit(limit)
        return list(cursor)
