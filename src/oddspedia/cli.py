#!/usr/bin/env python3
"""Standalone OddsHarvest football scraper entry point.

Usage:
    python main.py                              # full run for today (images blocked)
    python main.py --date 20260227             # full run for a specific date
    python main.py --headless                   # run without a browser window
    python main.py --headless --date 20260227  # headless run for a specific date
    python main.py discover --month 202607      # Event discovery only
    python main.py scrape --date 20260711       # Match detail extraction only
    python main.py run --month 202607            # Discover, then scrape
    python main.py --collect --month 202607      # Legacy alias for discover

Alternatively (after ``pip install -e .``):
    oddspedia-scraper --help
"""

import argparse
import calendar
import os
import sys
import threading
import time

# Make the src/ package discoverable when running main.py directly.
_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
if _src not in sys.path:
    sys.path.insert(0, _src)
import random
import tempfile
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime

from src.oddspedia.config import (
    get_run_logs_dir,
    get_match_links_file,
    get_discovery_snapshot_file,
    get_match_file,
    get_matches_dir,
    get_sport_listing_url,
    normalize_sport,
    normalize_date,
    normalize_month,
    WORKER_MIN_DELAY,
    WORKER_MAX_DELAY,
)
from src.oddspedia.driver import DriverManager
from src.oddspedia.logging import configure_logging, get_logger
from src.oddspedia.manifest import (
    create_manifest,
    load_manifest,
    save_manifest,
    update_manifest,
)
from src.oddspedia.match_collector import collect_match_links, listing_matches_target_date
from src.oddspedia.match_scraper import (
    FootballOddsCoverageError,
    FootballOddsUnavailableError,
    scrape_match,
)
from src.oddspedia.metrics import get_metrics, reset_metrics
from src.oddspedia.progress import TerminalOutcomeCheckpoint
from src.oddspedia.utils import save_json, load_json, random_delay
from selenium.common.exceptions import (
    InvalidSessionIdException,
    NoSuchWindowException,
    WebDriverException,
)
from src.oddspedia.audit import (
    audit_date,
    audit_match_json,
    sync_manifest_incomplete,
)

configure_logging()
logger = get_logger("oddspedia")

CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE = 5
CIRCUIT_BREAKER_COOLDOWN_SECONDS = 120
CIRCUIT_BREAKER_PAUSE_CYCLES_BEFORE_ABORT = 3
FOOTBALL_SKIP_STATUSES = {"POSTPONED", "CANCELLED", "CANCELED", "ABANDONED", "SUSPENDED"}


def _skip_reason(match_info, sport: str):
    status = str(match_info.get("status", "")).strip().upper()
    if sport == "football" and status in FOOTBALL_SKIP_STATUSES:
        return "non_playable_status"
    return None


def _driver_restart_required(exc: Exception) -> bool:
    """Only replace Chrome when the browser session itself is unusable."""
    if isinstance(exc, (InvalidSessionIdException, NoSuchWindowException)):
        return True
    if not isinstance(exc, WebDriverException):
        return False
    message = str(exc).lower()
    return any(
        marker in message
        for marker in (
            "invalid session id",
            "no such window",
            "disconnected",
            "not connected to devtools",
            "chrome not reachable",
            "tab crashed",
        )
    )


def _retry_delay(attempt: int, exc: Exception) -> float:
    if isinstance(exc, FootballOddsCoverageError):
        return min(2 * (attempt + 1), 6)
    return min(5 * (2**attempt), 120)


class _CircuitBreaker:
    """Tracks consecutive mark_failed outcomes and pauses/aborts the run.

    Thread-safe: uses a lock for concurrent worker access.
    """

    def __init__(self, metrics):
        self._metrics = metrics
        self._consecutive_failures = 0
        self._pause_cycles = 0
        self._pause_active = False
        self._aborted = False
        self._lock = threading.Lock()

    @property
    def aborted(self) -> bool:
        return self._aborted

    def record_success(self) -> None:
        with self._lock:
            self._consecutive_failures = 0

    def record_failure(self) -> None:
        with self._lock:
            if self._aborted:
                return
            self._consecutive_failures += 1
            if (
                self._consecutive_failures < CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE
                or self._pause_active
            ):
                return
            # One worker owns each cooldown. Concurrent failures observed while
            # paused belong to the same outage and must not count as new cycles.
            self._pause_active = True
            self._pause_cycles += 1
            self._metrics.record_circuit_breaker_pause()
            logger.warning(
                "circuit_breaker_pause",
                consecutive_failures=self._consecutive_failures,
                pause_cycle=self._pause_cycles,
                cooldown_seconds=CIRCUIT_BREAKER_COOLDOWN_SECONDS,
            )

        time.sleep(CIRCUIT_BREAKER_COOLDOWN_SECONDS)

        with self._lock:
            self._consecutive_failures = 0
            self._pause_active = False
            if self._pause_cycles >= CIRCUIT_BREAKER_PAUSE_CYCLES_BEFORE_ABORT:
                self._aborted = True
                self._metrics.record_circuit_breaker_abort()
                logger.error(
                    "circuit_breaker_abort",
                    total_pause_cycles=self._pause_cycles,
                )


def _match_id(match_info):
    """Return a normalized match id string for manifest comparisons."""
    return str(match_info["id"])


