"""Storage package — Bronze, Silver, and Gold layer storage."""
from .bronze.base import BaseBronzeStorage
from .bronze.fotmob import BronzeStorage, FotMobBronzeStorage
from .mongodb import MongoDBClient, ensure_content_catalog_indexes, get_mongodb_client
from .s3_client import S3Client, S3ConfigurationError

__all__ = [
    "BaseBronzeStorage",
    "FotMobBronzeStorage",
    "BronzeStorage",
    "S3Client",
    "S3ConfigurationError",
    "MongoDBClient",
    "get_mongodb_client",
    "ensure_content_catalog_indexes",
]
