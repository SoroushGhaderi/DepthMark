"""Durable terminal outcomes for one Sport-Date Scrape."""

import threading
from typing import Optional

from src.oddspedia.manifest import ScrapeManifest, update_manifest
from src.oddspedia.metrics import Metrics


class TerminalOutcomeCheckpoint:
    """Atomically persist one terminal outcome and its manifest metrics.

    This is the seam shared by sequential and concurrent scraping. Callers
    provide only the domain outcome; manifest mutation and metrics embedding
    remain implementation details inside this deep module.
    """

    def __init__(self, date: str, sport: str, metrics: Metrics):
        self.date = date
        self.sport = sport
        self.metrics = metrics
        self._lock = threading.RLock()

    def sync(self, manifest: ScrapeManifest) -> None:
        with self._lock:
            self.metrics.sync_phase2_progress(
                manifest.completed_count,
                manifest.skipped_count,
                manifest.failed_count,
            )
            manifest.update_metrics(self.metrics.manifest_snapshot())

    def done(self, match_id: str) -> ScrapeManifest:
        return self._transition(match_id, "done")

    def skipped(self, match_id: str, reason: str, **details) -> ScrapeManifest:
        return self._transition(match_id, "skipped", reason=reason, **details)

    def failed(self, match_id: str) -> ScrapeManifest:
        return self._transition(match_id, "failed")

    def _transition(
        self,
        match_id: str,
        outcome: str,
        reason: Optional[str] = None,
        **details,
    ) -> ScrapeManifest:
        def apply(manifest: ScrapeManifest) -> None:
            if outcome == "done":
                manifest.mark_done(match_id)
            elif outcome == "skipped":
                manifest.mark_skipped(match_id, reason or "unspecified", **details)
            elif outcome == "failed":
                manifest.mark_failed(match_id)
            else:
                raise ValueError(f"Unsupported terminal outcome: {outcome}")

        with self._lock:
            def apply_and_sync(manifest: ScrapeManifest) -> None:
                apply(manifest)
                self.metrics.sync_phase2_progress(
                    manifest.completed_count,
                    manifest.skipped_count,
                    manifest.failed_count,
                )
                manifest.update_metrics(self.metrics.manifest_snapshot())

            manifest = update_manifest(self.date, apply_and_sync, sport=self.sport)
            if manifest is None:
                raise RuntimeError(
                    f"Cannot persist terminal outcome for missing manifest: "
                    f"{self.sport} {self.date} match {match_id}"
                )
            return manifest