def _match_link(match_info):
    """Return the most complete source link available for a match."""
    return match_info.get("full_url") or match_info.get("url", "")


def _select_matches_to_scrape(
    matches, matches_dir, manifest, date_str, retry_failed: bool = False, sport: str = "football"
):
    """Choose matches from link inventory using JSON files as ground truth.

    Match links define the total available work. Per-match JSON files define
    completed data. The manifest is reconciled to those files before deciding
    what to scrape.
    """
    reconciled_count = 0
    for match_info in matches:
        reason = _skip_reason(match_info, sport)
        match_id = _match_id(match_info)
        if reason and match_id not in manifest.skipped:
            status = str(match_info.get("status", "")).strip().upper()
            manifest.mark_skipped(
                match_id,
                reason,
                status=status,
                url=_match_link(match_info),
            )
            logger.warning(
                "match_skipped",
                match_id=match_id,
                reason=reason,
                status=status,
                source="listing",
            )
            reconciled_count += 1

    done_set = {str(match_id) for match_id in manifest.done}
    failed_set = {str(match_id) for match_id in manifest.failed}
    skipped_set = {str(match_id) for match_id in manifest.skipped}
    incomplete_set = {str(match_id) for match_id in manifest.incomplete}
    in_progress_ids = {str(match_id) for match_id in manifest.in_progress_ids}

    matches_to_scrape = []
    skipped_count = 0

    if retry_failed and failed_set:
        for match_info in matches:
            match_id = _match_id(match_info)
            if match_id in skipped_set:
                skipped_count += 1
                continue
            out_path = get_match_file(date_str, match_id, sport=sport)
            has_json = os.path.exists(out_path)
            json_audit = (
                audit_match_json(date_str, match_id, out_path, sport=sport) if has_json else None
            )

            if has_json and json_audit and json_audit.accepted:
                if (
                    match_id not in done_set
                    or match_id in failed_set
                    or match_id in in_progress_ids
                ):
                    _log_manifest_json_reconciled(
                        match_id, match_id in done_set, match_id in failed_set, has_json
                    )
                    manifest.mark_done(match_id)
                    reconciled_count += 1
                skipped_count += 1
            elif has_json:
                _log_incomplete_json_rescrape(match_id, json_audit.reasons)
                manifest.mark_incomplete(match_id)
                reconciled_count += 1
                matches_to_scrape.append(match_info)
            elif (
                match_id in failed_set or match_id in incomplete_set or match_id in in_progress_ids
            ):
                matches_to_scrape.append(match_info)
            elif match_id in done_set:
                _log_stale_done_without_json(match_id)
                manifest.mark_pending(match_id)
                reconciled_count += 1
                matches_to_scrape.append(match_info)
        return matches_to_scrape, skipped_count, reconciled_count

    for match_info in matches:
        match_id = _match_id(match_info)
        if match_id in skipped_set:
            skipped_count += 1
            continue
        out_path = get_match_file(date_str, match_id, sport=sport)
        has_json = os.path.exists(out_path)
        json_audit = (
            audit_match_json(date_str, match_id, out_path, sport=sport) if has_json else None
        )

        if has_json and json_audit and json_audit.accepted:
            if match_id not in done_set or match_id in failed_set or match_id in in_progress_ids:
                _log_manifest_json_reconciled(
                    match_id, match_id in done_set, match_id in failed_set, has_json
                )
                manifest.mark_done(match_id)
                reconciled_count += 1
            skipped_count += 1
        elif has_json:
            _log_incomplete_json_rescrape(match_id, json_audit.reasons)
            manifest.mark_incomplete(match_id)
            reconciled_count += 1
            matches_to_scrape.append(match_info)
        elif match_id in failed_set or match_id in incomplete_set or match_id in in_progress_ids:
            matches_to_scrape.append(match_info)
        elif match_id in done_set:
            _log_stale_done_without_json(match_id)
            manifest.mark_pending(match_id)
            reconciled_count += 1
            matches_to_scrape.append(match_info)
        else:
            matches_to_scrape.append(match_info)

    return matches_to_scrape, skipped_count, reconciled_count


def _log_manifest_json_reconciled(match_id, in_done, in_failed, has_json):
    logger.warning(
        "manifest_reconciled_from_json",
        match_id=match_id,
        in_done=in_done,
        in_failed=in_failed,
        json_exists=has_json,
    )


def _log_stale_done_without_json(match_id):
    logger.warning(
        "manifest_done_without_json_rescrape",
        match_id=match_id,
        in_done=True,
        json_exists=False,
    )


def _log_incomplete_json_rescrape(match_id, reasons):
    logger.warning(
        "incomplete_json_rescrape",
        match_id=match_id,
        reasons=reasons,
    )


def _record_discovery(date_str, sport, discovery, snapshot=""):
    """Store date-level discovery acceptance or recovery evidence."""
    payload = discovery.to_dict()
    payload["snapshot"] = snapshot
    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        manifest = create_manifest(date_str, 0, sport=sport)
    manifest.record_discovery(payload)
    save_manifest(manifest)


def _needs_discovery_retry(date_str, sport: str) -> bool:
    manifest = load_manifest(date_str, sport=sport)
    if manifest and manifest.discovery.get("status") == "rescrape_candidate":
        return True
    links_file = get_match_links_file(date_str, sport=sport)
    return os.path.exists(links_file) and not _existing_inventory_matches_target(
        links_file, date_str
    )


