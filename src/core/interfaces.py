"""Protocol definitions for DepthMark components.

This module defines the interfaces (protocols) that components must implement.
Using protocols instead of abstract base classes allows for structural typing
and makes the codebase more flexible and testable.

Protocols defined:
- StorageProtocol: Interface for all storage implementations
- ScraperProtocol: Interface for all scraper implementations
- ProcessorProtocol: Interface for data processors
- OrchestratorProtocol: Interface for orchestration logic

Usage:
    from src.core.interfaces import StorageProtocol
    
    class MyStorage(StorageProtocol):
        def save_match(self, match_id: str, data: Dict[str, Any], date: str) -> Path:
            ...
"""

from pathlib import Path
from typing import Any, Dict, List, Optional, Protocol, Union, runtime_checkable

# Type alias for match IDs - int (FotMob)
MatchId = Union[int, str]


@runtime_checkable
class StorageProtocol(Protocol):
    """Protocol for storage implementations.

    All storage classes (Bronze, Silver, Gold layers) should implement this interface.
    This ensures consistency across different storage backends and makes testing easier.

    Example implementations:
        - BronzeStorage (FotMob)
        - ClickHouseStorage
    """

    def save_match(self, match_id: str, data: Dict[str, Any], date: str) -> Path:
        """Save match data to storage.

        Args:
            match_id: Unique match identifier
            data: Match data dictionary
            date: Date string (YYYYMMDD or YYYY-MM-DD)

        Returns:
            Path to saved file

        Raises:
            StorageError: If save operation fails
        """
        ...

    def load_match(self, match_id: str, date: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Load match data from storage.

        Args:
            match_id: Unique match identifier
            date: Optional date string (YYYYMMDD or YYYY-MM-DD)

        Returns:
            Match data dictionary, or None if not found

        Raises:
            StorageError: If load operation fails
        """
        ...

    def match_exists(self, match_id: str, date: Optional[str] = None) -> bool:
        """Check if match data exists in storage.

        Args:
            match_id: Unique match identifier
            date: Optional date string (YYYYMMDD or YYYY-MM-DD)

        Returns:
            True if match exists, False otherwise
        """
        ...


@runtime_checkable
class ScraperProtocol(Protocol):
    """Protocol for scraper implementations.

    All scrapers should implement this interface to ensure consistent behavior
    and enable easy swapping of implementations for testing.

    Example implementations:
        - FotMobMatchScraper
        - FotMobDailyScraper
    """

    def fetch_matches_for_date(self, date: str) -> List[MatchId]:
        """Fetch list of match IDs for a given date.

        Args:
            date: Date string (YYYYMMDD or YYYY-MM-DD)

        Returns:
            List of match IDs (int for FotMob)

        Raises:
            ScraperError: If fetching fails
        """
        ...

    def fetch_match_details(self, match_id: str) -> Optional[Dict[str, Any]]:
        """Fetch detailed match data.

        Args:
            match_id: Unique match identifier

        Returns:
            Match details dictionary, or None if not found

        Raises:
            ScraperError: If fetching fails
        """
        ...

    def close(self) -> None:
        """Clean up resources (connections, sessions, browsers, etc.).

        Should be called when scraper is no longer needed.
        Implements the cleanup part of context manager protocol.
        """
        ...


@runtime_checkable
class ProcessorProtocol(Protocol):
    """Protocol for data processor implementations.

    Processors transform raw data from Bronze layer to structured Silver layer.

    Example implementations:
        - MatchProcessor
        - OddsProcessor
        - PlayerProcessor
    """

    def process(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process raw data into structured format.

        Args:
            raw_data: Raw data from Bronze layer

        Returns:
            Processed data ready for Silver layer

        Raises:
            ValidationError: If data validation fails
            ProcessingError: If processing fails
        """
        ...

    def validate(self, data: Dict[str, Any]) -> List[str]:
        """Validate data structure and content.

        Args:
            data: Data to validate

        Returns:
            List of validation error messages (empty if valid)
        """
        ...


@runtime_checkable
class OrchestratorProtocol(Protocol):
    """Protocol for orchestrator implementations.

    Orchestrators coordinate the scraping pipeline from end to end.

    Example implementations:
        - FotMobOrchestrator
    """

    def scrape_date(
        self,
        date: str,
        force_rescrape: bool = False,
        force_refetch_listing: bool = False,
        compress_completed: bool = True,
    ) -> Dict[str, Any]:
        """Scrape all matches for a given date.

        Args:
            date: Date string (YYYYMMDD or YYYY-MM-DD)
            force_rescrape: If True, re-scrape even if data exists
            force_refetch_listing: If True, refresh the date listing
            compress_completed: If True, compress complete date payloads

        Returns:
            Dictionary with scraping metrics and results

        Raises:
            OrchestratorError: If orchestration fails
        """
        ...

    def scrape_date_range(
        self, start_date: str, end_date: str, force_rescrape: bool = False
    ) -> Dict[str, Any]:
        """Scrape matches for a date range.

        Args:
            start_date: Start date (YYYYMMDD or YYYY-MM-DD)
            end_date: End date (YYYYMMDD or YYYY-MM-DD)
            force_rescrape: If True, re-scrape even if data exists

        Returns:
            Dictionary with aggregated metrics

        Raises:
            OrchestratorError: If orchestration fails
        """
        ...


@runtime_checkable
class ConfigProtocol(Protocol):
    """Protocol for configuration implementations.

    All configuration classes should implement this interface.

    Example implementations:
        - FotMobConfig
    """

    def validate(self) -> List[str]:
        """Validate configuration values.

        Returns:
            List of validation error messages (empty if valid)
        """
        ...

    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary.

        Returns:
            Dictionary representation of configuration
        """
        ...


@runtime_checkable
class CacheProtocol(Protocol):
    """Protocol for cache implementations.

    Provides interface for caching scraped data to avoid redundant requests.

    Example implementations:
        - InMemoryCache
        - RedisCache
        - FileCache
    """

    def get(self, key: str) -> Optional[Any]:
        """Get value from cache.

        Args:
            key: Cache key

        Returns:
            Cached value, or None if not found or expired
        """
        ...

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """Set value in cache.

        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds (optional)
        """
        ...

    def delete(self, key: str) -> None:
        """Delete value from cache.

        Args:
            key: Cache key
        """
        ...

    def clear(self) -> None:
        """Clear all cached values."""
        ...


@runtime_checkable
class MetricsProtocol(Protocol):
    """Protocol for metrics tracking implementations.

    Provides interface for tracking and exporting metrics.

    Example implementations:
        - ScraperMetrics
        - PerformanceMetrics
    """

    def increment(self, metric: str, value: int = 1) -> None:
        """Increment a counter metric.

        Args:
            metric: Metric name
            value: Amount to increment by (default: 1)
        """
        ...

    def record(self, metric: str, value: float) -> None:
        """Record a value metric.

        Args:
            metric: Metric name
            value: Value to record
        """
        ...

    def export(self) -> Dict[str, Any]:
        """Export all metrics.

        Returns:
            Dictionary with all metrics
        """
        ...


@runtime_checkable
class LoggerProtocol(Protocol):
    """Protocol for logger implementations.

    Standard logging interface used throughout the application.
    """

    def debug(self, message: str, *args, **kwargs) -> None:
        """Log debug message."""
        ...

    def info(self, message: str, *args, **kwargs) -> None:
        """Log info message."""
        ...

    def warning(self, message: str, *args, **kwargs) -> None:
        """Log warning message."""
        ...

    def error(self, message: str, *args, **kwargs) -> None:
        """Log error message."""
        ...

    def exception(self, message: str, *args, **kwargs) -> None:
        """Log exception with traceback."""
        ...


__all__ = [
    "StorageProtocol",
    "ScraperProtocol",
    "ProcessorProtocol",
    "OrchestratorProtocol",
    "ConfigProtocol",
    "CacheProtocol",
    "MetricsProtocol",
    "LoggerProtocol",
]
