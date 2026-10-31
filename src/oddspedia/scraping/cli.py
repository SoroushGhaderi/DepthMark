#!/usr/bin/env python3
"""Oddspedia event-intake command implementation.

Usage:
    python scripts/oddspedia/run_oddspedia_pipeline.py --date 20260227 --silver-reference-window-ready
    python scripts/oddspedia/run_oddspedia_pipeline.py --headless --date 20260227 --silver-reference-window-ready
    python scripts/oddspedia/discover_oddspedia_events.py --month 202607
    python scripts/oddspedia/prioritize_oddspedia_events.py --date 20260711 --silver-reference-window-ready
    python scripts/oddspedia/scrape_oddspedia_matches.py --date 20260711
    python scripts/oddspedia/run_oddspedia_pipeline.py --month 202607 --silver-reference-window-ready
    python scripts/oddspedia/events.py --collect --month 202607      # Legacy alias for discover

Alternatively (after ``pip install -e .``):
    oddspedia-scraper --help
"""

import argparse
import os
import random
import shutil
import sys
import tempfile
import threading
import time
from collections.abc import Iterator, Sequence
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager, nullcontext
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from selenium.common.exceptions import (
    InvalidSessionIdException,
    NoSuchWindowException,
    WebDriverException,
)

from src.common.dates import normalize_compact_date
from src.common.run_scope import resolve_date_scope
from src.oddspedia.scraping.audit import (
    audit_date,
    audit_match_json,
    audit_match_payload,
    require_accepted_match_json,
    sync_manifest_incomplete,
)
from src.oddspedia.scraping.config import (
    FOOTBALL_ODDS_MAX_ATTEMPTS,
    get_settings,
    get_sport_listing_url,
    normalize_sport,
)
from src.oddspedia.scraping.driver import DriverManager
from src.oddspedia.scraping.link_prioritization import (
    LinkPriorityService,
    load_priority_artifact,
    priority_artifact_is_current,
    priority_run_summary,
    save_priority_artifact,
    select_links_for_priority,
    source_inventory_checksum,
)
from src.oddspedia.scraping.logging import configure_logging, get_logger
from src.oddspedia.scraping.manifest import (
    create_manifest,
    load_manifest,
    save_manifest,
    update_manifest,
)
from src.oddspedia.scraping.match_collector import collect_match_links, listing_matches_target_date
from src.oddspedia.scraping.match_scraper import (
    MatchPageNotRenderedError,
    scrape_match,
)
from src.oddspedia.scraping.metrics import get_metrics, reset_metrics
from src.oddspedia.scraping.odds_contract import (
    FootballOddsCoverageError,
    FootballOddsRetryableError,
    FootballOddsUnavailableError,
)
from src.oddspedia.scraping.operation_lock import oddspedia_date_lock
from src.oddspedia.scraping.paths import (
    get_discovery_snapshot_file,
    get_match_file,
    get_match_links_file,
    get_matches_dir,
    get_prioritized_match_links_file,
    get_run_logs_dir,
    get_storage_aspect,
)
from src.oddspedia.scraping.progress import TerminalOutcomeCheckpoint
from src.oddspedia.scraping.storage import (
    compress_date_files,
    read_match_payload,
)
from src.oddspedia.scraping.utils import (
    MATCH_LINKS_ARTIFACT,
    MATCH_PAYLOAD_ARTIFACT,
    load_json,
    random_delay,
    save_json,
)
from src.oddspedia.silver.match_resolution import OddspediaMatchResolver
from src.warehouse.identities import warehouse_session

configure_logging()
logger = get_logger("oddspedia")

CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE = 5
CIRCUIT_BREAKER_COOLDOWN_SECONDS = 120
CIRCUIT_BREAKER_PAUSE_CYCLES_BEFORE_ABORT = 3
FOOTBALL_SKIP_STATUSES = {"POSTPONED", "CANCELLED", "CANCELED", "ABANDONED", "SUSPENDED"}
ACCEPTED_DISCOVERY_STATUSES = {"accepted", "no_events"}
# One initial read plus two fresh-listing retries. Partial inventories are
# diagnostic only, so a date must get multiple chances to produce a complete
# target-date link set before discovery is allowed to fail closed.
DISCOVERY_MAX_ATTEMPTS = 3
PROJECT_ROOT = Path(__file__).resolve().parents[3]


def _skip_reason(match_info, sport: str):
    status = str(match_info.get("status", "")).strip().upper()
    if sport == "football" and status in FOOTBALL_SKIP_STATUSES:
        return "non_playable_status"
    return None


def _driver_restart_required(exc: Exception) -> bool:
    """Only replace Chrome when the browser session itself is unusable."""
    if isinstance(
        exc, (InvalidSessionIdException, NoSuchWindowException, MatchPageNotRenderedError)
    ):
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


def _match_payload_path(matches_dir: str, match_id: str) -> str:
    """Return the payload path within the collection run's explicit output directory."""
    return os.path.join(matches_dir, f"{match_id}.json")


