"""MongoDB client helpers for Orbit content catalog."""

import os
from dataclasses import dataclass
from typing import Optional
from urllib.parse import quote_plus

from pymongo import MongoClient
from pymongo.database import Database

from ...utils.logging_utils import get_logger

logger = get_logger(__name__)


def build_mongodb_uri(
    host: str,
    port: int,
    username: Optional[str],
    password: Optional[str],
    database: str,
    auth_source: str = "admin",
) -> str:
    """Build a MongoDB URI from explicit parts."""
    if username and password:
        user_quoted = quote_plus(username)
        password_quoted = quote_plus(password)
        return (
            f"mongodb://{user_quoted}:{password_quoted}@{host}:{port}/{database}"
            f"?authSource={auth_source}"
        )
    return f"mongodb://{host}:{port}/{database}"


@dataclass
class MongoConnectionConfig:
    """Runtime MongoDB connection configuration."""

    host: str
    port: int
    username: Optional[str]
    password: Optional[str]
    database: str
    auth_source: str
    uri: Optional[str]

    @classmethod
    def from_env(cls) -> "MongoConnectionConfig":
        """Build configuration from environment variables."""
        return cls(
            host=os.getenv("MONGODB_HOST", "localhost"),
            port=int(os.getenv("MONGODB_PORT", "27017")),
            username=os.getenv("MONGODB_USER"),
            password=os.getenv("MONGODB_PASSWORD"),
            database=os.getenv("MONGODB_DATABASE", "orbit_content"),
            auth_source=os.getenv("MONGODB_AUTH_SOURCE", "admin"),
            uri=os.getenv("MONGODB_URI"),
        )

    def resolved_uri(self) -> str:
        """Return explicit URI override or one built from parts."""
        if self.uri:
            return self.uri
        return build_mongodb_uri(
            host=self.host,
            port=self.port,
            username=self.username,
            password=self.password,
            database=self.database,
            auth_source=self.auth_source,
        )


class MongoDBClient:
    """Thin wrapper around pymongo.MongoClient used by Orbit."""

    def __init__(self, config: Optional[MongoConnectionConfig] = None):
        self.config = config or MongoConnectionConfig.from_env()
        self._client: Optional[MongoClient] = None

    def connect(self) -> bool:
        """Connect and ping MongoDB server."""
        try:
            self._client = MongoClient(
                self.config.resolved_uri(),
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=10000,
                appname="pitchwise-orbit",
            )
            self._client.admin.command("ping")
            logger.info(
                "Connected to MongoDB",
                host=self.config.host,
                port=self.config.port,
                database=self.config.database,
            )
            return True
        except Exception as exc:
            logger.error("MongoDB connection failed", error=str(exc))
            self._client = None
            return False

    def disconnect(self) -> None:
        """Close MongoDB client."""
        if self._client is not None:
            self._client.close()
            self._client = None

    def get_database(self) -> Database:
        """Return configured database, connecting first when needed."""
        if self._client is None and not self.connect():
            raise RuntimeError("Could not connect to MongoDB")
        assert self._client is not None
        return self._client[self.config.database]


def get_mongodb_client() -> MongoDBClient:
    """Factory for a MongoDB client using env-based configuration."""
    return MongoDBClient()