def _as_match_list(matches):
    """Normalise legacy dict inventories and new discovery maps to a list."""
    if isinstance(matches, dict):
        return list(matches.values())
    return list(matches or [])


def _existing_inventory_matches_target(links_file, date_str) -> bool:
    """Reject an on-disk inventory if it was saved from another listing date."""
    if not os.path.exists(links_file):
        return False
    try:
        return listing_matches_target_date(_as_match_list(load_json(links_file)), date_str)
    except Exception as exc:
        logger.warning("existing_inventory_unreadable", links_file=links_file, error=str(exc))
        return False


def phase1_collect(
    driver, date_str, sport: str = "football", reuse_listing: bool = False, force: bool = False
):
    """Discover events for date_str and save the event-link inventory.

    ``reuse_listing`` keeps a month discovery run on the existing football
    listing page rather than reloading it for every date.
    """
    sport = normalize_sport(sport)
    links_file = get_match_links_file(date_str, sport=sport)
    if (
        os.path.exists(links_file)
        and not force
        and _existing_inventory_matches_target(links_file, date_str)
    ):
        matches = _as_match_list(load_json(links_file))
        logger.info(
            "links_file_exists_skipping_collection",
            sport=sport,
            path=links_file,
            count=len(matches),
        )
        return matches
    if os.path.exists(links_file) and not force:
        logger.warning(
            "existing_inventory_target_date_mismatch_rescraping",
            sport=sport,
            date=date_str,
            links_file=links_file,
        )

    logger.info("event_discovery_start", sport=sport, date=date_str)
    discovery = collect_match_links(
        driver,
        target_date=date_str,
        sport=sport,
        reuse_listing=reuse_listing,
        return_result=True,
    )
    # A stalled external listing is frequently transient. Retry once from a
    # fresh page before turning this Sport-Date Run into a Rescrape Candidate.
    if not discovery.complete and {
        "pagination_stalled",
        "listing_target_date_missing",
    }.intersection(discovery.anomalies):
        logger.info("event_discovery_retrying_fresh_listing", sport=sport, date=date_str)
        discovery = collect_match_links(
            driver,
            target_date=date_str,
            sport=sport,
            reuse_listing=False,
            return_result=True,
        )
    matches = _as_match_list(discovery.matches)
    if not matches:
        snapshot = get_discovery_snapshot_file(date_str, sport=sport)
        save_json([], snapshot)
        _record_discovery(date_str, sport, discovery, snapshot)
        logger.error("no_matches_found", anomalies=discovery.anomalies)
        return []
    if not discovery.complete:
        snapshot = get_discovery_snapshot_file(date_str, sport=sport)
        save_json(matches, snapshot)
        _record_discovery(date_str, sport, discovery, snapshot)
        logger.warning(
            "event_discovery_unaccepted",
            sport=sport,
            date=date_str,
            anomalies=discovery.anomalies,
            expected_pages=discovery.expected_pages,
            observed_pages=discovery.observed_pages,
            partial_snapshot=snapshot,
        )
        return []
    save_json(matches, links_file)
    _record_discovery(date_str, sport, discovery)
    logger.info("event_links_saved", sport=sport, links_file=links_file, links_count=len(matches))
    for m in matches[:3]:
        logger.debug("sample_url", url=m.get("full_url", m.get("url", "")))
    return matches


def _warmup_cloudflare(driver, sport: str = "football"):
    """Visit the base site once so Cloudflare cookies are set for the session."""
    from src.oddspedia.utils import safe_get

    sport = normalize_sport(sport)
    logger.info("cloudflare_warmup_start", sport=sport)
    safe_get(driver, get_sport_listing_url(sport))
    time.sleep(2)


def _audit_before_scrape(date_str, sport: str = "football"):
    """Refresh manifest.incomplete from existing JSON files before scraping."""
    audit_result = audit_date(date_str, sport=sport)
    sync_manifest_incomplete(audit_result)
    logger.info(
        "pre_scrape_audit_complete",
        sport=sport,
        date=date_str,
        missing=len(audit_result.missing),
        incomplete=len(audit_result.incomplete),
        invalid=len(audit_result.invalid),
    )


def phase2_scrape(
    driver,
    matches,
    date_str,
    retry_failed: bool = False,
    max_retries: int = 3,
    workers: int = 1,
    sport: str = "football",
):
    """Run phase 2 for one sport/date."""
    sport = normalize_sport(sport)
    if workers > 1:
        return _phase2_scrape_concurrent(
            matches,
            date_str,
            retry_failed,
            workers,
            max_retries=max_retries,
            sport=sport,
        )
    return _phase2_scrape_sequential(
        driver,
        matches,
        date_str,
        retry_failed=retry_failed,
        max_retries=max_retries,
        sport=sport,
    )