def _select_matches_to_scrape(
    matches,
    matches_dir,
    manifest,
    date_str,
    retry_failed: bool = False,
    sport: str = "football",
    audit_result=None,
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
    retry_only = retry_failed and bool(failed_set)

    audited_by_id = {}
    missing_ids = set()
    if audit_result is not None:
        audited_by_id = {
            audit.match_id: audit for audit in audit_result.incomplete + audit_result.invalid
        }
        missing_ids = {audit.match_id for audit in audit_result.missing}

    for match_info in matches:
        match_id = _match_id(match_info)
        if match_id in skipped_set:
            skipped_count += 1
            continue
        if audit_result is not None:
            json_audit = audited_by_id.get(match_id)
            has_json = match_id not in missing_ids
        else:
            out_path = _match_payload_path(matches_dir, match_id)
            if os.path.exists(out_path):
                has_json = True
                json_audit = audit_match_json(
                    date_str,
                    match_id,
                    out_path,
                    sport=sport,
                    expected_match=match_info,
                )
            else:
                stored = read_match_payload(date_str, match_id, sport=sport)
                has_json = stored is not None
                json_audit = (
                    audit_match_payload(
                        date_str,
                        match_id,
                        stored.payload,
                        stored.source_file,
                        stored.size_bytes,
                        sport=sport,
                        expected_match=match_info,
                    )
                    if stored is not None
                    else None
                )

        if has_json and (json_audit is None or json_audit.accepted):
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
        elif not retry_only:
            matches_to_scrape.append(match_info)

    return matches_to_scrape, skipped_count, reconciled_count


def _scrape_scope_terminal_counts(matches, manifest):
    """Count terminal outcomes only for the matches scraped in this run."""
    selected_ids = {_match_id(match_info) for match_info in matches}
    done_ids = {str(match_id) for match_id in manifest.done}
    skipped_ids = {str(match_id) for match_id in manifest.skipped}
    failed_ids = {str(match_id) for match_id in manifest.failed}
    return (
        len(selected_ids & done_ids),
        len(selected_ids & skipped_ids),
        len(selected_ids & failed_ids),
    )


def _scrape_scope_progress(matches, manifest):
    """Return completion percentage for the current run's scrape scope."""
    selected_total = len(matches)
    if selected_total == 0:
        return 0.0
    done_count, skipped_count, _ = _scrape_scope_terminal_counts(matches, manifest)
    return round((done_count + skipped_count) / selected_total * 100, 2)


class _MatchProgressReporter:
    """Emit FotMob-shaped progress updates for one Oddspedia scrape batch."""

    def __init__(
        self,
        date_str: str,
        sport: str,
        total: int,
        previously_scraped: int = 0,
        previously_skipped: int = 0,
    ):
        self.date_str = date_str
        self.sport = sport
        self.total = total
        self.previously_scraped = previously_scraped
        self.previously_skipped = previously_skipped
        self.completed = 0
        self.successful = 0
        self.failed = 0
        self.skipped = 0
        self._lock = threading.Lock()

    def record(self, outcome: str, match_id: str) -> None:
        """Record one terminal batch outcome and log the aggregate progress."""
        with self._lock:
            self.completed += 1
            if outcome == "success":
                self.successful += 1
            elif outcome == "failed":
                self.failed += 1
            elif outcome == "skipped":
                self.skipped += 1
            else:
                raise ValueError(f"Unsupported progress outcome: {outcome}")

            progress_pct = (
                100.0 if self.total == 0 else round((self.completed / self.total) * 100, 1)
            )
            logger.info(
                "[PROGRESS] Match processing update",
                sport=self.sport,
                date=self.date_str,
                match_id=match_id,
                completed=self.completed,
                total=self.total,
                progress_pct=progress_pct,
                successful_matches=self.successful,
                failed_matches=self.failed,
                skipped_matches=(self.previously_scraped + self.previously_skipped + self.skipped),
                previously_scraped_matches=self.previously_scraped,
            )

    def snapshot(self):
        """Return the current progress fields for summary logging."""
        with self._lock:
            return {
                "completed": self.completed,
                "total": self.total,
                "progress_pct": (
                    100.0 if self.total == 0 else round((self.completed / self.total) * 100, 1)
                ),
                "successful_matches": self.successful,
                "failed_matches": self.failed,
                "skipped_matches": self.previously_scraped + self.previously_skipped + self.skipped,
                "previously_scraped_matches": self.previously_scraped,
            }


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
    payload["inventory_checksum"] = source_inventory_checksum(_as_match_list(discovery.matches))
    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        manifest = create_manifest(date_str, 0, sport=sport)
    manifest.record_discovery(payload)
    save_manifest(manifest)


def _needs_discovery_retry(date_str, sport: str) -> bool:
    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        return True
    if manifest.discovery.get("status") == "rescrape_candidate":
        return True
    if manifest.discovery.get("status") not in ACCEPTED_DISCOVERY_STATUSES:
        return True
    if manifest.incomplete:
        logger.info(
            "incomplete_matches_require_link_refresh",
            sport=sport,
            date=date_str,
            count=len(manifest.incomplete),
        )
        return True
    links_file = get_match_links_file(date_str, sport=sport)
    if not os.path.exists(links_file):
        return False
    if not _existing_inventory_matches_target(links_file, date_str, sport=sport):
        return True
    try:
        links = _as_match_list(load_json(links_file))
        discovery = manifest.discovery or {}
        return bool(links) and (
            int(discovery.get("match_count", -1)) != len(links)
            or discovery.get("inventory_checksum") != source_inventory_checksum(links)
        )
    except Exception as exc:
        logger.warning(
            "discovery_inventory_validation_failed", date=date_str, error=str(exc), exc_info=True
        )
        return True


def _as_match_list(matches):
    """Normalise legacy dict inventories and new discovery maps to a list."""
    if isinstance(matches, dict):
        return list(matches.values())
    return list(matches or [])


def _existing_inventory_matches_target(links_file, date_str, sport: str = "football") -> bool:
    """Validate an on-disk inventory, including an explicitly confirmed empty day."""
    if not os.path.exists(links_file):
        return False
    try:
        links = _as_match_list(load_json(links_file))
        if links:
            return listing_matches_target_date(links, date_str)
        manifest = load_manifest(date_str, sport=sport)
        discovery = manifest.discovery if manifest else {}
        return (
            manifest is not None
            and normalize_compact_date(manifest.date) == normalize_compact_date(date_str)
            and discovery.get("status") == "no_events"
            and bool(discovery.get("empty_confirmed"))
            and int(discovery.get("match_count", -1)) == 0
            and discovery.get("inventory_checksum") == source_inventory_checksum([])
        )
    except Exception as exc:
        logger.warning(
            "existing_inventory_unreadable", links_file=links_file, error=str(exc), exc_info=True
        )
        return False


def _discovery_is_accepted(date_str: str, sport: str = "football") -> bool:
    """Return whether the manifest has an authoritative result for a date."""
    manifest = load_manifest(date_str, sport=sport)
    if not manifest or manifest.discovery.get("status") not in ACCEPTED_DISCOVERY_STATUSES:
        return False
    links_file = get_match_links_file(date_str, sport=sport)
    if not _existing_inventory_matches_target(links_file, date_str, sport=sport):
        return False
    try:
        links = _as_match_list(load_json(links_file))
        discovery = manifest.discovery or {}
        return not links or (
            int(discovery.get("match_count", -1)) == len(links)
            and discovery.get("inventory_checksum") == source_inventory_checksum(links)
        )
    except Exception as exc:
        logger.warning(
            "accepted_discovery_validation_failed", date=date_str, error=str(exc), exc_info=True
        )
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
        and _existing_inventory_matches_target(links_file, date_str, sport=sport)
        and not _needs_discovery_retry(date_str, sport)
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
    discovery = None
    for attempt in range(1, DISCOVERY_MAX_ATTEMPTS + 1):
        discovery = collect_match_links(
            driver,
            target_date=date_str,
            sport=sport,
            # A retry must rebuild the listing state. Reusing a listing that
            # already yielded a partial result can reproduce the same gap.
            reuse_listing=reuse_listing if attempt == 1 else False,
            return_result=True,
        )
        if discovery.complete:
            break
        if attempt == DISCOVERY_MAX_ATTEMPTS:
            break
        logger.info(
            "event_discovery_retrying_fresh_listing",
            sport=sport,
            date=date_str,
            attempt=attempt + 1,
            max_attempts=DISCOVERY_MAX_ATTEMPTS,
            anomalies=discovery.anomalies,
        )

    # A complete result is the only result that can become match_links.json.
    # Any final incomplete result is retained below as a diagnostic snapshot
    # and causes the caller to fail the date rather than scrape partial links.
    if discovery is None:
        raise RuntimeError(f"Discovery did not run for {sport} {date_str}")
    matches = _as_match_list(discovery.matches)
    if not matches:
        if discovery.complete and discovery.empty_confirmed:
            save_json([], links_file, artifact_type=MATCH_LINKS_ARTIFACT)
            _record_discovery(date_str, sport, discovery)
            logger.info(
                "event_discovery_no_events",
                sport=sport,
                date=date_str,
                expected_pages=discovery.expected_pages,
                observed_pages=discovery.observed_pages,
            )
            return []
        snapshot = get_discovery_snapshot_file(date_str, sport=sport)
        save_json([], snapshot, artifact_type=MATCH_LINKS_ARTIFACT)
        _record_discovery(date_str, sport, discovery, snapshot)
        logger.error("no_matches_found", anomalies=discovery.anomalies)
        return []
    if not discovery.complete:
        snapshot = get_discovery_snapshot_file(date_str, sport=sport)
        save_json(matches, snapshot, artifact_type=MATCH_LINKS_ARTIFACT)
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
    save_json(matches, links_file, artifact_type=MATCH_LINKS_ARTIFACT)
    _record_discovery(date_str, sport, discovery)
    logger.info("event_links_saved", sport=sport, links_file=links_file, links_count=len(matches))
    for m in matches[:3]:
        logger.debug("sample_url", url=m.get("full_url", m.get("url", "")))
    return matches


@contextmanager
def _priority_service() -> Iterator[LinkPriorityService]:
    """Connect a source-workflow service to the canonical Silver reference."""
    with warehouse_session() as client:
        yield LinkPriorityService(client, _priority_resolver())


def _priority_resolver() -> OddspediaMatchResolver:
    """Create the versioned shared resolution policy without opening a connection."""
    return OddspediaMatchResolver(
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "scoring_policy.yaml",
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "team_aliases.yaml",
    )


def prioritize_date(
    date_str: str,
    priority: str = "lower",
    dry_run: bool = False,
    sport: str = "football",
    source_links=None,
):
    """Generate and audit one complete, date-scoped priority decision artifact."""
    sport = normalize_sport(sport)
    if get_storage_aspect(date_str) != "historical":
        raise ValueError("Link prioritization requires a completed Historical date")
    links_file = get_match_links_file(date_str, sport=sport)
    if not os.path.exists(links_file):
        raise FileNotFoundError(f"Cannot prioritize without source links: {links_file}")
    if not _discovery_is_accepted(date_str, sport=sport):
        raise ValueError(f"Cannot prioritize without an accepted discovery inventory: {date_str}")
    links = (
        _as_match_list(source_links)
        if source_links is not None
        else _as_match_list(load_json(links_file))
    )
    if links and not listing_matches_target_date(links, date_str):
        raise ValueError(f"Source links do not target {date_str}: {links_file}")

    with _priority_service() as service:
        artifact = service.prioritize(date_str, links, sport=sport)

    artifact_path = get_prioritized_match_links_file(date_str, sport=sport)
    if not dry_run:
        artifact_path = save_priority_artifact(artifact, date_str, sport=sport)
    summary = priority_run_summary(artifact, artifact_path, priority)
    if not dry_run:
        manifest = load_manifest(date_str, sport=sport)
        if manifest is None:
            manifest = create_manifest(date_str, 0, sport=sport)
        manifest.record_priority_run(summary)
        save_manifest(manifest)
    get_metrics().record_link_prioritization(summary)
    logger.info(
        "link_priorities_ready",
        date=date_str,
        priority=priority,
        dry_run=dry_run,
        artifact_path=artifact_path,
        selected_count=len(select_links_for_priority(artifact, priority, links)),
        validation_status_counts=summary["validation_status_counts"],
        priority_counts=summary["priority_counts"],
        match_confidence_counts=summary["match_confidence_counts"],
        team_match_rule_counts=summary["team_match_rule_counts"],
        no_candidate_count=summary["no_candidate_count"],
        matcher_rule_version=summary["matcher_rule_version"],
    )
    return artifact


def _selected_priority_matches(
    date_str: str, priority: str, sport: str = "football", source_links=None
):
    """Ensure, load, and validate the priority decision before page scraping."""
    links_file = get_match_links_file(date_str, sport=sport)
    if not os.path.exists(links_file):
        raise FileNotFoundError(f"Cannot scrape without source links: {links_file}")
    links = (
        _as_match_list(source_links)
        if source_links is not None
        else _as_match_list(load_json(links_file))
    )
    artifact = load_priority_artifact(date_str, sport=sport)
    artifact_path = get_prioritized_match_links_file(date_str, sport=sport)
    matcher_rule_version = _priority_resolver().rule_version
    artifact_needs_refresh = artifact is None or not priority_artifact_is_current(
        artifact,
        date_str,
        links,
        matcher_rule_version=matcher_rule_version,
    )
    if artifact_needs_refresh:
        logger.info(
            "priority_artifact_refresh_required",
            date=date_str,
            priority=priority,
            artifact_path=artifact_path,
            reason="missing" if artifact is None else "stale",
        )
        if source_links is None:
            prioritize_date(date_str, priority=priority, sport=sport)
        else:
            prioritize_date(date_str, priority=priority, sport=sport, source_links=links)
        artifact = load_priority_artifact(date_str, sport=sport)
        if artifact is None:
            raise FileNotFoundError(f"Priority artifact was not created: {artifact_path}")

    if not priority_artifact_is_current(
        artifact,
        date_str,
        links,
        matcher_rule_version=matcher_rule_version,
    ):
        raise ValueError(f"Priority artifact is stale after refresh: {artifact_path}")
    selected = select_links_for_priority(artifact, priority, links)
    manifest = load_manifest(date_str, sport=sport)
    if manifest is None:
        manifest = create_manifest(date_str, 0, sport=sport)
    manifest.record_priority_run(priority_run_summary(artifact, artifact_path, priority))
    save_manifest(manifest)
    logger.info(
        "priority_selection_loaded",
        date=date_str,
        priority=priority,
        source_links=len(links),
        selected_links=len(selected),
        artifact_path=artifact_path,
    )
    return selected


def _warmup_cloudflare(driver, sport: str = "football"):
    """Visit the base site once so Cloudflare cookies are set for the session."""
    from src.oddspedia.scraping.utils import safe_get

    sport = normalize_sport(sport)
    logger.info("cloudflare_warmup_start", sport=sport)
    safe_get(driver, get_sport_listing_url(sport))
    time.sleep(2)


def _audit_before_scrape(date_str, sport: str = "football"):
    """Refresh manifest.incomplete from existing JSON or date archives."""
    audit_result = audit_date(date_str, sport=sport)
    audited_manifest = sync_manifest_incomplete(audit_result)
    logger.info(
        "pre_scrape_audit_complete",
        sport=sport,
        date=date_str,
        missing=len(audit_result.missing),
        incomplete=len(audit_result.incomplete),
        invalid=len(audit_result.invalid),
    )
    return audit_result, audited_manifest


def _compress_completed_date(manifest, date_str: str, sport: str = "football") -> None:
    """Compress one complete historical Oddspedia date without remote storage."""
    if manifest is None or manifest.total <= 0:
        return
    if manifest.failed_count or manifest.incomplete_count or manifest.in_progress:
        logger.info(
            "oddspedia_date_not_compressed",
            sport=sport,
            date=date_str,
            total=manifest.total,
            done=manifest.completed_count,
            skipped=manifest.skipped_count,
            failed=manifest.failed_count,
            incomplete=manifest.incomplete_count,
        )
        return
    if manifest.completed_count + manifest.skipped_count < manifest.total:
        return
    if get_storage_aspect(date_str) != "historical":
        logger.info("oddspedia_live_date_not_compressed", sport=sport, date=date_str)
        return

    logger.info("oddspedia_date_compression_start", sport=sport, date=date_str)
    result = compress_date_files(date_str, sport=sport)
    if result.get("status") not in {"success", "already_compressed", "no_files", "no_directory"}:
        raise RuntimeError(
            f"Oddspedia date compression failed for {date_str}: {result.get('error', 'unknown error')}"
        )
    logger.info(
        "oddspedia_date_compression_complete",
        sport=sport,
        date=date_str,
        status=result.get("status"),
        compressed_files=result.get("compressed", 0),
        archive_file=result.get("archive_file"),
    )


@dataclass
class _Phase2Run:
    """Shared state for one date's match-detail extraction."""

    date_str: str
    sport: str
    max_retries: int
    odds_max_attempts: int
    metrics: Any
    outcome_checkpoint: TerminalOutcomeCheckpoint
    progress_reporter: "_MatchProgressReporter"
    circuit_breaker: "_CircuitBreaker"
    progress_matches: list
    started_at: float


def _start_phase2(matches, date_str, retry_failed, max_retries, sport, workers):
    """Load and audit the manifest and choose the matches still to scrape.

    Returns ``(run, matches_to_scrape, manifest)``.
    """
    metrics = get_metrics()
    outcome_checkpoint = TerminalOutcomeCheckpoint(date_str, sport, metrics)
    started_at = time.time()
    logger.info(
        "match_detail_extraction_start",
        sport=sport,
        total_matches=len(matches),
        date=date_str,
        retry_failed=retry_failed,
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

    audit_result, audited_manifest = _audit_before_scrape(date_str, sport=sport)
    manifest = audited_manifest or manifest

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
        audit_result=audit_result,
    )
    if reconciled_count:
        save_manifest(manifest)
        logger.info("manifest_reconciled_from_json_files", count=reconciled_count)
    match_ids = {_match_id(match_info) for match_info in matches}
    previously_scraped = len(match_ids & {str(match_id) for match_id in manifest.done})
    previously_skipped = len(match_ids & {str(match_id) for match_id in manifest.skipped})
    progress_reporter = _MatchProgressReporter(
        date_str,
        sport,
        len(matches_to_scrape),
        previously_scraped=previously_scraped,
        previously_skipped=previously_skipped,
    )
    progress_matches = matches_to_scrape or matches
    outcome_checkpoint.set_scope(_match_id(match_info) for match_info in progress_matches)
    metrics.phase2_start(total=len(progress_matches))
    outcome_checkpoint.sync(manifest)

    logger.info(
        "scraping_matches",
        to_scrape=len(matches_to_scrape),
        already_done=skipped_count,
        previously_failed=len(failed_set),
        workers=workers,
        completed_progress=_scrape_scope_progress(progress_matches, manifest),
        previously_scraped_matches=previously_scraped,
        skipped_matches=previously_scraped + previously_skipped,
    )
    run = _Phase2Run(
        date_str=date_str,
        sport=sport,
        max_retries=max_retries,
        odds_max_attempts=min(FOOTBALL_ODDS_MAX_ATTEMPTS, max_retries + 1),
        metrics=metrics,
        outcome_checkpoint=outcome_checkpoint,
        progress_reporter=progress_reporter,
        circuit_breaker=_CircuitBreaker(metrics),
        progress_matches=progress_matches,
        started_at=started_at,
    )
    return run, matches_to_scrape, manifest


def _finish_phase2(run: _Phase2Run):
    """Clear in-progress markers, record metrics, and return the saved manifest."""
    manifest = update_manifest(run.date_str, lambda m: m.clear_in_progress(), sport=run.sport)
    manifest = manifest or load_manifest(run.date_str, sport=run.sport)
    duration_seconds = int(time.time() - run.started_at)
    selected_done, selected_skipped, selected_failed = _scrape_scope_terminal_counts(
        run.progress_matches, manifest
    )
    run.metrics.phase2_complete(
        total=len(run.progress_matches),
        success=selected_done,
        skipped=selected_skipped,
        duration_seconds=duration_seconds,
    )
    run.outcome_checkpoint.sync(manifest)
    save_manifest(manifest)
    logger.info(
        "match_detail_extraction_complete",
        done=selected_done,
        failed=selected_failed,
        skipped=selected_skipped,
        completed_progress=_scrape_scope_progress(run.progress_matches, manifest),
        duration_seconds=duration_seconds,
        **run.progress_reporter.snapshot(),
    )
    return manifest


def _reconnect(driver, run: _Phase2Run, worker_id: int) -> None:
    """Replace a broken browser session; the next attempt reports any failure."""
    if not hasattr(driver, "reconnect"):
        return
    try:
        driver.reconnect()
        _warmup_cloudflare(driver, sport=run.sport)
    except Exception as reconnect_error:  # noqa: BLE001 - the next attempt fails and is retried
        logger.warning(
            "driver_reconnect_failed",
            worker=worker_id,
            error=str(reconnect_error),
            exc_info=True,
        )


def scrape_one(driver, match_info, run: _Phase2Run, worker_id: int = 0) -> str:
    """Scrape, save, and accept one match with retries; return its terminal outcome.

    The outcome is ``"success"``, ``"skipped"`` (no odds published), or
    ``"failed"`` (every attempt failed); each is persisted to the manifest.
    """
    match_id = _match_id(match_info)
    out_path = get_match_file(run.date_str, match_id, sport=run.sport)
    update_manifest(
        run.date_str,
        lambda m: m.set_in_progress(match_id, worker_id=worker_id),
        sport=run.sport,
    )
    logger.info("match_scrape_start", worker=worker_id, match_id=match_id)

    empty_odds_attempts = 0
    partial_odds = None
    retry_market_names = None
    for attempt in range(run.max_retries + 1):
        try:
            match_data = scrape_match(
                driver,
                match_info,
                sport=run.sport,
                odds_attempt=min(attempt + 1, run.odds_max_attempts),
                odds_max_attempts=run.odds_max_attempts,
                previous_empty_odds_attempts=empty_odds_attempts,
                previous_odds=partial_odds,
                retry_market_names=retry_market_names,
            )
            save_json(match_data, out_path, artifact_type=MATCH_PAYLOAD_ARTIFACT)
            require_accepted_match_json(
                run.date_str, match_id, out_path, sport=run.sport, expected_match=match_info
            )
            run.outcome_checkpoint.done(match_id)
            run.circuit_breaker.record_success()
            run.progress_reporter.record("success", match_id)
            logger.info("match_scrape_success", worker=worker_id, match_id=match_id)
            return "success"
        except FootballOddsUnavailableError as e:
            run.outcome_checkpoint.skipped(
                match_id, "all_odds_unavailable", error=str(e), url=_match_link(match_info)
            )
            run.circuit_breaker.record_success()
            run.progress_reporter.record("skipped", match_id)
            logger.warning(
                "match_skipped",
                worker=worker_id,
                match_id=match_id,
                reason="all_odds_unavailable",
                error=str(e),
                source="match_page",
            )
            return "skipped"
        except Exception as e:  # noqa: BLE001 - retried; the final error is recorded
            if isinstance(e, FootballOddsRetryableError):
                empty_odds_attempts += 1
            elif isinstance(e, FootballOddsCoverageError):
                # Keep what was saved and target only the missing markets next time.
                if e.partial_odds and e.missing_markets:
                    partial_odds, retry_market_names = e.partial_odds, e.missing_markets
                else:
                    partial_odds, retry_market_names = None, None
            if attempt == run.max_retries:
                logger.error(
                    "match_scrape_failed", worker=worker_id, match_id=match_id, error=str(e)
                )
                run.metrics.record_scrape_error(type(e).__name__)
                run.outcome_checkpoint.failed(match_id)
                run.circuit_breaker.record_failure()
                run.progress_reporter.record("failed", match_id)
                return "failed"
            update_manifest(
                run.date_str, lambda m, err=str(e): m.record_retry(match_id, err), sport=run.sport
            )
            delay = _retry_delay(attempt, e)
            jitter = random.uniform(0, delay * 0.5)
            restart_driver = _driver_restart_required(e)
            logger.warning(
                "match_retry",
                worker=worker_id,
                match_id=match_id,
                attempt=attempt + 1,
                max_retries=run.max_retries,
                delay_s=round(delay + jitter, 1),
                restart_driver=restart_driver,
                missing_markets=getattr(e, "missing_markets", None),
                error=str(e),
            )
            if restart_driver:
                _reconnect(driver, run, worker_id)
            time.sleep(delay + jitter)
    raise AssertionError("unreachable: the last attempt always returns")


def _pause_between_matches(workers: int) -> None:
    """Sequential runs use the page delay; parallel workers use the slower worker delay."""
    if workers <= 1:
        random_delay()
        return
    settings = get_settings()
    delay = random.uniform(settings.worker_min_delay, settings.worker_max_delay)
    logger.debug("worker_delay", delay_s=round(delay, 1))
    time.sleep(delay)


def _run_worker(driver, batch, run: _Phase2Run, worker_id: int, workers: int) -> None:
    """Process one batch of matches in order with one browser session."""
    if driver is None:
        logger.error("worker_no_driver", worker=worker_id)
        return
    try:
        _warmup_cloudflare(driver, sport=run.sport)
    except Exception as e:  # noqa: BLE001 - a fresh session is tried before the first match
        logger.warning("worker_warmup_failed", worker=worker_id, error=str(e), exc_info=True)
        _reconnect(driver, run, worker_id)
    for position, match_info in enumerate(batch):
        if run.circuit_breaker.aborted:
            logger.warning(
                "circuit_breaker_skipping_remaining",
                worker=worker_id,
                remaining=len(batch) - position,
            )
            return
        outcome = scrape_one(driver, match_info, run, worker_id=worker_id)
        if position < len(batch) - 1 and outcome != "failed":
            _pause_between_matches(workers)


def _fail_unresolved(batch, run: _Phase2Run, reason: str) -> None:
    """Persist a retryable failure for every batch match without a terminal outcome."""
    current = load_manifest(run.date_str, sport=run.sport)
    if current is None:
        raise RuntimeError(
            f"Cannot recover worker batch without manifest: {run.sport} {run.date_str}"
        )
    terminal_ids = {
        str(match_id)
        for match_id in (*current.done, *current.skipped, *current.failed, *current.incomplete)
    }
    recovered = 0
    for match_info in batch:
        match_id = _match_id(match_info)
        if match_id in terminal_ids:
            continue
        run.outcome_checkpoint.failed(match_id)
        run.progress_reporter.record("failed", match_id)
        run.metrics.record_scrape_error(reason)
        terminal_ids.add(match_id)
        recovered += 1
    if recovered:
        logger.error("worker_batch_recovered_as_failed", reason=reason, recovered=recovered)


def phase2_scrape(
    driver,
    matches,
    date_str,
    retry_failed: bool = False,
    max_retries: int = 3,
    workers: int = 1,
    sport: str = "football",
    headless: bool = False,
    load_resources: bool = False,
):
    """Extract match details for one date with ``workers`` browser sessions.

    ``workers=1`` runs the batch in order on ``driver``, which the caller owns.
    With more workers each gets its own Chrome profile and a disjoint batch;
    the same per-match flow (:func:`scrape_one`) runs in every worker.
    Matches left without an outcome (crash, circuit-breaker abort, no driver)
    are persisted as retryable failures.
    """
    sport = normalize_sport(sport)
    workers = max(1, workers)
    run, matches_to_scrape, _manifest = _start_phase2(
        matches, date_str, retry_failed, max_retries, sport, workers
    )
    if not matches_to_scrape:
        return _finish_phase2(run)

    batches = [matches_to_scrape[w::workers] for w in range(workers)]
    profile_dirs: list[str] = []
    drivers = [driver] if workers == 1 else []
    if workers > 1:
        # Create drivers serially so undetected_chromedriver does not race on patching.
        logger.info("initialising_worker_drivers", count=workers)
        for worker_id in range(workers):
            profile_dir = tempfile.mkdtemp(prefix=f"oddspedia_profile_{worker_id}_")
            profile_dirs.append(profile_dir)
            try:
                drivers.append(
                    DriverManager(
                        headless=headless,
                        load_resources=load_resources,
                        user_data_dir=profile_dir,
                    )
                )
            except Exception as e:  # noqa: BLE001 - that worker's batch is recorded as failed
                logger.exception("worker_driver_init_failed", worker=worker_id, error=str(e))
                drivers.append(None)

    try:
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {
                pool.submit(_run_worker, drivers[w], batch, run, w, workers): (w, batch)
                for w, batch in enumerate(batches)
                if batch
            }
            for future in as_completed(futures):
                worker_id, batch = futures[future]
                reason = "worker_incomplete_batch"
                try:
                    future.result()
                except Exception as e:  # noqa: BLE001 - its unresolved matches are failed below
                    logger.exception("worker_crashed", worker=worker_id, error=str(e))
                    reason = "worker_crashed"
                if drivers[worker_id] is None:
                    reason = "driver_init_failed"
                _fail_unresolved(batch, run, reason)
                logger.info("worker_finished", worker=worker_id, count=len(batch))
    finally:
        if workers > 1:
            for worker_driver in drivers:
                if worker_driver is not None:
                    worker_driver.quit()
            for profile_dir in profile_dirs:
                shutil.rmtree(profile_dir, ignore_errors=True)

    return _finish_phase2(run)


def _resolve_dates(args, current_date=None):
    """Resolve date, month, or range arguments into one or more date strings."""
    try:
        return resolve_date_scope(
            date_value=getattr(args, "date", None),
            month=getattr(args, "month", None),
            current_date=current_date,
            start_date=getattr(args, "start_date", None),
            end_date=getattr(args, "end_date", None),
        )
    except ValueError as exc:
        logger.error("invalid_collection_date_scope", error=str(exc))
        sys.exit(1)


def _print_status(date_str, sport: str = "football"):
    """Compatibility helper backed by the unified, read-only report."""
    normalize_sport(sport)
    from src.operations.scraping_reporting import build_scraping_report, render_summary

    print(render_summary(build_scraping_report("oddspedia", [date_str])), end="")


def _warn_deprecated_options(argv: Sequence[str]) -> None:
    """Report legacy CLI spellings while keeping existing automation working."""
    replacements = {
        "--retry": "--retry-failed or --retry-incomplete",
        "--priority": "--priority-tier",
        "--depthmark-window-ready": "--silver-reference-window-ready",
        "--reference-window-complete": "--silver-reference-window-ready",
        "--images": "--load-resources",
        "--load-images": "--load-resources",
        "--json-logs": "--log-format json",
        "--collect": "discover_oddspedia_events.py",
        "--scrape": "scrape_oddspedia_matches.py",
        "--status": "report_scraping.py --source oddspedia",
    }
    for argument in argv:
        option = argument.split("=", 1)[0]
        replacement = replacements.get(option)
        if replacement:
            print(
                f"Warning: {option} is deprecated; use {replacement} instead.",
                file=sys.stderr,
            )


def main(
    argv: Sequence[str] | None = None,
    default_sport: str = "football",
    fixed_command: str | None = None,
) -> None:
    """Run the shared pipeline.

    ``default_sport`` is used by the sport-specific project entry points.
    The football project owns this complete collection, manifest, retry,
    logging, and status pipeline.
    """
    parser = argparse.ArgumentParser(
        description=(
            f"Oddspedia {fixed_command} command"
            if fixed_command
            else "Oddspedia event intake compatibility command"
        ),
        epilog=(
            None
            if fixed_command
            else "Canonical phase scripts: discover_oddspedia_events.py, "
            "prioritize_oddspedia_events.py, scrape_oddspedia_matches.py, "
            "and run_oddspedia_pipeline.py. Use ../report_scraping.py for reporting."
        ),
    )
    if fixed_command is None:
        parser.add_argument(
            "command",
            nargs="?",
            choices=("discover", "prioritize", "scrape", "run", "pipeline", "status"),
            help="Compatibility action to run (default: run)",
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
        "--load-resources",
        dest="load_resources",
        action="store_true",
        help="Allow Chrome to load nonessential images, CSS, fonts, media, and trackers",
    )
    parser.add_argument(
        "--load-images",
        dest="load_resources",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--images",
        dest="load_resources",
        action="store_true",
        help=argparse.SUPPRESS,
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
        help="Target month. A current-month run stops at the machine-local current date.",
    )
    date_group.add_argument(
        "--start-date",
        default=None,
        metavar="YYYYMMDD",
        help="First date of an inclusive range; requires --end-date.",
    )
    parser.add_argument(
        "--end-date",
        default=None,
        metavar="YYYYMMDD",
        help="Last date of an inclusive range; valid only with --start-date.",
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
        help=argparse.SUPPRESS,
    )
    retry = parser.add_mutually_exclusive_group()
    retry.add_argument(
        "--retry-failed",
        dest="retry",
        action="store_const",
        const="failed",
        help="Retry failed match-detail extraction",
    )
    retry.add_argument(
        "--retry-incomplete",
        dest="retry",
        action="store_const",
        const="incomplete",
        help="Retry incomplete event discovery",
    )
    retry.add_argument(
        "--retry",
        dest="legacy_retry",
        choices=("failed", "incomplete"),
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--priority-tier",
        dest="priority",
        choices=("xG", "ratings", "lower", "unmatched"),
        default="lower",
        help="Inclusive scrape priority tier (default: lower)",
    )
    parser.add_argument(
        "--priority",
        dest="priority",
        choices=("xG", "ratings", "lower", "unmatched"),
        default=argparse.SUPPRESS,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--silver-reference-window-ready",
        dest="depthmark_window_ready",
        action="store_true",
        help="Assert the previous/current/next FotMob Silver reference dates are complete",
    )
    parser.add_argument(
        "--depthmark-window-ready",
        dest="depthmark_window_ready",
        action="store_true",
        default=argparse.SUPPRESS,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Calculate priority decisions without writing artifacts or manifests (prioritize only)",
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
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    args = parser.parse_args(raw_argv)
    _warn_deprecated_options(raw_argv)
    if args.start_date and not args.end_date:
        parser.error("--end-date is required with --start-date")
    if args.end_date and not args.start_date:
        parser.error("--end-date can only be used with --start-date")
    if args.legacy_retry:
        args.retry = args.legacy_retry
    if fixed_command is None and args.command and args.legacy_command:
        parser.error("choose either a command or a legacy action flag, not both")
    command = fixed_command or args.command or args.legacy_command or "run"
    if command == "pipeline":
        command = "run"
    if args.retry == "failed" and command not in {"scrape", "run"}:
        parser.error("--retry-failed is only valid with 'scrape' or 'run'")
    if args.retry == "incomplete" and command != "discover":
        parser.error("--retry-incomplete is only valid with 'discover'")
    if args.dry_run and command != "prioritize":
        parser.error("--dry-run is only valid with 'prioritize'")
    if command in {"prioritize", "run"} and not args.depthmark_window_ready:
        parser.error("--silver-reference-window-ready is required for prioritize and run")
    sport = normalize_sport(default_sport)

    dates = _resolve_dates(args)

    # Legacy umbrella status is an observational compatibility path. Route it
    # before run-log setup so a report cannot mutate scraper state or logs.
    if command == "status":
        from src.operations.scraping_reporting import build_scraping_report, render_summary

        print(render_summary(build_scraping_report("oddspedia", dates)), end="")
        return

    # Persist every terminal event alongside the data being scraped. A month
    # run receives its own directory because its events span multiple dates.
    log_date = dates[0]
    run_started_at = datetime.now(UTC)
    run_id = run_started_at.strftime("%Y%m%dT%H%M%S")
    run_dir = get_run_logs_dir(log_date, sport=sport)
    log_path = None if args.dry_run else os.path.join(run_dir, f"run_{run_id}.log")
    configure_logging(json_logs=args.log_format == "json", log_file=log_path)
    logger.info(
        "run_log_started",
        log_path=log_path,
        run_id=run_id,
        sport=sport,
        dates=dates,
    )
    persist_manifest_metrics = False

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
    persist_manifest_metrics = not (command == "prioritize" and args.dry_run)
    logger.info("scraper_start", sport=sport, dates=dates, headless=args.headless, workers=workers)

    driver = None
    try:

        def date_operation(date_str):
            """Serialize mutating work for one sport/date across processes."""
            if args.dry_run:
                return nullcontext()
            return oddspedia_date_lock(
                date_str,
                sport=sport,
                operation=command,
            )

        def ensure_driver():
            nonlocal driver
            if driver is None:
                driver = DriverManager(
                    headless=args.headless,
                    load_resources=args.load_resources,
                )
            return driver

        if command == "prioritize":
            for date_str in dates:
                with date_operation(date_str):
                    prioritize_date(
                        date_str,
                        priority=args.priority,
                        dry_run=args.dry_run,
                        sport=sport,
                    )
            return

        if command == "discover":
            listing_ready = False
            failed_dates = []
            for date_str in dates:
                with date_operation(date_str):
                    refresh_inventory = _needs_discovery_retry(date_str, sport)
                    if args.retry == "incomplete" and not refresh_inventory:
                        logger.info("discovery_retry_not_needed", sport=sport, date=date_str)
                        continue
                    links_file = get_match_links_file(date_str, sport=sport)
                    inventory_valid = _existing_inventory_matches_target(
                        links_file, date_str, sport=sport
                    )
                    collect_driver = (
                        None if inventory_valid and not refresh_inventory else ensure_driver()
                    )
                    matches = phase1_collect(
                        collect_driver,
                        date_str,
                        sport=sport,
                        reuse_listing=listing_ready,
                        force=refresh_inventory or args.retry == "incomplete",
                    )
                    # Existing inventories do not change the browser's location.
                    # Once a discovery succeeds, later dates can stay on this
                    # listing and change only the date picker.
                    if collect_driver is not None and matches:
                        listing_ready = True
                    if not _discovery_is_accepted(date_str, sport=sport):
                        failed_dates.append(date_str)
            if failed_dates:
                logger.error(
                    "discovery_dates_failed",
                    sport=sport,
                    dates=failed_dates,
                    failed_count=len(failed_dates),
                )
                sys.exit(1)
            return

        if command == "scrape":
            scraped_any = False
            failed_dates = []
            for date_str in dates:
                with date_operation(date_str):
                    links_file = get_match_links_file(date_str, sport=sport)
                    if not os.path.exists(links_file):
                        logger.error(
                            "links_file_not_found",
                            sport=sport,
                            links_file=links_file,
                            date=date_str,
                        )
                        if len(dates) == 1:
                            sys.exit(1)
                        failed_dates.append(date_str)
                        continue
                    if not _discovery_is_accepted(date_str, sport=sport):
                        logger.error(
                            "discovery_not_accepted",
                            sport=sport,
                            date=date_str,
                            links_file=links_file,
                        )
                        failed_dates.append(date_str)
                        continue
                    source_links = _as_match_list(load_json(links_file))
                    if not _existing_inventory_matches_target(links_file, date_str, sport=sport):
                        logger.error(
                            "links_file_target_date_mismatch",
                            sport=sport,
                            date=date_str,
                            links_file=links_file,
                        )
                        failed_dates.append(date_str)
                        continue
                    matches = _selected_priority_matches(
                        date_str, args.priority, sport=sport, source_links=source_links
                    )
                    if matches:
                        scrape_driver = None if workers > 1 else ensure_driver()
                        manifest = phase2_scrape(
                            scrape_driver,
                            matches,
                            date_str,
                            retry_failed=args.retry == "failed",
                            workers=workers,
                            sport=sport,
                            headless=args.headless,
                            load_resources=args.load_resources,
                        )
                        _compress_completed_date(manifest, date_str, sport=sport)
                    else:
                        logger.info("priority_selection_empty", sport=sport, date=date_str)
                    logger.info("scrape_json_complete", sport=sport, date=date_str)
                    scraped_any = True
            if failed_dates:
                logger.error(
                    "scrape_dates_failed",
                    sport=sport,
                    dates=failed_dates,
                    failed_count=len(failed_dates),
                )
                sys.exit(1)
            if not scraped_any:
                logger.error("no_scope_links_found", dates=dates)
                sys.exit(1)
            return

        failed_dates = []
        for date_str in dates:
            with date_operation(date_str):
                links_file = get_match_links_file(date_str, sport=sport)
                refresh_inventory = _needs_discovery_retry(date_str, sport)
                collect_driver = (
                    None
                    if _existing_inventory_matches_target(links_file, date_str, sport=sport)
                    and not refresh_inventory
                    else ensure_driver()
                )
                matches = phase1_collect(
                    collect_driver,
                    date_str,
                    sport=sport,
                    force=refresh_inventory,
                )
                if matches:
                    prioritize_date(
                        date_str,
                        priority=args.priority,
                        sport=sport,
                        source_links=matches,
                    )
                    selected_matches = _selected_priority_matches(
                        date_str,
                        args.priority,
                        sport=sport,
                        source_links=matches,
                    )
                    if selected_matches:
                        scrape_driver = None if workers > 1 else ensure_driver()
                        manifest = phase2_scrape(
                            scrape_driver,
                            selected_matches,
                            date_str,
                            retry_failed=args.retry == "failed",
                            workers=workers,
                            sport=sport,
                            headless=args.headless,
                            load_resources=args.load_resources,
                        )
                        _compress_completed_date(manifest, date_str, sport=sport)
                        logger.info("scrape_json_complete", sport=sport, date=date_str)
                    else:
                        logger.info("priority_selection_empty", sport=sport, date=date_str)
                elif not _discovery_is_accepted(date_str, sport=sport):
                    failed_dates.append(date_str)

        if failed_dates:
            logger.error(
                "pipeline_dates_failed",
                sport=sport,
                dates=failed_dates,
                failed_count=len(failed_dates),
            )
            sys.exit(1)

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
    """Console-script adapter for the Oddspedia event-intake workflow."""
    main(default_sport="football")


if __name__ == "__main__":
    project_main()
