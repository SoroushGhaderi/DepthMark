"""Base Bronze layer storage for raw API responses (JSON format).

Bronze layer contains unprocessed, raw data exactly as received from the API.
This provides an audit trail and enables reprocessing if needed.

This base class provides common functionality for all scraper-specific
bronze storage implementations.
"""

import gzip
import io
import json
import os
import shutil
import tarfile
from abc import ABC, abstractmethod
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

try:
    from filelock import FileLock, Timeout

    FILE_LOCKING_AVAILABLE = True
except ImportError:
    FILE_LOCKING_AVAILABLE = False
    FileLock = None
    Timeout = None

from ...core import StorageError, StorageProtocol
from src.common.logging import get_logger


class BaseBronzeStorage(StorageProtocol, ABC):
    """Base class for Bronze layer storage.

    Bronze layer contains unprocessed, raw data exactly as received from the API.
    This provides an audit trail and enables reprocessing if needed.

    Structure:
        data/{scraper}/
            ├── matches/
            │   └── YYYYMM/
            │       └── YYYYMMDD/
            │       ├── match_{id}.json
            │       └── match_{id}.json
            └── daily_listings/
                └── YYYYMM/
                    └── YYYYMMDD/
                        └── matches.json

    Daily listings track match IDs to prevent duplicate API requests.

    Subclasses must implement:
        - scraper_name: Name of the scraper (e.g., 'fotmob')
        - source_name: Name of the data source (e.g., 'fotmob_api')
    """

    @property
    @abstractmethod
    def scraper_name(self) -> str:
        """Return the name of the scraper (e.g., 'fotmob')."""
        pass

    @property
    @abstractmethod
    def source_name(self) -> str:
        """Return the name of the data source (e.g., 'fotmob_api')."""
        pass

    def __init__(self, base_dir: str):
        """Initialize Bronze storage.

        Args:
            base_dir: Explicit aspect directory (e.g., data/fotmob/historical)
        """
        self.base_dir = Path(base_dir)
        self.logger = get_logger(self.__class__.__name__)

        # Validate and create base directory
        if self.base_dir.exists() and self.base_dir.is_file():
            raise StorageError(
                f"Cannot create directory '{self.base_dir}': A file with that name already exists. "
                f"Please remove or rename the file at {self.base_dir.absolute()}",
                details={"path": str(self.base_dir.absolute())},
            )
        self.base_dir.mkdir(parents=True, exist_ok=True)

        # Create matches directory
        self.matches_dir = self.base_dir / "matches"
        if self.matches_dir.exists() and self.matches_dir.is_file():
            raise StorageError(
                f"Cannot create directory '{self.matches_dir}': A file with that name already exists. "
                f"Please remove or rename the file at {self.matches_dir.absolute()}",
                details={"path": str(self.matches_dir.absolute())},
            )
        self.matches_dir.mkdir(parents=True, exist_ok=True)

        # Create daily listings directory
        self.daily_listings_dir = self.base_dir / "daily_listings"
        if self.daily_listings_dir.exists() and self.daily_listings_dir.is_file():
            raise StorageError(
                f"Cannot create directory '{self.daily_listings_dir}': A file with that name already exists. "
                f"Please remove or rename the file at {self.daily_listings_dir.absolute()}",
                details={"path": str(self.daily_listings_dir.absolute())},
            )
        self.daily_listings_dir.mkdir(parents=True, exist_ok=True)

        self.logger.debug(f"Bronze storage initialized at {base_dir}")

    def _normalize_date(self, date_str: str) -> str:
        """Normalize date string to YYYYMMDD format.

        Args:
            date_str: Date string in YYYYMMDD or YYYY-MM-DD format

        Returns:
            Normalized date string in YYYYMMDD format

        Raises:
            ValueError: If date format is invalid
        """
        if len(date_str) == 10 and "-" in date_str:
            return date_str.replace("-", "")
        elif len(date_str) == 8 and date_str.isdigit():
            return date_str
        else:
            raise ValueError(f"Invalid date format: {date_str}. Expected YYYYMMDD or YYYY-MM-DD")

    @staticmethod
    def _date_partition_dir(parent_dir: Path, date_str: str) -> Path:
        """Return the canonical ``YYYYMM/YYYYMMDD`` directory for a date."""
        return parent_dir / date_str[:6] / date_str

    def _normalize_date_safe(self, date_str: str) -> str:
        """Normalize date string to YYYYMMDD format, returning as-is if invalid.

        Args:
            date_str: Date string in YYYYMMDD or YYYY-MM-DD format

        Returns:
            Normalized date string in YYYYMMDD format, or original if invalid
        """
        try:
            return self._normalize_date(date_str)
        except ValueError:
            self.logger.warning(f"Invalid date format: {date_str}, using as-is")
            return date_str

    def save_raw_match_data(
        self, match_id: str, raw_data: Dict[str, Any], date_str: Optional[str] = None
    ) -> Path:
        """Save raw API response to Bronze layer.

        Bronze layer = One API call = One JSON file = Complete or Failed

        Args:
            match_id: Match ID
            raw_data: Raw API response (dict) - complete response from one API call
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            Path to saved file
        """
        try:
            if date_str:
                date_str_normalized = self._normalize_date(date_str)
            else:
                date_str_normalized = datetime.now().strftime("%Y%m%d")

            date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)
            date_dir.mkdir(parents=True, exist_ok=True)

            file_path = date_dir / f"match_{match_id}.json"
            temp_path = date_dir / f".match_{match_id}.json.tmp"
            scraped_at = datetime.now().isoformat()

            data_with_metadata = {
                "match_id": match_id,
                "scraped_at": scraped_at,
                "date": date_str_normalized,
                "data": raw_data,
            }

            try:
                # Write to temp file first (atomic write pattern)
                with open(temp_path, "w", encoding="utf-8") as f:
                    json.dump(data_with_metadata, f, indent=2, ensure_ascii=False)

                # Verify the file is valid JSON
                with open(temp_path, "r", encoding="utf-8") as f:
                    json.load(f)

                # Atomic rename
                if file_path.exists():
                    file_path.unlink()
                temp_path.rename(file_path)

                file_size_kb = os.path.getsize(file_path) / 1024

                self.logger.debug(
                    f"Saved raw data for match {match_id} to {file_path} ({file_size_kb:.2f} KB)"
                )
                return file_path

            except Exception as write_error:
                if temp_path.exists():
                    try:
                        temp_path.unlink()
                    except Exception:
                        pass
                raise write_error

        except Exception as e:
            self.logger.error(f"Error saving raw data for match {match_id}: {e}", exc_info=True)
            raise

    def save_matches_batch(
        self, matches: List[tuple], date_str: Optional[str] = None
    ) -> List[Path]:
        """Save multiple matches in a single batch operation.

        More efficient than individual saves when processing many matches
        as it reduces lock acquisition overhead and I/O operations.

        Args:
            matches: List of (match_id, raw_data) tuples
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            List of paths to saved files
        """
        if not matches:
            return []

        try:
            if date_str:
                date_str_normalized = self._normalize_date(date_str)
            else:
                date_str_normalized = datetime.now().strftime("%Y%m%d")

            date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)
            date_dir.mkdir(parents=True, exist_ok=True)

            saved_paths = []
            failed_matches = []
            scraped_at = datetime.now().isoformat()

            lock_path = date_dir / ".batch_write.lock"

            if FILE_LOCKING_AVAILABLE:
                lock = FileLock(lock_path, timeout=30)
                try:
                    with lock:
                        saved_paths, failed_matches = self._save_matches_batch_internal(
                            matches, date_dir, date_str_normalized, scraped_at
                        )
                except Timeout:
                    self.logger.error("Could not acquire lock for batch save after 30s")
                    raise
                finally:
                    if lock_path.exists():
                        try:
                            lock_path.unlink()
                        except Exception:
                            pass
            else:
                self.logger.warning(
                    "File locking not available - batch save may not be thread-safe"
                )
                saved_paths, failed_matches = self._save_matches_batch_internal(
                    matches, date_dir, date_str_normalized, scraped_at
                )

            if failed_matches:
                self.logger.warning(
                    f"Batch save completed: {len(saved_paths)}/{len(matches)} succeeded, "
                    f"{len(failed_matches)} failed: {failed_matches}"
                )
            else:
                self.logger.info(
                    f"Batch save completed: {len(saved_paths)} matches saved to {date_dir}"
                )

            return saved_paths

        except Exception as e:
            self.logger.error(f"Error in batch save: {e}", exc_info=True)
            raise

    def _save_matches_batch_internal(
        self, matches: List[tuple], date_dir: Path, date_str_normalized: str, scraped_at: str
    ) -> tuple:
        """Internal method to save matches without lock management.

        Returns:
            Tuple of (saved_paths, failed_matches)
        """
        saved_paths = []
        failed_matches = []

        for match_id, raw_data in matches:
            try:
                file_path = date_dir / f"match_{match_id}.json"
                temp_path = date_dir / f".match_{match_id}.json.tmp"

                data_with_metadata = {
                    "match_id": match_id,
                    "scraped_at": scraped_at,
                    "date": date_str_normalized,
                    "data": raw_data,
                }

                with open(temp_path, "w", encoding="utf-8") as f:
                    json.dump(data_with_metadata, f, indent=2, ensure_ascii=False)

                # Verify
                with open(temp_path, "r", encoding="utf-8") as f:
                    json.load(f)

                if file_path.exists():
                    file_path.unlink()
                temp_path.rename(file_path)

                file_size_kb = os.path.getsize(file_path) / 1024

                saved_paths.append(file_path)
                self.logger.debug(f"Saved match {match_id} ({file_size_kb:.2f} KB)")

            except Exception as e:
                self.logger.error(f"Error saving match {match_id} in batch: {e}")
                failed_matches.append(match_id)

                temp_path = date_dir / f".match_{match_id}.json.tmp"
                if temp_path.exists():
                    try:
                        temp_path.unlink()
                    except Exception:
                        pass

        return saved_paths, failed_matches

    def load_raw_match_data(
        self, match_id: str, date_str: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Load raw API response from Bronze layer.

        Supports: tar archive, individual .json.gz, and .json files.

        Args:
            match_id: Match ID
            date_str: Optional date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            Raw API response dict, or None if not found
        """
        try:
            if date_str:
                date_str_normalized = self._normalize_date_safe(date_str)
                date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)

                # Try tar archive first
                archive_path = date_dir / f"{date_str_normalized}_matches.tar"
                if archive_path.exists():
                    try:
                        with tarfile.open(archive_path, "r") as tar:
                            member_name = f"match_{match_id}.json.gz"
                            try:
                                member = tar.getmember(member_name)
                                f = tar.extractfile(member)
                                if f:
                                    with gzip.open(
                                        io.BytesIO(f.read()), "rt", encoding="utf-8"
                                    ) as gz:
                                        data = json.load(gz)
                                    return data.get("data", data)
                            except KeyError:
                                pass
                    except Exception as e:
                        self.logger.error(f"Error reading archive {archive_path}: {e}")

                # Try gzip file
                file_path_gz = date_dir / f"match_{match_id}.json.gz"
                if file_path_gz.exists():
                    with gzip.open(file_path_gz, "rt", encoding="utf-8") as f:
                        data = json.load(f)
                    return data.get("data", data)

                # Try plain JSON
                file_path = date_dir / f"match_{match_id}.json"
                if file_path.exists():
                    with open(file_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    return data.get("data", data)

                self.logger.warning(f"Raw data not found for match {match_id} on {date_str}")
                return None
            else:
                # Search all date directories
                for date_dir in self.matches_dir.rglob("????????"):
                    if not date_dir.is_dir():
                        continue

                    # Try tar archive
                    archive_path = date_dir / f"{date_dir.name}_matches.tar"
                    if archive_path.exists():
                        try:
                            with tarfile.open(archive_path, "r") as tar:
                                member_name = f"match_{match_id}.json.gz"
                                try:
                                    member = tar.getmember(member_name)
                                    f = tar.extractfile(member)
                                    if f:
                                        with gzip.open(
                                            io.BytesIO(f.read()), "rt", encoding="utf-8"
                                        ) as gz:
                                            data = json.load(gz)
                                        return data.get("data", data)
                                except KeyError:
                                    continue
                        except Exception:
                            continue

                # Try gzip files
                matches_gz = list(self.matches_dir.rglob(f"match_{match_id}.json.gz"))
                matches = list(self.matches_dir.rglob(f"match_{match_id}.json"))

                if matches_gz:
                    with gzip.open(matches_gz[0], "rt", encoding="utf-8") as f:
                        data = json.load(f)
                    return data.get("data", data)
                elif matches:
                    with open(matches[0], "r", encoding="utf-8") as f:
                        data = json.load(f)
                    return data.get("data", data)

                self.logger.warning(f"Raw data not found for match {match_id}")
                return None

        except Exception as e:
            self.logger.error(f"Error loading raw data for match {match_id}: {e}")
            return None

    def match_exists(self, match_id: str, date_str: Optional[str] = None) -> bool:
        """Check if raw data exists for a match.

        Checks archive, .json.gz, and .json files.

        Args:
            match_id: Match ID
            date_str: Optional date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            True if raw data exists, False otherwise
        """
        if date_str:
            date_str_normalized = self._normalize_date_safe(date_str)
            date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)

            # Check tar archive
            archive_path = date_dir / f"{date_str_normalized}_matches.tar"
            if archive_path.exists():
                try:
                    with tarfile.open(archive_path, "r") as tar:
                        member_name = f"match_{match_id}.json.gz"
                        try:
                            tar.getmember(member_name)
                            return True
                        except KeyError:
                            pass
                except Exception:
                    pass

            # Check individual files
            file_path = date_dir / f"match_{match_id}.json"
            file_path_gz = date_dir / f"match_{match_id}.json.gz"
            return file_path.exists() or file_path_gz.exists()
        else:
            # Search all locations
            matches = list(self.matches_dir.rglob(f"match_{match_id}.json"))
            matches_gz = list(self.matches_dir.rglob(f"match_{match_id}.json.gz"))

            if matches or matches_gz:
                return True

            # Check archives
            for date_dir in self.matches_dir.rglob("????????"):
                if not date_dir.is_dir():
                    continue
                archive_path = date_dir / f"{date_dir.name}_matches.tar"
                if archive_path.exists():
                    try:
                        with tarfile.open(archive_path, "r") as tar:
                            member_name = f"match_{match_id}.json.gz"
                            try:
                                tar.getmember(member_name)
                                return True
                            except KeyError:
                                continue
                    except Exception:
                        continue

        return False

    def is_match_unavailable(self, match_id: str, date_str: str) -> bool:
        """Return True when FotMob has no detail data for a listed match."""
        listing = self.load_daily_listing(date_str)
        if not listing:
            return False

        unavailable = listing.get("storage", {}).get("unavailable_match_ids", [])
        try:
            match_id_int = int(match_id)
        except (TypeError, ValueError):
            return False

        return match_id_int in {int(mid) for mid in unavailable}

    def is_match_complete(self, match_id: str, date_str: str) -> bool:
        """Return True when a match is stored in Bronze or marked FotMob-unavailable."""
        return self.match_exists(match_id, date_str) or self.is_match_unavailable(
            match_id, date_str
        )

    def save_daily_listing(self, date_str: str, match_ids: List) -> Path:
        """Save daily listing of match IDs for a date with comprehensive metadata.

        Used to track games and prevent duplicate API requests.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)
            match_ids: List of match IDs for the date

        Returns:
            Path to saved daily listing file
        """
        date_str_normalized = self._normalize_date(date_str)

        date_dir = self._date_partition_dir(self.daily_listings_dir, date_str_normalized)
        date_dir.mkdir(parents=True, exist_ok=True)

        listing_file = date_dir / "matches.json"

        matches_date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)
        existing_listing = self.load_daily_listing(date_str_normalized)
        existing_unavailable = []
        if existing_listing:
            existing_unavailable = existing_listing.get("storage", {}).get(
                "unavailable_match_ids", []
            )
        storage_stats = self._get_storage_stats(
            date_str_normalized,
            match_ids,
            matches_date_dir,
            unavailable_match_ids=existing_unavailable,
        )

        listing_data = {
            "date": date_str_normalized,
            "scraped_at": datetime.now().isoformat(),
            "match_ids": [str(mid) if not isinstance(mid, int) else mid for mid in match_ids],
            "total_matches": len(match_ids),
            "storage": storage_stats,
        }

        temp_file = date_dir / ".matches.json.tmp"
        try:
            with open(temp_file, "w", encoding="utf-8") as f:
                json.dump(listing_data, f, indent=2, ensure_ascii=False)
            temp_file.replace(listing_file)
            self.logger.info(
                f"Saved daily listing for {date_str_normalized}: {len(match_ids)} matches, "
                f"{storage_stats['files_stored']} files stored ({storage_stats['total_size_mb']:.2f} MB)"
            )
            return listing_file
        except Exception:
            if temp_file.exists():
                temp_file.unlink()
            raise

    def _get_storage_stats(
        self,
        date_str: str,
        match_ids: List,
        matches_date_dir: Path,
        unavailable_match_ids: Optional[List] = None,
    ) -> Dict[str, Any]:
        """Gather comprehensive storage statistics for a date.

        Args:
            date_str: Date string YYYYMMDD format
            match_ids: List of match IDs
            matches_date_dir: Path to matches directory for the date

        Returns:
            Dictionary with storage statistics
        """
        stats = {
            "files_stored": 0,
            "files_missing": 0,
            "total_size_bytes": 0,
            "total_size_mb": 0.0,
            "files_in_archive": 0,
            "files_individual": 0,
            "archive_size_bytes": 0,
            "archive_size_mb": 0.0,
            "scraped_match_ids": [],
            "missing_match_ids": [],
            "unavailable_match_ids": [],
        }

        unavailable_ids = []
        for match_id in unavailable_match_ids or []:
            try:
                unavailable_ids.append(int(match_id))
            except (TypeError, ValueError):
                continue
        unavailable_set = set(unavailable_ids)
        stats["unavailable_match_ids"] = sorted(unavailable_set)

        if not matches_date_dir.exists():
            stats["missing_match_ids"] = [
                int(mid) for mid in match_ids if int(mid) not in unavailable_set
            ]
            stats["files_missing"] = len(stats["missing_match_ids"])
            if len(match_ids) > 0:
                completed = len(unavailable_set)
                stats["completion_percentage"] = round((completed / len(match_ids)) * 100, 2)
            return stats

        # Check archive
        archive_path = matches_date_dir / f"{date_str}_matches.tar"
        archived_match_ids = set()
        if archive_path.exists():
            try:
                stats["archive_size_bytes"] = archive_path.stat().st_size
                stats["archive_size_mb"] = stats["archive_size_bytes"] / (1024 * 1024)

                match_ids_set = {str(mid) for mid in match_ids}

                with tarfile.open(archive_path, "r") as tar:
                    for member in tar.getmembers():
                        if member.name.startswith("match_") and member.name.endswith(".json.gz"):
                            match_id_str = member.name.replace("match_", "").replace(".json.gz", "")
                            if match_id_str in match_ids_set:
                                archived_match_ids.add(match_id_str)
                                stats["files_in_archive"] += 1
                                stats["total_size_bytes"] += member.size
            except Exception as e:
                self.logger.warning(f"Error reading archive {archive_path}: {e}")

        # Check individual files
        for match_id in match_ids:
            match_id_str = str(match_id)
            file_path = matches_date_dir / f"match_{match_id_str}.json"
            file_path_gz = matches_date_dir / f"match_{match_id_str}.json.gz"

            found = False
            if match_id_str in archived_match_ids:
                found = True
                stats["scraped_match_ids"].append(
                    int(match_id) if isinstance(match_id, str) and match_id.isdigit() else match_id
                )
            elif file_path.exists():
                found = True
                stats["files_individual"] += 1
                file_size = file_path.stat().st_size
                stats["total_size_bytes"] += file_size
                stats["scraped_match_ids"].append(
                    int(match_id) if isinstance(match_id, str) and match_id.isdigit() else match_id
                )
            elif file_path_gz.exists():
                found = True
                stats["files_individual"] += 1
                file_size = file_path_gz.stat().st_size
                stats["total_size_bytes"] += file_size
                stats["scraped_match_ids"].append(
                    int(match_id) if isinstance(match_id, str) and match_id.isdigit() else match_id
                )

            if not found:
                if int(match_id) in unavailable_set:
                    continue
                stats["files_missing"] += 1
                stats["missing_match_ids"].append(
                    int(match_id) if isinstance(match_id, str) and match_id.isdigit() else match_id
                )

        stats["files_stored"] = stats["files_in_archive"] + stats["files_individual"]
        stats["total_size_mb"] = stats["total_size_bytes"] / (1024 * 1024)

        if len(match_ids) > 0:
            completed = stats["files_stored"] + len(unavailable_set)
            stats["completion_percentage"] = round((completed / len(match_ids)) * 100, 2)
        else:
            stats["completion_percentage"] = 0.0

        return stats

    def load_daily_listing(self, date_str: str) -> Optional[Dict[str, Any]]:
        """Load daily listing of match IDs for a date.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            Dictionary with daily listing data, or None if not found
        """
        try:
            date_str_normalized = self._normalize_date(date_str)
        except ValueError:
            self.logger.warning(f"Invalid date format: {date_str}")
            return None

        listing_file = self._date_partition_dir(
            self.daily_listings_dir, date_str_normalized
        ) / "matches.json"

        if not listing_file.exists():
            return None

        try:
            with open(listing_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            self.logger.error(f"Error loading daily listing for {date_str_normalized}: {e}")
            return None

    def get_match_ids_for_date(self, date_str: str) -> List[Union[int, str]]:
        """Get list of match IDs for a date from daily listing.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            List of match IDs (numeric integers for FotMob), or empty list if not found
        """
        listing = self.load_daily_listing(date_str)
        if listing:
            return listing.get("match_ids", [])
        return []

    def get_completion_percentage(self, date_str: str) -> Optional[float]:
        """Get completion percentage for a date from daily listing.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            Completion percentage (0-100), or None if not available
        """
        listing = self.load_daily_listing(date_str)
        if listing:
            storage = listing.get("storage", {})
            return storage.get("completion_percentage")
        return None

    def daily_listing_exists(self, date_str: str) -> bool:
        """Check if daily listing exists for a date.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            True if daily listing exists, False otherwise
        """
        try:
            date_str_normalized = self._normalize_date(date_str)
        except ValueError:
            return False

        listing_file = self._date_partition_dir(
            self.daily_listings_dir, date_str_normalized
        ) / "matches.json"
        return listing_file.exists()

    def compress_date_files(self, date_str: str, force: bool = False) -> Dict[str, Any]:
        """Compress all JSON files for a specific date.

        Step 1: Compress each .json to .json.gz (GZIP compression)
        Step 2: Bundle all .json.gz to ONE tar archive
        Step 3: Delete individual .json.gz files

        Final result: ONE tar file containing all compressed .json.gz files

        RESUMABLE: If archive already exists, skips compression unless force=True.

        Args:
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)
            force: If True, recompress even if archive exists (default: False)

        Returns:
            Dictionary with compression statistics and processing log
        """
        date_str_normalized = self._normalize_date(date_str)

        date_dir = self._date_partition_dir(self.matches_dir, date_str_normalized)
        archive_path = date_dir / f"{date_str_normalized}_matches.tar"

        # Check if already compressed
        if not force and archive_path.exists():
            archive_size_mb = archive_path.stat().st_size / (1024 * 1024)
            self.logger.debug(
                f"Archive exists for {date_str_normalized} ({archive_size_mb:.2f} MB), skipping"
            )
            return {
                "compressed": 0,
                "size_before_mb": 0,
                "size_after_mb": archive_size_mb,
                "saved_mb": 0,
                "saved_pct": 0,
                "archive_file": str(archive_path),
                "status": "already_compressed",
            }

        if not date_dir.exists():
            self.logger.debug(f"Date directory not found: {date_dir}")
            return {
                "compressed": 0,
                "size_before_mb": 0,
                "size_after_mb": 0,
                "archive_file": None,
                "status": "no_directory",
            }

        json_files = list(date_dir.glob("match_*.json"))
        existing_gz_files = list(date_dir.glob("match_*.json.gz"))

        all_files = json_files + existing_gz_files
        if not all_files:
            self.logger.debug(f"No files to compress for {date_str_normalized}")
            return {
                "compressed": 0,
                "size_before_mb": 0,
                "size_after_mb": 0,
                "archive_file": None,
                "status": "no_files",
            }

        total_before = sum(f.stat().st_size for f in all_files)

        try:
            gz_files = list(existing_gz_files)

            # Step 1: Compress JSON files to gzip (byte-copy method - faster)
            if json_files:
                self.logger.debug(f"Compressing {len(json_files)} JSON files to gzip")
                for json_file in json_files:
                    gz_file = json_file.with_suffix(".json.gz")
                    with open(json_file, "rb") as f_in, gzip.open(
                        gz_file, "wb", compresslevel=6
                    ) as f_out:
                        shutil.copyfileobj(f_in, f_out)

                    gz_files.append(gz_file)
                    json_file.unlink()
            else:
                self.logger.debug(f"Using {len(existing_gz_files)} existing gzip files")

            # Step 2: Create tar archive
            self.logger.debug(f"Creating tar archive with {len(gz_files)} files")

            with tarfile.open(archive_path, "w") as tar:
                for gz_file in gz_files:
                    tar.add(gz_file, arcname=gz_file.name)

            total_after = archive_path.stat().st_size

            # Verify archive
            self.logger.debug("Verifying archive integrity")
            try:
                with tarfile.open(archive_path, "r") as tar:
                    tar_members = {m.name for m in tar.getmembers()}
                    expected_files = {f.name for f in gz_files}

                    if tar_members != expected_files:
                        missing = expected_files - tar_members
                        extra = tar_members - expected_files
                        error_msg = []
                        if missing:
                            error_msg.append(f"Missing files in tar: {missing}")
                        if extra:
                            error_msg.append(f"Unexpected files in tar: {extra}")
                        raise ValueError(f"Tar archive incomplete: {'; '.join(error_msg)}")

                    self.logger.debug(f"Archive verified: {len(tar_members)} files intact")

            except Exception as verify_error:
                self.logger.error(f"Archive verification failed: {verify_error}")
                if archive_path.exists():
                    archive_path.unlink()
                self.logger.info("Deleted corrupt archive, kept original files")
                raise Exception(f"Tar archive verification failed: {verify_error}")

            # Step 3: Delete gzip files
            self.logger.debug(f"Cleaning up {len(gz_files)} temporary gzip files")
            deleted_count = 0
            for gz_file in gz_files:
                if gz_file.exists():
                    try:
                        gz_file.unlink()
                        deleted_count += 1
                    except Exception as e:
                        self.logger.warning(f"Could not delete {gz_file.name}: {e}")

            size_before_mb = total_before / (1024 * 1024)
            size_after_mb = total_after / (1024 * 1024)
            saved_mb = size_before_mb - size_after_mb
            saved_pct = ((total_before - total_after) / max(total_before, 1)) * 100

            self.logger.info(
                f"Compressed {date_str_normalized}: {len(gz_files)} files, "
                f"{size_before_mb:.2f} MB -> {size_after_mb:.2f} MB "
                f"(saved {saved_pct:.0f}%)"
            )

            return {
                "compressed": len(gz_files),
                "size_before_mb": round(size_before_mb, 2),
                "size_after_mb": round(size_after_mb, 2),
                "saved_mb": round(saved_mb, 2),
                "saved_pct": round(saved_pct, 1),
                "archive_file": str(archive_path),
                "status": "success",
            }

        except Exception as e:
            self.logger.error(f"Error during compression for {date_str_normalized}: {e}")
            # Cleanup on error
            if archive_path.exists():
                archive_path.unlink()
            return {
                "compressed": 0,
                "size_before_mb": 0,
                "size_after_mb": 0,
                "archive_file": None,
                "status": "error",
                "error": str(e),
            }
