"""FotMob Bronze ingestion, storage, and artifact synchronization."""

from .loader import BronzeRunResult, BronzeService
from .match_processor import FotMobBronzeMatchProcessor, MatchProcessor
from .paths import get_fotmob_historical_path, get_fotmob_live_path
from .s3_sync import BronzeS3Service, BronzeS3SyncError, BronzeS3SyncResult
from .storage import BronzeStorage, FotMobBronzeStorage

__all__ = [
    "BronzeRunResult",
    "BronzeService",
    "BronzeS3Service",
    "BronzeS3SyncError",
    "BronzeS3SyncResult",
    "BronzeStorage",
    "FotMobBronzeMatchProcessor",
    "FotMobBronzeStorage",
    "MatchProcessor",
    "get_fotmob_historical_path",
    "get_fotmob_live_path",
]
