"""MongoDB storage package for DepthMark content catalog."""

from .client import MongoDBClient, build_mongodb_uri, get_mongodb_client
from .collections import (
    CHANNEL_TEMPLATES_COLLECTION,
    CONTENT_VERSIONS_COLLECTION,
    SCENARIO_SIGNAL_MAP_COLLECTION,
    SCENARIOS_COLLECTION,
    SIGNALS_COLLECTION,
)
from .indexes import ensure_content_catalog_indexes

__all__ = [
    "MongoDBClient",
    "build_mongodb_uri",
    "get_mongodb_client",
    "ensure_content_catalog_indexes",
    "SIGNALS_COLLECTION",
    "SCENARIOS_COLLECTION",
    "CHANNEL_TEMPLATES_COLLECTION",
    "CONTENT_VERSIONS_COLLECTION",
    "SCENARIO_SIGNAL_MAP_COLLECTION",
]

