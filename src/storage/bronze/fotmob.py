"""Bronze layer storage for raw FotMob API responses (JSON format).

This module provides FotMob-specific bronze storage implementation that extends
the base bronze storage with FotMob-specific functionality like health checks.
"""

import contextlib
import json
from datetime import datetime
from typing import Any, Dict

try:
    from filelock import FileLock, Timeout

    FILE_LOCKING_AVAILABLE = True
except ImportError:
    FILE_LOCKING_AVAILABLE = False
    FileLock = None
    Timeout = None

from ...core.constants import HealthThresholds
from ...utils.logging_utils import get_logger
from .base import BaseBronzeStorage

logger = get_logger(__name__)


class FotMobBronzeStorage(BaseBronzeStorage):
    """FotMob-specific Bronze layer storage.

    Extends BaseBronzeStorage with FotMob-specific functionality:
    - Health checks for FotMob API connectivity
    - FotMob-specific match marking functionality

    Structure:
        data/fotmob/
            ├── matches/
            │   └── YYYYMMDD/
            │       ├── match_4193494.json
            │       └── match_4193495.json
            └── daily_listings/
                └── YYYYMMDD/
                    └── matches.json

    Daily listings track match IDs to prevent duplicate API requests.
    """

    @property
    def scraper_name(self) -> str:
        """Return the scraper name."""
        return "fotmob"

    @property
    def source_name(self) -> str:
        """Return the data source name."""
        return "fotmob_api"

    def __init__(self, base_dir: str = "data/fotmob"):
        """Initialize FotMob Bronze storage.

        Args:
            base_dir: Base directory for raw data (default: data/fotmob)
        """
        super().__init__(base_dir)
        logger.info(f"Bronze storage initialized: {base_dir}")

    def health_check(self) -> Dict[str, Any]:
        """Perform pre-flight health checks before operations.

        Checks:
        - Disk space available
        - Write permissions
        - Directory structure
        - Network connectivity (basic)

        Returns:
            Dictionary with health check results
        """
        issues = []
        warnings = []
        checks = []

        # Check disk space
        try:
            import shutil

            stat = shutil.disk_usage(self.base_dir)
            free_gb = stat.free / (1024**3)
            total_gb = stat.total / (1024**3)
            used_pct = (stat.used / stat.total) * 100

            disk_status = (
                "OK"
                if free_gb >= HealthThresholds.DISK_WARNING_GB
                else "WARNING"
                if free_gb >= HealthThresholds.DISK_CRITICAL_GB
                else "ERROR"
            )
            checks.append(
                {
                    "check": "Disk Space",
                    "status": disk_status,
                    "message": f"{free_gb:.1f} GB free ({used_pct:.1f}% used)",
                    "details": {
                        "free_gb": round(free_gb, 2),
                        "total_gb": round(total_gb, 2),
                        "used_pct": round(used_pct, 1),
                    },
                }
            )

            if free_gb < HealthThresholds.DISK_CRITICAL_GB:
                issues.append(
                    f"Critical: Less than {HealthThresholds.DISK_CRITICAL_GB} GB "
                    f"free disk space ({free_gb:.1f} GB)"
                )
            elif free_gb < HealthThresholds.DISK_WARNING_GB:
                warnings.append(
                    f"Low disk space: {free_gb:.1f} GB free "
                    f"(recommend {HealthThresholds.DISK_WARNING_GB}+ GB)"
                )
        except Exception as e:
            checks.append(
                {"check": "Disk Space", "status": "ERROR", "message": f"Failed to check: {e}"}
            )
            issues.append(f"Could not check disk space: {e}")

        # Check write permissions
        try:
            test_file = self.base_dir / ".health_check_write_test"
            test_file.write_text("test")
            test_file.unlink()

            checks.append(
                {
                    "check": "Write Permissions",
                    "status": "OK",
                    "message": "Can write to bronze directory",
                }
            )
        except Exception as e:
            checks.append(
                {
                    "check": "Write Permissions",
                    "status": "ERROR",
                    "message": f"No write permission: {e}",
                }
            )
            issues.append(f"No write permission to {self.base_dir}: {e}")

        # Check directory structure
        required_dirs = [self.matches_dir]
        missing_dirs = [d for d in required_dirs if not d.exists()]

        if missing_dirs:
            checks.append(
                {
                    "check": "Directory Structure",
                    "status": "WARNING",
                    "message": f"{len(missing_dirs)} directories missing (will be created)",
                    "details": {"missing": [str(d) for d in missing_dirs]},
                }
            )
            warnings.append(f"{len(missing_dirs)} directories missing")
        else:
            checks.append(
                {
                    "check": "Directory Structure",
                    "status": "OK",
                    "message": "All required directories exist",
                }
            )

        # Check network connectivity
        try:
            import requests

            requests.get("https://www.fotmob.com", timeout=5)

            checks.append(
                {"check": "Network Connectivity", "status": "OK", "message": "Can reach FotMob.com"}
            )
        except Exception as e:
            checks.append(
                {
                    "check": "Network Connectivity",
                    "status": "WARNING",
                    "message": f"Cannot reach FotMob.com: {e}",
                }
            )
            warnings.append(f"Network may be unavailable: {e}")

        # Check file locking
        if FILE_LOCKING_AVAILABLE:
            checks.append(
                {
                    "check": "File Locking",
                    "status": "OK",
                    "message": "File locking available (filelock installed)",
                }
            )
        else:
            checks.append(
                {
                    "check": "File Locking",
                    "status": "WARNING",
                    "message": "File locking NOT available (install 'filelock' package)",
                }
            )
            warnings.append("File locking not available - concurrent access may cause issues")

        # Calculate overall status
        error_count = sum(1 for c in checks if c["status"] == "ERROR")
        warning_count = sum(1 for c in checks if c["status"] == "WARNING")

        if error_count > 0:
            overall_status = "UNHEALTHY"
        elif warning_count > 0:
            overall_status = "WARNING"
        else:
            overall_status = "HEALTHY"

        return {
            "overall_status": overall_status,
            "timestamp": datetime.now().isoformat(),
            "checks": checks,
            "issues": issues,
            "warnings": warnings,
            "summary": {
                "total_checks": len(checks),
                "passed": sum(1 for c in checks if c["status"] == "OK"),
                "warnings": warning_count,
                "errors": error_count,
            },
        }

    def mark_match_as_scraped(self, match_id: str, date_str: str) -> bool:
        """Update daily listing file to mark a match as scraped.

        Moves match_id from missing_match_ids to scraped_match_ids.

        Args:
            match_id: Match ID to mark as scraped
            date_str: Date string YYYYMMDD format (or YYYY-MM-DD, will be converted)

        Returns:
            True if update was successful, False otherwise
        """
        try:
            date_str_normalized = self._normalize_date(date_str)
        except ValueError:
            self.logger.warning(f"Invalid date format: {date_str}")
            return False

        listing_file = self.daily_listings_dir / date_str_normalized / "matches.json"

        if not listing_file.exists():
            self.logger.debug(f"Daily listing file not found: {listing_file}")
            return False

        lock_file = listing_file.parent / ".matches.json.lock"

        if FILE_LOCKING_AVAILABLE:
            lock = FileLock(lock_file, timeout=30)
        else:
            lock = contextlib.nullcontext()

        with lock:
            try:
                with open(listing_file, "r", encoding="utf-8") as f:
                    data = json.load(f)

                match_id_int = int(match_id)

                if "storage" not in data:
                    data["storage"] = {}
                storage = data["storage"]

                if "missing_match_ids" not in storage:
                    storage["missing_match_ids"] = []
                if "scraped_match_ids" not in storage:
                    storage["scraped_match_ids"] = []

                # Move from missing to scraped
                if match_id_int in storage["missing_match_ids"]:
                    storage["missing_match_ids"].remove(match_id_int)

                if match_id_int not in storage["scraped_match_ids"]:
                    storage["scraped_match_ids"].append(match_id_int)

                # Update storage statistics
                try:
                    all_match_ids = data.get("match_ids", [])
                    if not all_match_ids:
                        matches = data.get("matches", [])
                        all_match_ids = [m.get("match_id") for m in matches if m.get("match_id")]

                    if all_match_ids:
                        match_ids_int = [int(mid) for mid in all_match_ids]
                        matches_date_dir = self.matches_dir / date_str_normalized
                        unavailable_match_ids = storage.get("unavailable_match_ids", [])
                        storage_stats = self._get_storage_stats(
                            date_str_normalized,
                            match_ids_int,
                            matches_date_dir,
                            unavailable_match_ids=unavailable_match_ids,
                        )

                        storage.update(
                            {
                                "files_stored": storage_stats["files_stored"],
                                "files_missing": storage_stats["files_missing"],
                                "total_size_bytes": storage_stats["total_size_bytes"],
                                "total_size_mb": storage_stats["total_size_mb"],
                                "files_in_archive": storage_stats["files_in_archive"],
                                "files_individual": storage_stats["files_individual"],
                                "archive_size_bytes": storage_stats["archive_size_bytes"],
                                "archive_size_mb": storage_stats["archive_size_mb"],
                                "scraped_match_ids": storage_stats["scraped_match_ids"],
                                "missing_match_ids": storage_stats["missing_match_ids"],
                                "unavailable_match_ids": storage_stats["unavailable_match_ids"],
                                "completion_percentage": storage_stats.get(
                                    "completion_percentage", 0.0
                                ),
                            }
                        )
                except Exception as e:
                    self.logger.warning(f"Could not update storage statistics: {e}")

                # Atomic write
                temp_file = listing_file.parent / ".matches.json.tmp"
                with open(temp_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)

                # Verify
                with open(temp_file, "r", encoding="utf-8") as f:
                    json.load(f)

                if listing_file.exists():
                    listing_file.unlink()
                temp_file.rename(listing_file)

                self.logger.debug(f"Updated daily listing: match {match_id} marked as scraped")
                return True

            except Exception as e:
                self.logger.error(f"Error updating daily listing for match {match_id}: {e}")

                temp_file = listing_file.parent / ".matches.json.tmp"
                if temp_file.exists():
                    try:
                        temp_file.unlink()
                    except Exception:
                        pass
                return False

    def mark_match_as_unavailable(self, match_id: str, date_str: str) -> bool:
        """Mark a match as unavailable from FotMob detail API.

        FotMob may list a fixture in the daily schedule but return
        ``{"error": true, "message": "Data not found"}`` for matchDetails.
        These matches count toward day completion without a Bronze file.
        """
        try:
            date_str_normalized = self._normalize_date(date_str)
        except ValueError:
            self.logger.warning(f"Invalid date format: {date_str}")
            return False

        listing_file = self.daily_listings_dir / date_str_normalized / "matches.json"

        if not listing_file.exists():
            self.logger.debug(f"Daily listing file not found: {listing_file}")
            return False

        lock_file = listing_file.parent / ".matches.json.lock"

        if FILE_LOCKING_AVAILABLE:
            lock = FileLock(lock_file, timeout=30)
        else:
            lock = contextlib.nullcontext()

        with lock:
            try:
                with open(listing_file, "r", encoding="utf-8") as f:
                    data = json.load(f)

                match_id_int = int(match_id)
                storage = data.setdefault("storage", {})
                unavailable_match_ids = storage.setdefault("unavailable_match_ids", [])

                if match_id_int not in unavailable_match_ids:
                    unavailable_match_ids.append(match_id_int)

                if match_id_int in storage.get("missing_match_ids", []):
                    storage["missing_match_ids"].remove(match_id_int)

                try:
                    all_match_ids = data.get("match_ids", [])
                    if all_match_ids:
                        match_ids_int = [int(mid) for mid in all_match_ids]
                        matches_date_dir = self.matches_dir / date_str_normalized
                        storage_stats = self._get_storage_stats(
                            date_str_normalized,
                            match_ids_int,
                            matches_date_dir,
                            unavailable_match_ids=unavailable_match_ids,
                        )
                        storage.update(
                            {
                                "files_stored": storage_stats["files_stored"],
                                "files_missing": storage_stats["files_missing"],
                                "total_size_bytes": storage_stats["total_size_bytes"],
                                "total_size_mb": storage_stats["total_size_mb"],
                                "files_in_archive": storage_stats["files_in_archive"],
                                "files_individual": storage_stats["files_individual"],
                                "archive_size_bytes": storage_stats["archive_size_bytes"],
                                "archive_size_mb": storage_stats["archive_size_mb"],
                                "scraped_match_ids": storage_stats["scraped_match_ids"],
                                "missing_match_ids": storage_stats["missing_match_ids"],
                                "unavailable_match_ids": storage_stats["unavailable_match_ids"],
                                "completion_percentage": storage_stats.get(
                                    "completion_percentage", 0.0
                                ),
                            }
                        )
                except Exception as e:
                    self.logger.warning(f"Could not update storage statistics: {e}")

                temp_file = listing_file.parent / ".matches.json.tmp"
                with open(temp_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)

                with open(temp_file, "r", encoding="utf-8") as f:
                    json.load(f)

                if listing_file.exists():
                    listing_file.unlink()
                temp_file.rename(listing_file)

                self.logger.info(
                    "Marked match as FotMob-unavailable in daily listing",
                    extra={"date": date_str_normalized, "match_id": match_id},
                )
                return True

            except Exception as e:
                self.logger.error(
                    f"Error marking match {match_id} as unavailable in daily listing: {e}"
                )

                temp_file = listing_file.parent / ".matches.json.tmp"
                if temp_file.exists():
                    try:
                        temp_file.unlink()
                    except Exception:
                        pass
                return False


# Backward-compatible alias; prefer FotMobBronzeStorage in new code.
BronzeStorage = FotMobBronzeStorage
