"""
Orchestrator for parallel match scraping and processing.

SCRAPER: FotMob
PURPOSE: Orchestrate the entire scraping and processing pipeline.
         Saves to Bronze layer only. Use load_clickhouse.py to load to ClickHouse.
"""

import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import requests

from config import FotMobConfig

from .core import OrchestratorError, OrchestratorProtocol
from .core.constants import Defaults
from .processors import FotMobBronzeMatchProcessor
from .scrapers import DailyScraper, MatchScraper
from .storage import FotMobBronzeStorage, get_s3_uploader
from .utils import DataQualityChecker, ScraperMetrics, get_logger
from .services.telegram import ErrorAlertData, TelegramClient

logger = get_logger(__name__)


class FotMobOrchestrator(OrchestratorProtocol):
    """
    Orchestrate the entire scraping and processing pipeline.

    SCRAPER: FotMob
    PURPOSE: Scrapes match data and saves to Bronze layer (JSON files).
             ClickHouse loading is done separately via load_clickhouse.py
    """

    def __init__(self, config: Optional[FotMobConfig] = None, bronze_only: bool = True):
        """
        Initialize the orchestrator.

        Args:
            config: FotMob configuration. If None, uses default config.
            bronze_only: If True, only scrape to Bronze layer (no processing).
                        Default is True. Processing to ClickHouse is done separately.
        """
        self.config = config or FotMobConfig()
        self.logger = logger
        self.bronze_only = bronze_only
        self.telegram_client = TelegramClient()

        # Safety: FotMob can rate-limit/ban aggressive clients. Force sequential scraping
        # unless you intentionally re-enable parallelism in code.
        try:
            if getattr(self.config, "scraping", None) is not None:
                if getattr(self.config.scraping, "enable_parallel", False):
                    self.logger.warning(
                        "FotMob parallel scraping is disabled for safety (rate-limit/ban risk). "
                        "Forcing enable_parallel=False, max_workers=1."
                    )
                self.config.scraping.enable_parallel = False
                self.config.scraping.max_workers = 1
        except Exception as e:
            # Never fail initialization due to config shape differences
            self.logger.debug(
                "Could not enforce sequential FotMob scraping",
                extra={"error": str(e)},
            )

        self.bronze_storage = FotMobBronzeStorage(self.config.storage.bronze_path)
        self.logger.info("Bronze layer storage initialized")

        self.processor = None if bronze_only else FotMobBronzeMatchProcessor()

        self.logger.info("FotMob Orchestrator initialized", extra={"bronze_only": bronze_only})
        if bronze_only:
            self.logger.info("Note: Use load_clickhouse.py to load data from bronze to ClickHouse")

    def scrape_date(self, date_str: str, force_rescrape: bool = False) -> ScraperMetrics:
        """
        Scrape all matches for a specific date.

        Args:
            date_str: Date in YYYYMMDD format
            force_rescrape: If True, rescrape already processed matches

        Returns:
            ScraperMetrics object with results
        """

        metrics = ScraperMetrics(date=date_str)
        metrics.start()

        self.logger.info("Starting scrape for date", extra={"date": date_str})

        self.logger.info("Running automatic health check...")
        health_status = self.bronze_storage.health_check()

        if health_status["overall_status"] != "HEALTHY":
            critical_failures = [
                check
                for check in health_status["checks"]
                if check["status"] == "FAIL" and check.get("critical", False)
            ]
            if critical_failures:
                error_msg = (
                    f"Critical health check failures: {[c['name'] for c in critical_failures]}"
                )
                self.logger.error(error_msg)
                metrics.end()
                raise OrchestratorError(
                    error_msg, details={"failed_checks": [c["name"] for c in critical_failures]}
                )
            self.logger.warning("Health check warnings detected, but continuing...")
        else:
            self.logger.info("[OK] Health check passed")

        try:
            scraped_match_ids = set()

            match_ids = self._fetch_match_ids(date_str)
            metrics.total_matches = len(match_ids)

            if not match_ids:
                self.logger.warning("No matches found for date", extra={"date": date_str})
                metrics.end()
                return metrics

            completion_pct = self.bronze_storage.get_completion_percentage(date_str)
            already_complete = completion_pct is not None and completion_pct >= 100.0

            if already_complete:
                self.logger.info(
                    "Date already complete, skipping scrape and proceeding with compression/S3",
                    extra={
                        "date": date_str,
                        "completion_pct": round(completion_pct or 0.0, 2),
                    },
                )
                metrics.skipped_matches = metrics.total_matches
                self.logger.info(
                    "Set metrics for completed date",
                    extra={
                        "date": date_str,
                        "total_matches": metrics.total_matches,
                        "successful_matches": metrics.successful_matches,
                        "skipped_matches": metrics.skipped_matches,
                    },
                )

            if already_complete:
                match_ids_to_scrape = []
            elif not force_rescrape:
                match_ids_to_scrape = [
                    str(m)
                    for m in match_ids
                    if not self.bronze_storage.match_exists(str(m), date_str)
                ]
                skipped = len(match_ids) - len(match_ids_to_scrape)
                if skipped > 0:
                    self.logger.info(
                        "Skipping already scraped matches in Bronze",
                        extra={"date": date_str, "skipped_matches": skipped},
                    )
                for match_id in match_ids:
                    if self.bronze_storage.match_exists(str(match_id), date_str):
                        metrics.record_skip(str(match_id), "Already scraped in Bronze")
                        scraped_match_ids.add(str(match_id))
            else:
                match_ids_to_scrape = [str(m) for m in match_ids]

            if self.config.enable_parallel and len(match_ids_to_scrape) > 1:
                self._scrape_matches_parallel(
                    match_ids_to_scrape, metrics, date_str, scraped_match_ids
                )
            else:
                self._scrape_matches_sequential(
                    match_ids_to_scrape, metrics, date_str, scraped_match_ids
                )

        except Exception as e:
            self.logger.exception(
                "Error during scraping", extra={"date": date_str, "error": str(e)}
            )

        finally:
            metrics.end()

        all_matches_scraped = (
            metrics.successful_matches + metrics.skipped_matches == metrics.total_matches
            and metrics.failed_matches == 0
        )

        self.logger.info(
            "Post-scrape summary",
            extra={
                "date": date_str,
                "bronze_only": self.bronze_only,
                "successful_matches": metrics.successful_matches,
                "total_matches": metrics.total_matches,
                "failed_matches": metrics.failed_matches,
                "all_matches_scraped": all_matches_scraped,
            },
        )

        if self.bronze_only and metrics.successful_matches > 0:
            self.logger.info(
                "Compression eligibility check",
                extra={"date": date_str, "all_matches_scraped": all_matches_scraped},
            )
            if not all_matches_scraped:
                missing_count = (
                    metrics.total_matches - metrics.successful_matches - metrics.skipped_matches
                )
                missing_reason = f"Missing {missing_count} of {metrics.total_matches} matches (failed: {metrics.failed_matches}, skipped: {metrics.skipped_matches})"
                self.logger.warning(
                    "Skipping compression due to incomplete scraping",
                    extra={"date": date_str, "missing_reason": missing_reason},
                )

                self.telegram_client.render_and_send(
                    "error_alert.html.j2",
                    ErrorAlertData(
                        level="WARNING",
                        title=f"FotMob Partial Scraping — {date_str}",
                        message=f"Only {metrics.successful_matches}/{metrics.total_matches} matches scraped. Compression and S3 backup skipped.\n\nReason: {missing_reason}",
                        context={
                            "date": date_str,
                            "total_matches": str(metrics.total_matches),
                            "successful": str(metrics.successful_matches),
                            "failed": str(metrics.failed_matches),
                            "skipped": str(metrics.skipped_matches),
                        },
                    ),
                )
            else:
                try:
                    self.logger.debug("Starting compression", extra={"date": date_str})
                    compression_stats = self.bronze_storage.compress_date_files(date_str)

                    if (
                        compression_stats.get("status") == "success"
                        and compression_stats["compressed"] > 0
                    ):
                        saved_mb = compression_stats.get("saved_mb", 0)
                        saved_pct = compression_stats.get("saved_pct", 0)
                        compressed = compression_stats.get("compressed", 0)
                        self.logger.info(
                            f"Compressed {compressed} files for {date_str}: "
                            f"saved {saved_mb:.2f} MB ({saved_pct:.0f}% reduction)"
                        )
                except Exception as e:
                    self.logger.error(
                        "Error during compression",
                        extra={"date": date_str, "error": str(e)},
                    )

        if self.bronze_only and all_matches_scraped:
            self.logger.info("Checking S3 backup...")
            s3_uploader = get_s3_uploader()
            if s3_uploader:
                bronze_dir = f"{self.config.storage.bronze_path}/matches/{date_str}"
                bronze_path = Path(bronze_dir)

                self.logger.info(
                    "Checking bronze directory", extra={"bronze_dir": bronze_dir, "date": date_str}
                )

                if bronze_path.exists():
                    files = list(bronze_path.iterdir())
                    self.logger.info(
                        "Bronze directory file count",
                        extra={
                            "bronze_dir": bronze_dir,
                            "date": date_str,
                            "file_count": len(files),
                        },
                    )

                    if files:
                        year_month = date_str[:6]
                        s3_key = f"bronze/fotmob/{year_month}/{date_str}.tar.gz"
                        already_in_bucket = s3_uploader.object_exists(s3_key)

                        if already_in_bucket:
                            self.logger.info(
                                "S3 backup already exists in bucket",
                                extra={"date": date_str, "s3_key": s3_key},
                            )
                            metrics.s3_already_in_bucket = True
                            metrics.s3_uploaded = True
                            obj_size = s3_uploader.get_object_size(s3_key)
                            if obj_size is not None:
                                metrics.s3_size_mb = round(obj_size / (1024 * 1024), 1)
                        else:
                            try:
                                if s3_uploader.upload_bronze_backup(bronze_dir, date_str, "fotmob"):
                                    self.logger.info(
                                        "S3 backup uploaded", extra={"date": date_str}
                                    )
                                    metrics.s3_uploaded = True
                                    obj_size = s3_uploader.get_object_size(s3_key)
                                    if obj_size is not None:
                                        metrics.s3_size_mb = round(
                                            obj_size / (1024 * 1024), 1
                                        )
                                else:
                                    self.logger.error(
                                        "Failed to upload date to S3", extra={"date": date_str}
                                    )
                            except Exception as e:
                                self.logger.error(
                                    "Error uploading to S3",
                                    extra={"date": date_str, "error": str(e)},
                                )
                    else:
                        self.logger.warning(
                            "Bronze directory is empty, skipping S3 upload",
                            extra={"bronze_dir": bronze_dir, "date": date_str},
                        )
                else:
                    self.logger.warning(
                        "Bronze directory missing, skipping S3 upload",
                        extra={"bronze_dir": bronze_dir, "date": date_str},
                    )
            else:
                self.logger.info(
                    "S3 uploader not available (not configured or boto3 not installed)"
                )

        metrics.print_summary()

        return metrics

    def _fetch_match_ids(self, date_str: str, force_refetch: bool = False) -> List[Union[int, str]]:
        """
        Fetch match IDs for a date and save daily listing to Bronze.
        Uses daily listing to prevent duplicate API requests.

        Args:
            date_str: Date string YYYYMMDD format
            force_refetch: If True, fetch from API even if daily listing exists

        Returns:
            List of match IDs (int for FotMob)
        """

        if not force_refetch and self.bronze_storage.daily_listing_exists(date_str):
            self.logger.info("Daily listing exists, loading from storage", extra={"date": date_str})
            if match_ids := self.bronze_storage.get_match_ids_for_date(date_str):
                self.logger.info(
                    "Loaded match IDs from daily listing",
                    extra={"date": date_str, "match_count": len(match_ids)},
                )
                return match_ids
            self.logger.warning(
                "Daily listing exists but is empty, fetching from API",
                extra={"date": date_str},
            )

        self.logger.info("Fetching daily listing from API", extra={"date": date_str})

        max_retries = Defaults.MAX_FETCH_RETRIES

        for attempt in range(max_retries):
            try:
                with DailyScraper(self.config) as scraper:
                    match_ids = scraper.fetch_matches_for_date(date_str)

                if not match_ids:
                    self.logger.warning("Empty match list returned", extra={"date": date_str})
                    if attempt < max_retries - 1:
                        wait_time = 2**attempt
                        self.logger.info(
                            "Retrying daily listing fetch",
                            extra={
                                "date": date_str,
                                "wait_seconds": wait_time,
                                "attempt": attempt + 1,
                                "max_retries": max_retries,
                            },
                        )
                        time.sleep(wait_time)
                        continue
                    else:
                        self.logger.error(
                            "Failed to fetch daily listing after retries",
                            extra={"date": date_str, "max_retries": max_retries},
                        )
                        return []

                try:
                    self.bronze_storage.save_daily_listing(date_str, match_ids)
                    self.logger.info(
                        "Saved daily listing",
                        extra={"date": date_str, "match_count": len(match_ids)},
                    )
                except Exception as e:
                    self.logger.warning(
                        "Could not save daily listing",
                        extra={"date": date_str, "error": str(e)},
                    )

                self.logger.info(
                    "Successfully fetched daily listing",
                    extra={"date": date_str, "match_count": len(match_ids)},
                )
                return match_ids

            except requests.exceptions.RequestException as network_error:
                if attempt < max_retries - 1:
                    wait_time = 2**attempt
                    self.logger.warning(
                        f"Network error fetching daily listing "
                        f"(attempt {attempt + 1}/{max_retries}): {network_error}. "
                        f"Retrying {wait_time}s..."
                    )
                    time.sleep(wait_time)
                else:
                    self.logger.error(
                        "Failed to fetch daily listing after retries",
                        extra={
                            "date": date_str,
                            "max_retries": max_retries,
                            "error": str(network_error),
                        },
                    )
                    raise

            except Exception as error:
                self.logger.error(
                    "Unexpected error fetching daily listing",
                    extra={"date": date_str, "error": str(error)},
                )
                raise

        return []

    def _scrape_matches_sequential(
        self, match_ids: List[str], metrics: ScraperMetrics, date_str: str, scraped_match_ids: set
    ):
        """Scrape matches sequentially."""
        self.logger.info(
            "Scraping matches sequentially",
            extra={"date": date_str, "match_count": len(match_ids)},
        )

        completed_count = 0
        consecutive_errors = 0
        MAX_CONSECUTIVE_ERRORS = 3

        with MatchScraper(self.config) as scraper:
            for match_id in match_ids:
                if match_id in scraped_match_ids:
                    self.logger.debug(
                        "[SKIP]Skipping match already scraped in this session",
                        extra={"date": date_str, "match_id": match_id},
                    )
                    continue

                success, error_msg, quality_issues = self._fetch_and_save_match(
                    scraper, match_id, date_str
                )

                if success:
                    scraped_match_ids.add(match_id)
                    consecutive_errors = 0

                    if quality_issues:
                        metrics.record_data_quality_issue(match_id, quality_issues)
                        self.telegram_client.render_and_send(
                            "error_alert.html.j2",
                            ErrorAlertData(
                                level="WARNING",
                                title=f"Data Quality Issue: Match {match_id}",
                                message=f"Data quality issues detected for match {match_id}: {', '.join(quality_issues[:3])}",
                                context={
                                    "match_id": match_id,
                                    "issues": ", ".join(quality_issues),
                                    "date": date_str,
                                },
                            ),
                        )

                    metrics.record_success(match_id)
                    self.logger.info(
                        "[SUCCESS] Scraped match to Bronze",
                        extra={"date": date_str, "match_id": match_id},
                    )
                else:
                    metrics.record_failure(
                        match_id, error_msg or "Unknown error", "ProcessingError"
                    )
                    self.telegram_client.render_and_send(
                        "error_alert.html.j2",
                        ErrorAlertData(
                            level="ERROR",
                            title=f"Scrape Failed: Match {match_id}",
                            message=f"Failed to scrape match {match_id}: {error_msg or 'Unknown error'}",
                            context={
                                "match_id": match_id,
                                "error": error_msg or "Unknown error",
                                "error_type": "ProcessingError",
                                "date": date_str,
                            },
                        ),
                    )
                    consecutive_errors += 1

                    if consecutive_errors >= MAX_CONSECUTIVE_ERRORS:
                        error_msg_critical = f"CRITICAL: {MAX_CONSECUTIVE_ERRORS} consecutive errors detected. Interrupting scrape."
                        self.logger.error(error_msg_critical)
                        self.telegram_client.render_and_send(
                            "error_alert.html.j2",
                            ErrorAlertData(
                                level="CRITICAL",
                                title=f"FotMob Scraping Interrupted — {date_str}",
                                message=f"{error_msg_critical}\n\nLast error: {error_msg}\nLast match ID: {match_id}\nCompleted: {completed_count}/{len(match_ids)}",
                                context={
                                    "date": date_str,
                                    "consecutive_errors": str(consecutive_errors),
                                    "last_error": error_msg or "Unknown error",
                                    "last_match_id": match_id,
                                    "completed": str(completed_count),
                                    "total": str(len(match_ids)),
                                },
                            ),
                        )
                        raise OrchestratorError(error_msg_critical)

                completed_count += 1
                # Log progress after EVERY match
                progress_pct = (completed_count / len(match_ids)) * 100
                self.logger.info(
                    "[PROGRESS] Match processing update",
                    extra={
                        "date": date_str,
                        "completed": completed_count,
                        "total": len(match_ids),
                        "progress_pct": round(progress_pct, 1),
                        "successful_matches": metrics.successful_matches,
                        "failed_matches": metrics.failed_matches,
                        "skipped_matches": metrics.skipped_matches,
                    },
                )

    def _scrape_matches_parallel(
        self, match_ids: List[str], metrics: ScraperMetrics, date_str: str, scraped_match_ids: set
    ):
        """Scrape matches in parallel using thread pool."""
        self.logger.info(
            "Scraping matches in parallel",
            extra={
                "date": date_str,
                "match_count": len(match_ids),
                "max_workers": self.config.max_workers,
            },
        )

        match_ids_to_scrape = [m for m in match_ids if m not in scraped_match_ids]
        if len(match_ids_to_scrape) < len(match_ids):
            skipped = len(match_ids) - len(match_ids_to_scrape)
            self.logger.info(
                "Skipping already scraped matches in session",
                extra={"date": date_str, "skipped_matches": skipped},
            )

        # IMPORTANT: In parallel mode, reuse one MatchScraper (and its underlying
        # requests.Session) per worker thread to avoid per-match connection/TLS overhead.
        thread_local = threading.local()
        created_scrapers: List[MatchScraper] = []
        created_scrapers_lock = threading.Lock()

        def _get_thread_scraper() -> MatchScraper:
            scraper = getattr(thread_local, "scraper", None)
            if scraper is None:
                scraper = MatchScraper(self.config)
                thread_local.scraper = scraper
                with created_scrapers_lock:
                    created_scrapers.append(scraper)
            return scraper

        def _worker(match_id: str) -> tuple[bool, Optional[str]]:
            scraper = _get_thread_scraper()
            return self._process_match_with_scraper(scraper, match_id, date_str)

        try:
            with ThreadPoolExecutor(max_workers=self.config.max_workers) as executor:
                future_to_match = {}
                for match_id in match_ids_to_scrape:
                    future = executor.submit(_worker, match_id)
                    future_to_match[future] = match_id

                completed_count = 0

                for future in as_completed(future_to_match):
                    match_id = future_to_match[future]
                    try:
                        success, error_msg = future.result()
                        if success:
                            scraped_match_ids.add(match_id)
                            metrics.record_success(match_id)
                            self.logger.info(
                                "[SUCCESS] Processed match",
                                extra={"date": date_str, "match_id": match_id},
                            )
                        else:
                            metrics.record_failure(match_id, error_msg or "Unknown error")
                            self.logger.error(
                                "[FAILED] Match processing failed",
                                extra={"date": date_str, "match_id": match_id},
                            )
                    except Exception as e:
                        self.logger.exception(
                            "Exception in parallel match processing",
                            extra={"date": date_str, "match_id": match_id, "error": str(e)},
                        )
                        metrics.record_failure(match_id, str(e), type(e).__name__)

                    completed_count += 1
                    # Log progress after EVERY match
                    progress_pct = (completed_count / len(match_ids_to_scrape)) * 100
                    self.logger.info(
                        "[PROGRESS] Parallel match processing update",
                        extra={
                            "date": date_str,
                            "completed": completed_count,
                            "total": len(match_ids_to_scrape),
                            "progress_pct": round(progress_pct, 1),
                            "successful_matches": metrics.successful_matches,
                            "failed_matches": metrics.failed_matches,
                            "skipped_matches": metrics.skipped_matches,
                        },
                    )
        finally:
            # Always close any sessions created for worker threads.
            for scraper in created_scrapers:
                try:
                    scraper.close()
                except Exception as e:
                    self.logger.debug(
                        "Failed to close worker scraper session", extra={"error": str(e)}
                    )

    def _fetch_and_save_match(
        self,
        scraper: MatchScraper,
        match_id: str,
        date_str: str,
    ) -> tuple[bool, Optional[str], Optional[List[str]]]:
        """
        Core match processing logic - fetch data and save to Bronze storage.

        This method contains the shared logic used by both sequential and parallel
        processing modes. It intentionally does NOT handle metrics or alerting,
        allowing callers to handle those concerns appropriately.

        Args:
            scraper: MatchScraper instance to use for fetching
            match_id: Match ID to process
            date_str: Date string YYYYMMDD format

        Returns:
            Tuple of (success, error_message, quality_issues)
            - success: True if match was processed successfully
            - error_message: Error description if failed, None otherwise
            - quality_issues: List of data quality issues, or None if not checked
        """
        try:
            raw_data = scraper.fetch_match_details(match_id)
            if not raw_data:
                return False, "Failed to fetch match data", None

            self.bronze_storage.save_raw_match_data(match_id, raw_data, date_str)
            self.logger.debug(
                "Saved raw data to bronze layer",
                extra={"date": date_str, "match_id": match_id},
            )

            try:
                self.bronze_storage.mark_match_as_scraped(match_id, date_str)
            except Exception as e:
                self.logger.warning(
                    "Could not update daily listing for match",
                    extra={"date": date_str, "match_id": match_id, "error": str(e)},
                )

            if self.bronze_only:
                return True, None, None

            # Run data quality checks if enabled
            quality_issues = None
            if self.processor and self.config.enable_data_quality_checks:
                try:
                    dataframes, _ = self.processor.process_all(raw_data)
                    validation_results = DataQualityChecker.validate_all_dataframes(dataframes)
                    quality_issues = [
                        issue
                        for result in validation_results.values()
                        if not result.get("passed", True)
                        for issue in result.get("issues", [])
                    ]

                    if quality_issues and self.config.fail_on_quality_issues:
                        return False, f"Data quality issues: {quality_issues}", quality_issues
                except Exception as e:
                    self.logger.warning(
                        "Data quality check failed for match",
                        extra={"date": date_str, "match_id": match_id, "error": str(e)},
                    )

            return True, None, quality_issues

        except Exception as e:
            self.logger.exception(
                "Error processing match",
                extra={"date": date_str, "match_id": match_id, "error": str(e)},
            )
            return False, str(e), None

    def _process_match_with_scraper(
        self,
        scraper: MatchScraper,
        match_id: str,
        date_str: str,
    ) -> tuple[bool, Optional[str]]:
        """
        Process a single match using an existing scraper instance.

        NOTE: This method intentionally does NOT create/close the scraper.
        In parallel mode we reuse a scraper (and HTTP session) per worker thread.

        Returns:
            Tuple of (success, error_message)
        """
        success, error_msg, _ = self._fetch_and_save_match(scraper, match_id, date_str)
        return success, error_msg

    def _process_single_match(
        self,
        scraper: MatchScraper,
        match_id: str,
        metrics: ScraperMetrics,
        date_str: str,
        scraped_match_ids: set,
    ):
        """Process a single match (for sequential execution)."""
        self.logger.info("Processing match", extra={"date": date_str, "match_id": match_id})

        success, error_msg, quality_issues = self._fetch_and_save_match(scraper, match_id, date_str)

        if success:
            scraped_match_ids.add(match_id)

            if quality_issues:
                metrics.record_data_quality_issue(match_id, quality_issues)
                self.telegram_client.render_and_send(
                    "error_alert.html.j2",
                    ErrorAlertData(
                        level="WARNING",
                        title=f"Data Quality Issue: Match {match_id}",
                        message=f"Data quality issues detected for match {match_id}: {', '.join(quality_issues[:3])}",
                        context={
                            "match_id": match_id,
                            "issues": ", ".join(quality_issues),
                            "date": date_str,
                        },
                    ),
                )

            metrics.record_success(match_id)
            self.logger.info(
                "[SUCCESS] Scraped match to Bronze",
                extra={"date": date_str, "match_id": match_id},
            )
        else:
            metrics.record_failure(match_id, error_msg or "Unknown error", "ProcessingError")
            self.telegram_client.render_and_send(
                "error_alert.html.j2",
                ErrorAlertData(
                    level="ERROR",
                    title=f"Scrape Failed: Match {match_id}",
                    message=f"Failed to scrape match {match_id}: {error_msg or 'Unknown error'}",
                    context={
                        "match_id": match_id,
                        "error": error_msg or "Unknown error",
                        "error_type": "ProcessingError",
                        "date": date_str,
                    },
                ),
            )

    def get_match_data(self, match_id: int, date_str: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve raw match data from Bronze layer.

        Args:
            match_id: Match ID to retrieve
            date_str: Date string YYYYMMDD format

        Returns:
            Raw match data (dict) or None if not found

        Note: For processed data, use load_clickhouse.py to query ClickHouse.
        """

        return self.bronze_storage.load_raw_match_data(str(match_id), date_str)

    def close(self):
        """Clean up resources."""

        self.logger.info("Orchestrator closed")

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()
