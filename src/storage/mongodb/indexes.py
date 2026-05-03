"""MongoDB index bootstrap for Orbit content catalog."""

from typing import Dict, List

from pymongo import ASCENDING, DESCENDING
from pymongo.database import Database

from .collections import (
    CHANNEL_TEMPLATES_COLLECTION,
    CONTENT_VERSIONS_COLLECTION,
    SCENARIO_SIGNAL_MAP_COLLECTION,
    SCENARIOS_COLLECTION,
    SIGNALS_COLLECTION,
)


def ensure_content_catalog_indexes(database: Database) -> Dict[str, List[str]]:
    """Create required indexes and return created index names per collection."""
    created = {}

    created[SIGNALS_COLLECTION] = [
        database[SIGNALS_COLLECTION].create_index([("signal_id", ASCENDING)], unique=True),
        database[SIGNALS_COLLECTION].create_index([("status", ASCENDING), ("updated_at", DESCENDING)]),
        database[SIGNALS_COLLECTION].create_index(
            [("entity", ASCENDING), ("family", ASCENDING), ("subfamily", ASCENDING), ("grain", ASCENDING)]
        ),
        database[SIGNALS_COLLECTION].create_index([("source_path", ASCENDING)]),
    ]

    created[SCENARIOS_COLLECTION] = [
        database[SCENARIOS_COLLECTION].create_index([("scenario_id", ASCENDING)], unique=True),
        database[SCENARIOS_COLLECTION].create_index(
            [("status", ASCENDING), ("updated_at", DESCENDING)]
        ),
        database[SCENARIOS_COLLECTION].create_index([("tags", ASCENDING)]),
    ]

    created[CHANNEL_TEMPLATES_COLLECTION] = [
        database[CHANNEL_TEMPLATES_COLLECTION].create_index(
            [("template_id", ASCENDING)],
            unique=True,
        ),
        database[CHANNEL_TEMPLATES_COLLECTION].create_index(
            [("content_type", ASCENDING), ("channel", ASCENDING), ("status", ASCENDING)]
        ),
        database[CHANNEL_TEMPLATES_COLLECTION].create_index(
            [("scenario_id", ASCENDING), ("signal_id", ASCENDING)]
        ),
    ]

    created[CONTENT_VERSIONS_COLLECTION] = [
        database[CONTENT_VERSIONS_COLLECTION].create_index(
            [("content_type", ASCENDING), ("content_id", ASCENDING), ("version", DESCENDING)],
            unique=True,
        ),
        database[CONTENT_VERSIONS_COLLECTION].create_index(
            [("published_at", DESCENDING)]
        ),
    ]

    created[SCENARIO_SIGNAL_MAP_COLLECTION] = [
        database[SCENARIO_SIGNAL_MAP_COLLECTION].create_index(
            [("scenario_id", ASCENDING), ("signal_id", ASCENDING)],
            unique=True,
        ),
        database[SCENARIO_SIGNAL_MAP_COLLECTION].create_index([("signal_id", ASCENDING)]),
    ]

    return created