def _phase2_scrape_sequential(
    driver,
    matches,
    date_str,
    retry_failed: bool = False,
    max_retries: int = 3,
    sport: str = "football",
):
    """Extract match details from the event-link inventory.

    When *workers* > 1, each worker gets its own Chrome instance and processes
    a disjoint batch of matches concurrently.

    Args:
        driver: Selenium driver instance (unused when workers > 1)
        matches: List of match info dicts
        date_str: Date string for the scrape
        retry_failed: If True, only retry matches that previously failed
        max_retries: Maximum retry attempts for failed matches
        workers: Number of concurrent browser workers (1 = sequential)
    """
    sport = normalize_sport(sport)
    metrics = get_metrics()
    outcome_checkpoint = TerminalOutcomeCheckpoint(date_str, sport, metrics)
    metrics.phase2_start(total=len(matches))
    t0 = time.time()

    logger.info(
        "match_detail_extraction_start",
        sport=sport,
        total_matches=len(matches),
        date=date_str,
        retry_failed=retry_failed,
    )
    matches_dir = get_matches_dir(date_str, sport=sport)
    os.makedirs(matches_dir, exist_ok=True)

    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        manifest = create_manifest(date_str, len(matches), sport=sport)
    elif manifest.total != len(matches):
        manifest.total = len(matches)
        save_manifest(manifest)

    _audit_before_scrape(date_str, sport=sport)
    manifest = load_manifest(date_str, sport=sport) or manifest

    success_count = 0
    skipped_count = 0
    failed_count = 0
    circuit_breaker = _CircuitBreaker(metrics)

    failed_set = {str(match_id) for match_id in manifest.failed}
    if retry_failed and failed_set:
        logger.info("retrying_failed_matches", failed_count=len(failed_set))

    matches_to_scrape, skipped_count, reconciled_count = _select_matches_to_scrape(
        matches,
        matches_dir,
        manifest,
        date_str,
        retry_failed=retry_failed,
        sport=sport,
    )
    if reconciled_count:
        save_manifest(manifest)
        logger.info("manifest_reconciled_from_json_files", count=reconciled_count)
    outcome_checkpoint.sync(manifest)

    logger.info(
        "scraping_matches",
        to_scrape=len(matches_to_scrape),
        already_done=skipped_count,
        previously_failed=len(failed_set),
    )

    if not matches_to_scrape:
        manifest.clear_in_progress()
        save_manifest(manifest)
        duration_seconds = int(time.time() - t0)
        metrics.phase2_complete(
            total=len(matches),
            success=manifest.completed_count,
            skipped=manifest.skipped_count,
            duration_seconds=duration_seconds,
        )
        outcome_checkpoint.sync(manifest)
        save_manifest(manifest)
        logger.info(
            "match_detail_extraction_complete",
            total=len(matches),
            done=manifest.completed_count,
            failed=manifest.failed_count,
            skipped=manifest.skipped_count,
            completed_progress=manifest.completed_progress,
            duration_seconds=duration_seconds,
        )
        return manifest

    _warmup_cloudflare(driver, sport=sport)

    for i, match_info in enumerate(matches_to_scrape, 1):
        match_id = _match_id(match_info)
        out_path = get_match_file(date_str, match_id, sport=sport)

        if circuit_breaker.aborted:
            logger.warning(
                "circuit_breaker_skipping_remaining", remaining=len(matches_to_scrape) - i + 1
            )
            break

        manifest.set_in_progress(match_id)
        save_manifest(manifest)

        logger.info(
            "match_scrape_start",
            match_id=match_id,
            progress=f"{i}/{len(matches_to_scrape)}",
            completed_progress=manifest.completed_progress,
        )

        last_error = None
        for attempt in range(max_retries + 1):
            try:
                match_data = scrape_match(driver, match_info, sport=sport)
                save_json(match_data, out_path)

                manifest = outcome_checkpoint.done(match_id)

                success_count += 1
                circuit_breaker.record_success()

                logger.info(
                    "match_scrape_success",
                    match_id=match_id,
                    progress=f"{i}/{len(matches_to_scrape)}",
                    completed_progress=manifest.completed_progress,
                )
                last_error = None
                break

            except FootballOddsUnavailableError as e:
                manifest = outcome_checkpoint.skipped(
                    match_id,
                    "all_odds_unavailable",
                    error=str(e),
                    url=_match_link(match_info),
                )
                skipped_count += 1
                circuit_breaker.record_success()
                logger.warning(
                    "match_skipped",
                    match_id=match_id,
                    reason="all_odds_unavailable",
                    error=str(e),
                    source="match_page",
                )
                last_error = None
                break
            except Exception as e:
                last_error = e
                if attempt < max_retries:
                    manifest.record_retry(match_id, str(e))
                    save_manifest(manifest)
                    delay = _retry_delay(attempt, e)
                    jitter = random.uniform(0, delay * 0.5)
                    restart_driver = _driver_restart_required(e)
                    logger.warning(
                        "match_retry",
                        match_id=match_id,
                        attempt=attempt + 1,
                        max_retries=max_retries,
                        delay_s=round(delay + jitter, 1),
                        restart_driver=restart_driver,
                        error=str(e),
                    )
                    if restart_driver and hasattr(driver, "reconnect"):
                        try:
                            driver.reconnect()
                            _warmup_cloudflare(driver, sport=sport)
                        except Exception as reconnect_error:
                            logger.warning("driver_reconnect_failed", error=str(reconnect_error))
                    time.sleep(delay + jitter)
                else:
                    logger.error(
                        "match_scrape_failed",
                        match_id=match_id,
                        error=str(e),
                        retries=manifest.get_retry_count(match_id),
                    )
                    metrics.record_scrape_error(type(e).__name__)
                    manifest = outcome_checkpoint.failed(match_id)
                    failed_count += 1
                    circuit_breaker.record_failure()

        if i < len(matches_to_scrape) and last_error is None:
            random_delay()

    manifest.clear_in_progress()
    save_manifest(manifest)

    duration_seconds = int(time.time() - t0)
    metrics.phase2_complete(
        total=len(matches),
        success=manifest.completed_count,
        skipped=manifest.skipped_count,
        duration_seconds=duration_seconds,
    )
    outcome_checkpoint.sync(manifest)
    save_manifest(manifest)

    logger.info(
        "match_detail_extraction_complete",
        total=len(matches),
        done=manifest.completed_count,
        failed=manifest.failed_count,
        skipped=manifest.skipped_count,
        completed_progress=manifest.completed_progress,
        duration_seconds=duration_seconds,
    )


