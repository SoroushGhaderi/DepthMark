"""MongoDB client helpers for DepthMark content catalog."""

from dataclasses import dataclass
from urllib.parse import quote_plus

from pymongo import MongoClient
from pymongo.database import Database

from config.settings import get_settings
from src.common.logging import get_logger

logger = get_logger(__name__)


def build_mongodb_uri(
    host: str,
    port: int,
    username: str | None,
    password: str | None,
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
    username: str | None
    password: str | None
    database: str
    auth_source: str
    uri: str | None

    @classmethod
    def from_settings(cls) -> "MongoConnectionConfig":
        """Build configuration from the MONGODB_* settings."""
        settings = get_settings()
        return cls(
            host=settings.mongodb_host,
            port=settings.mongodb_port,
            username=settings.mongodb_user,
            password=settings.mongodb_password,
            database=settings.mongodb_database,
            auth_source=settings.mongodb_auth_source,
            uri=settings.mongodb_uri,
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
    """Thin wrapper around pymongo.MongoClient used by DepthMark."""

    def __init__(self, config: MongoConnectionConfig | None = None):
        self.config = config or MongoConnectionConfig.from_settings()
        self._client: MongoClient | None = None

    def connect(self) -> bool:
        """Connect and ping MongoDB server."""
        try:
            self._client = MongoClient(
                self.config.resolved_uri(),
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=10000,
                appname="depthmark",
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
            logger.exception("MongoDB connection failed", error=str(exc))
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