def _phase2_scrape_concurrent(
    matches, date_str, retry_failed, workers, max_retries: int = 3, sport: str = "football"
):
    """Extract match details concurrently with one Chrome instance per worker.

    Workers process disjoint batches sequentially (with delays between matches
    per worker) to respect rate limits.  Manifest updates are serialised via
    a thread lock.
    """
    sport = normalize_sport(sport)
    metrics = get_metrics()
    outcome_checkpoint = TerminalOutcomeCheckpoint(date_str, sport, metrics)
    metrics.phase2_start(total=len(matches))
    t0 = time.time()

    logger.info(
        "match_detail_extraction_concurrent_start",
        sport=sport,
        total_matches=len(matches),
        date=date_str,
        workers=workers,
    )
    matches_dir = get_matches_dir(date_str, sport=sport)
    os.makedirs(matches_dir, exist_ok=True)

    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        manifest = create_manifest(date_str, len(matches), sport=sport)
    elif manifest.total != len(matches):
        manifest.total = len(matches)
        save_manifest(manifest)

    _audit_before_scrape(date_str, sport=sport)
    manifest = load_manifest(date_str, sport=sport) or manifest

    failed_set = {str(match_id) for match_id in manifest.failed}
    if retry_failed and failed_set:
        logger.info("retrying_failed_matches", failed_count=len(failed_set))

    matches_to_scrape, skipped_count, reconciled_count = _select_matches_to_scrape(
        matches,
        matches_dir,
        manifest,
        date_str,
        retry_failed=retry_failed,
        sport=sport,
    )
    if reconciled_count:
        save_manifest(manifest)
        logger.info("manifest_reconciled_from_json_files", count=reconciled_count)
    outcome_checkpoint.sync(manifest)

    logger.info(
        "scraping_matches_concurrent",
        to_scrape=len(matches_to_scrape),
        already_done=skipped_count,
        previously_failed=len(failed_set),
        workers=workers,
    )

    if not matches_to_scrape:
        manifest.clear_in_progress()
        save_manifest(manifest)
        duration_seconds = int(time.time() - t0)
        metrics.phase2_complete(
            total=len(matches),
            success=manifest.completed_count,
            skipped=manifest.skipped_count,
            duration_seconds=duration_seconds,
        )
        outcome_checkpoint.sync(manifest)
        save_manifest(manifest)
        logger.info(
            "match_detail_extraction_concurrent_complete",
            total=len(matches),
            done=manifest.completed_count,
            failed=manifest.failed_count,
            skipped=manifest.skipped_count,
            duration_seconds=duration_seconds,
        )
        return manifest

    # Split matches into roughly equal batches per worker
    batches = [[] for _ in range(workers)]
    for i, match_info in enumerate(matches_to_scrape):
        batches[i % workers].append(match_info)

    # Pre-initialise all drivers in the main thread (serialised) so that
    # undetected_chromedriver does not race on binary patching.
    logger.info("initialising_worker_drivers", count=workers)
    worker_dirs = []
    worker_drivers = []
    for w in range(workers):
        d = tempfile.mkdtemp(prefix=f"oddspedia_profile_{w}_")
        worker_dirs.append(d)
        try:
            driver = DriverManager(headless=False, block_images=True, user_data_dir=d)
            worker_drivers.append(driver)
        except Exception as e:
            logger.error("worker_driver_init_failed", worker=w, error=str(e))
            worker_drivers.append(None)

    success_count = 0
    failed_count = 0
    circuit_breaker = _CircuitBreaker(metrics)

    def _worker_task(batch, worker_id, driver):
        """Long-lived worker: owns one Chrome instance, processes its batch."""
        worker_results = []
        if driver is None:
            logger.error("worker_no_driver", worker=worker_id)
            return [
                (match_id, False, "driver_init_failed")
                for match_info in batch
                for match_id in [_match_id(match_info)]
            ]

        try:
            try:
                _warmup_cloudflare(driver, sport=sport)
            except Exception as e:
                logger.warning("worker_warmup_failed", worker=worker_id, error=str(e))
                if hasattr(driver, "reconnect"):
                    try:
                        driver.reconnect()
                    except Exception:
                        pass
            for j, match_info in enumerate(batch):
                match_id = _match_id(match_info)
                out_path = get_match_file(date_str, match_id, sport=sport)

                if circuit_breaker.aborted:
                    logger.warning(
                        "circuit_breaker_skipping_worker_batch",
                        worker=worker_id,
                        remaining=len(batch) - j,
                    )
                    break

                update_manifest(
                    date_str,
                    lambda m, mid=match_id, wid=worker_id: m.set_in_progress(mid, worker_id=wid),
                    sport=sport,
                )

                logger.info(
                    "concurrent_match_start",
                    worker=worker_id,
                    match_id=match_id,
                    progress=f"{j + 1}/{len(batch)}",
                )

                last_error = None
                for attempt in range(max_retries + 1):
                    try:
                        match_data = scrape_match(driver, match_info, sport=sport)
                        save_json(match_data, out_path)
                        outcome_checkpoint.done(match_id)
                        worker_results.append((match_id, True, None))
                        logger.info("concurrent_match_success", worker=worker_id, match_id=match_id)
                        last_error = None
                        circuit_breaker.record_success()
                        break
                    except FootballOddsUnavailableError as e:
                        outcome_checkpoint.skipped(
                            match_id,
                            "all_odds_unavailable",
                            error=str(e),
                            url=_match_link(match_info),
                        )
                        worker_results.append((match_id, None, str(e)))
                        logger.warning(
                            "match_skipped",
                            worker=worker_id,
                            match_id=match_id,
                            reason="all_odds_unavailable",
                            error=str(e),
                            source="match_page",
                        )
                        last_error = None
                        circuit_breaker.record_success()
                        break
                    except Exception as e:
                        last_error = e
                        if attempt < max_retries:
                            update_manifest(
                                date_str,
                                lambda m, mid=match_id, err=str(e): m.record_retry(mid, err),
                                sport=sport,
                            )
                            delay = _retry_delay(attempt, e)
                            jitter = random.uniform(0, delay * 0.5)
                            restart_driver = _driver_restart_required(e)
                            logger.warning(
                                "concurrent_match_retry",
                                worker=worker_id,
                                match_id=match_id,
                                attempt=attempt + 1,
                                max_retries=max_retries,
                                delay_s=round(delay + jitter, 1),
                                restart_driver=restart_driver,
                                error=str(e),
                            )
                            if restart_driver and hasattr(driver, "reconnect"):
                                try:
                                    driver.reconnect()
                                    _warmup_cloudflare(driver, sport=sport)
                                except Exception as reconnect_error:
                                    logger.warning(
                                        "driver_reconnect_failed",
                                        worker=worker_id,
                                        error=str(reconnect_error),
                                    )
                            time.sleep(delay + jitter)
                        else:
                            logger.error(
                                "concurrent_match_failed",
                                worker=worker_id,
                                match_id=match_id,
                                error=str(e),
                            )
                            metrics.record_scrape_error(type(e).__name__)
                            outcome_checkpoint.failed(match_id)
                            worker_results.append((match_id, False, str(e)))
                            circuit_breaker.record_failure()

                if j < len(batch) - 1 and last_error is None:
                    delay = random.uniform(WORKER_MIN_DELAY, WORKER_MAX_DELAY)
                    logger.debug("worker_delay", worker=worker_id, delay_s=round(delay, 1))
                    time.sleep(delay)
        finally:
            driver.quit()
        return worker_results

    completed_futures = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(_worker_task, batch, wid, worker_drivers[wid]): wid
            for wid, batch in enumerate(batches)
            if batch
        }
        for future in as_completed(futures):
            wid = futures[future]
            try:
                results = future.result()
                for match_id, success, err in results:
                    if success is True:
                        success_count += 1
                    elif success is False:
                        failed_count += 1
                completed_futures += 1
                logger.info("worker_finished", worker=wid, count=len(results))
            except Exception as e:
                logger.error("worker_crashed", worker=wid, error=str(e))

    update_manifest(date_str, lambda m: m.clear_in_progress(), sport=sport)
    manifest = load_manifest(date_str, sport=sport) or manifest

    duration_seconds = int(time.time() - t0)
    metrics.phase2_complete(
        total=len(matches),
        success=manifest.completed_count,
        skipped=manifest.skipped_count,
        duration_seconds=duration_seconds,
    )
    outcome_checkpoint.sync(manifest)
    save_manifest(manifest)

    logger.info(
        "match_detail_extraction_concurrent_complete",
        total=len(matches),
        done=manifest.completed_count,
        failed=manifest.failed_count,
        skipped=manifest.skipped_count,
        completed_progress=manifest.completed_progress,
        duration_seconds=duration_seconds,
    )

    # Clean up temp Chrome profile directories
    for d in worker_dirs:
        try:
            shutil.rmtree(d, ignore_errors=True)
        except Exception:
            pass

    return manifest


def _parse_month(month_str):
    """Parse a YYYYMM month argument and return (year, month)."""
    try:
        parsed = datetime.strptime(normalize_month(month_str), "%Y%m")
    except ValueError:
        logger.error("invalid_month_format", month=month_str)
        sys.exit(1)
    return parsed.year, parsed.month


def _dates_for_month(month_str):
    """Return every YYYYMMDD date identifier in a YYYYMM month."""
    year, month = _parse_month(month_str)
    last_day = calendar.monthrange(year, month)[1]
    return [date(year, month, day).strftime("%Y%m%d") for day in range(1, last_day + 1)]


def _resolve_dates(args):
    """Resolve CLI date/month arguments into one or more date strings."""
    if args.month:
        dates = _dates_for_month(args.month)
    else:
        date_str = args.date or datetime.now().strftime("%Y%m%d")
        try:
            dates = [normalize_date(date_str)]
        except ValueError:
            logger.error("invalid_date_format", date=date_str)
            sys.exit(1)

    today = datetime.now().date()
    selected_dates = [datetime.strptime(date_str, "%Y%m%d").date() for date_str in dates]
    if any(selected_date > today for selected_date in selected_dates):
        logger.error("future_collection_date", dates=dates, today=today.strftime("%Y%m%d"))
        sys.exit(1)
    return [date_str for date_str in dates if datetime.strptime(date_str, "%Y%m%d").date() <= today]


def _print_status(date_str, sport: str = "football"):
    """Print scrape status for one date."""
    sport = normalize_sport(sport)
    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        logger.info("no_manifest_found", sport=sport, date=date_str)
        print(f"No manifest found for {sport} on {date_str}")
        return
    print(f"\n=== Scrape Status for {sport} on {date_str} ===")
    print(f"Total: {manifest.total}")
    print(f"Done: {manifest.completed_count} ({manifest.completed_progress}%)")
    print(f"Skipped: {manifest.skipped_count}")
    print(f"Failed: {manifest.failed_count}")
    print(f"Incomplete: {manifest.incomplete_count}")
    if manifest.in_progress:
        active = ", ".join(
            f"{worker_id}:{match_id}"
            for worker_id, match_id in sorted(manifest.in_progress.items())
        )
    else:
        active = "None"
    print(f"In Progress: {active}")
    print(f"Remaining: {manifest.remaining}")
    if manifest.failed:
        print(f"\nFailed match IDs: {', '.join(manifest.failed)}")
    if manifest.incomplete:
        print(f"\nIncomplete match IDs: {', '.join(manifest.incomplete)}")
    if manifest.discovery:
        discovery = manifest.discovery
        print(
            "\nEvent Discovery: "
            f"{discovery.get('status', 'unknown')} "
            f"({discovery.get('observed_pages', 0)}/{discovery.get('expected_pages', 0)} pages)"
        )
        if discovery.get("reasons"):
            print(f"Discovery reasons: {', '.join(discovery['reasons'])}")
    if manifest.skipped:
        skipped = ", ".join(
            f"{match_id} ({entry.get('reason', 'unknown')})"
            for match_id, entry in manifest.skipped.items()
        )
        print(f"\nSkipped matches: {skipped}")
    logger.info("manifest_status_shown", **manifest.to_dict())


def main(argv=None, default_sport="football"):
    """Run the shared pipeline.

    ``default_sport`` is used by the sport-specific project entry points.
    The football project owns this complete collection, manifest, retry,
    logging, and status pipeline.
    """
    parser = argparse.ArgumentParser(
        description="OddsHarvest football scraper",
        epilog="Commands: discover (event links only), scrape (saved links only), "
        "run (discover then scrape), status.",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=("discover", "scrape", "run", "status"),
        help="Action to run (default: run)",
    )
    legacy_actions = parser.add_mutually_exclusive_group()
    legacy_actions.add_argument(
        "--collect",
        dest="legacy_command",
        action="store_const",
        const="discover",
        help="Deprecated alias for 'discover'",
    )
    legacy_actions.add_argument(
        "--scrape",
        dest="legacy_command",
        action="store_const",
        const="scrape",
        help="Deprecated alias for 'scrape'",
    )
    legacy_actions.add_argument(
        "--status",
        dest="legacy_command",
        action="store_const",
        const="status",
        help="Deprecated alias for 'status'",
    )
    parser.add_argument(
        "--headless", action="store_true", help="Run in headless mode (may fail CF)"
    )
    parser.add_argument(
        "--images",
        "--load-images",
        dest="load_images",
        action="store_true",
        help="Allow Chrome to load images (disabled by default to reduce bandwidth; --load-images is an alias)",
    )
    date_group = parser.add_mutually_exclusive_group()
    date_group.add_argument(
        "--date",
        default=None,
        metavar="YYYYMMDD",
        help="Target date for the selected command (default: today). Use YYYYMMDD format.",
    )
    date_group.add_argument(
        "--month",
        default=None,
        metavar="YYYYMM",
        help="Target month for the selected command. Runs each day in the month.",
    )
    log_format = parser.add_mutually_exclusive_group()
    log_format.add_argument(
        "--log-format",
        choices=("text", "json"),
        default="text",
        help="Terminal and persisted log format (default: text)",
    )
    log_format.add_argument(
        "--json-logs",
        dest="log_format",
        action="store_const",
        const="json",
        help="Deprecated alias for '--log-format json'",
    )
    retry = parser.add_mutually_exclusive_group()
    retry.add_argument(
        "--retry",
        choices=("failed", "incomplete"),
        help="Retry failed match details or incomplete event discovery",
    )
    retry.add_argument(
        "--retry-failed",
        dest="retry",
        action="store_const",
        const="failed",
        help="Deprecated alias for '--retry failed'",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=None,
        metavar="N",
        help="Number of concurrent Chrome workers (default: 1, sequential). "
        "Each worker gets its own browser instance and profile dir. "
        "Recommended: 3 workers with default per-worker delays.",
    )
    args = parser.parse_args(argv)
    if args.command and args.legacy_command:
        parser.error("choose either a command or a legacy action flag, not both")
    command = args.command or args.legacy_command or "run"
    if args.retry == "failed" and command not in {"scrape", "run"}:
        parser.error("--retry failed is only valid with 'scrape' or 'run'")
    if args.retry == "incomplete" and command != "discover":
        parser.error("--retry incomplete is only valid with 'discover'")
    sport = normalize_sport(default_sport)

    dates = _resolve_dates(args)

    # Persist every terminal event alongside the data being scraped. A month
    # run receives its own directory because its events span multiple dates.
    log_date = dates[0]
    run_started_at = datetime.now()
    run_id = run_started_at.strftime("%Y%m%dT%H%M%S")
    run_dir = get_run_logs_dir(log_date, sport=sport)
    log_path = os.path.join(run_dir, f"run_{run_id}.log")
    configure_logging(json_logs=args.log_format == "json", log_file=log_path)
    logger.info(
        "run_log_started",
        log_path=log_path,
        run_id=run_id,
        sport=sport,
        dates=dates,
    )
    persist_manifest_metrics = False

    if command == "status":
        for date_str in dates:
            _print_status(date_str, sport=sport)
        metrics = get_metrics()
        metrics.finish()
        metrics.log_summary()
        return

    workers = args.workers or 1
    if workers < 1:
        logger.error("invalid_workers", workers=workers)
        sys.exit(1)

    reset_metrics()
    get_metrics().set_context(
        run_id=run_id,
        sport=sport,
        target_dates=dates,
        log_path=log_path,
    )
    persist_manifest_metrics = True
    logger.info("scraper_start", sport=sport, dates=dates, headless=args.headless, workers=workers)

    driver = None
    try:

        def ensure_driver():
            nonlocal driver
            if driver is None:
                driver = DriverManager(headless=args.headless, block_images=not args.load_images)
            return driver

        if command == "discover":
            listing_ready = False
            for date_str in dates:
                if args.retry == "incomplete" and not _needs_discovery_retry(date_str, sport):
                    logger.info("discovery_retry_not_needed", sport=sport, date=date_str)
                    continue
                links_file = get_match_links_file(date_str, sport=sport)
                inventory_valid = _existing_inventory_matches_target(links_file, date_str)
                collect_driver = (
                    None if inventory_valid and args.retry != "incomplete" else ensure_driver()
                )
                matches = phase1_collect(
                    collect_driver,
                    date_str,
                    sport=sport,
                    reuse_listing=listing_ready,
                    force=args.retry == "incomplete",
                )
                # Existing inventories do not change the browser's location.
                # Once a discovery succeeds, later dates can stay on this
                # listing and change only the date picker.
                if collect_driver is not None and matches:
                    listing_ready = True
            get_metrics().log_summary()
            return

        if command == "scrape":
            scraped_any = False
            for date_str in dates:
                links_file = get_match_links_file(date_str, sport=sport)
                if not os.path.exists(links_file):
                    logger.error(
                        "links_file_not_found",
                        sport=sport,
                        links_file=links_file,
                        date=date_str,
                    )
                    if not args.month:
                        sys.exit(1)
                    continue
                matches = _as_match_list(load_json(links_file))
                if not listing_matches_target_date(matches, date_str):
                    logger.error(
                        "links_file_target_date_mismatch",
                        sport=sport,
                        date=date_str,
                        links_file=links_file,
                    )
                    continue
                scrape_driver = None if workers > 1 else ensure_driver()
                phase2_scrape(
                    scrape_driver,
                    matches,
                    date_str,
                    retry_failed=args.retry == "failed",
                    workers=workers,
                    sport=sport,
                )
                logger.info("scrape_json_complete", sport=sport, date=date_str)
                scraped_any = True
            if not scraped_any:
                logger.error("no_month_links_found", month=args.month)
                sys.exit(1)
            get_metrics().log_summary()
            return

        for date_str in dates:
            links_file = get_match_links_file(date_str, sport=sport)
            collect_driver = (
                None
                if _existing_inventory_matches_target(links_file, date_str)
                else ensure_driver()
            )
            matches = phase1_collect(collect_driver, date_str, sport=sport)
            if matches:
                scrape_driver = None if workers > 1 else ensure_driver()
                phase2_scrape(
                    scrape_driver,
                    matches,
                    date_str,
                    retry_failed=args.retry == "failed",
                    workers=workers,
                    sport=sport,
                )
                logger.info("scrape_json_complete", sport=sport, date=date_str)

        get_metrics().log_summary()

    except KeyboardInterrupt:
        logger.info("interrupted_by_user")
    except Exception:
        logger.exception("fatal_error")
        sys.exit(1)
    finally:
        metrics = get_metrics()
        metrics.finish()
        if persist_manifest_metrics:
            for date_str in dates:
                if load_manifest(date_str, sport=sport) is not None:
                    update_manifest(
                        date_str,
                        lambda manifest: manifest.update_metrics(metrics.manifest_snapshot()),
                        sport=sport,
                    )
        metrics.log_summary()
        if driver:
            logger.info("Shutting down browser...")
            driver.quit()

    logger.info("Done.")


def project_main():
    """Console-script adapter for the standalone football project."""
    main(default_sport="football")


if __name__ == "__main__":
    project_main()
