import os
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from src.oddspedia import cli as main
from src.oddspedia.metrics import Metrics
from src.oddspedia.manifest import ScrapeManifest
from src.oddspedia.match_collector import DiscoveryResult
from src.oddspedia.match_scraper import FootballOddsCoverageError
from src.oddspedia.progress import TerminalOutcomeCheckpoint
from src.oddspedia.utils import DataValidationError, save_json
from selenium.common.exceptions import InvalidSessionIdException, WebDriverException


class _Metrics:
    def __init__(self):
        self.pauses = 0
        self.aborts = 0

    def record_circuit_breaker_pause(self):
        self.pauses += 1

    def record_circuit_breaker_abort(self):
        self.aborts += 1


class PipelineReliabilityTests(unittest.TestCase):
    def test_manifest_tracks_terminal_skips_as_completed_work(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=2)
        manifest.mark_done("1")
        manifest.mark_skipped("2", "all_odds_unavailable")

        self.assertEqual(manifest.skipped_count, 1)
        self.assertEqual(manifest.completed_progress, 100.0)
        self.assertEqual(manifest.remaining, 0)
        self.assertTrue(manifest.is_complete)
        self.assertEqual(
            ScrapeManifest.from_dict(manifest.to_dict()).skipped["2"]["reason"],
            "all_odds_unavailable",
        )

    def test_manifest_tracks_discovery_rescrape_candidates(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football")
        manifest.record_discovery({
            "complete": False,
            "anomalies": ["pagination_stalled"],
            "expected_pages": 11,
            "observed_pages": 5,
            "match_count": 241,
            "dom_count": 5,
            "snapshot": "data/links/202607/discovery_partial_20260706.json",
        })

        restored = ScrapeManifest.from_dict(manifest.to_dict())

        self.assertEqual(restored.discovery["status"], "rescrape_candidate")
        self.assertEqual(restored.discovery["attempts"], 1)
        self.assertEqual(restored.discovery["observed_pages"], 5)
        self.assertIn("next_attempt_at", restored.discovery)

    @patch("src.oddspedia.cli._record_discovery")
    @patch("src.oddspedia.cli.save_json")
    @patch("src.oddspedia.cli.collect_match_links")
    @patch("src.oddspedia.cli.os.path.exists", return_value=False)
    def test_phase1_persists_discovery_maps_as_match_link_lists(
        self, _exists, collect, save, _record
    ):
        collect.return_value = DiscoveryResult(
            matches={"42": {"id": "42", "home": "Home", "away": "Away"}},
            expected_pages=1,
            observed_pages=1,
        )

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [{"id": "42", "home": "Home", "away": "Away"}])
        self.assertIsInstance(save.call_args.args[0], list)

    def test_non_playable_football_status_is_skipped_before_scraping(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
        matches = [{
            "id": "42",
            "status": "CANCELED",
            "url": "/football/home-away-42",
            "full_url": "https://oddspedia.com/football/home-away-42",
        }]
        with tempfile.TemporaryDirectory() as directory:
            selected, skipped, reconciled = main._select_matches_to_scrape(
                matches, directory, manifest, "2026-07-06", sport="football"
            )

        self.assertEqual(selected, [])
        self.assertEqual(skipped, 1)
        self.assertEqual(reconciled, 1)
        self.assertEqual(manifest.skipped["42"]["reason"], "non_playable_status")
        self.assertEqual(
            manifest.skipped["42"]["details"]["url"],
            "https://oddspedia.com/football/home-away-42",
        )

    def test_done_match_with_limited_optional_markets_is_not_rescraped(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
        manifest.mark_done("42")
        payload = {
            "sport": "football", "id": "42", "home": "Home", "away": "Away",
            "date": "2026-07-06", "url": "https://oddspedia.com/football/example",
            "status": "FT", "score": {"home": 1, "away": 0},
            "odds": [{"market": "Full Time Result", "lines": [{"home": 2.0}]}],
        }
        with tempfile.TemporaryDirectory() as directory:
            with open(os.path.join(directory, "42.json"), "w", encoding="utf-8") as file:
                json.dump(payload, file)
            selected, skipped, _ = main._select_matches_to_scrape(
                [{"id": "42", "status": "FT"}],
                directory,
                manifest,
                "2026-07-06",
                sport="football",
            )

        self.assertEqual(selected, [])
        self.assertEqual(skipped, 1)
        self.assertIn("42", manifest.done)

    def test_coverage_errors_do_not_restart_chrome(self):
        self.assertFalse(main._driver_restart_required(FootballOddsCoverageError("missing card")))
        self.assertFalse(main._driver_restart_required(WebDriverException("element not interactable")))
        self.assertTrue(main._driver_restart_required(InvalidSessionIdException("gone")))
        self.assertTrue(main._driver_restart_required(WebDriverException("disconnected from DevTools")))

    def test_invalid_match_payload_is_not_persisted(self):
        invalid_payload = {
            "id": "missing-required-fields",
            "odds": [],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "match.json")
            with self.assertRaises(DataValidationError):
                save_json(invalid_payload, path)
            self.assertFalse(os.path.exists(path))

    def test_concurrent_failures_during_cooldown_count_as_one_pause(self):
        metrics = _Metrics()
        breaker = main._CircuitBreaker(metrics)

        def cooldown_with_concurrent_failures(_seconds):
            for _ in range(main.CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE):
                breaker.record_failure()

        with patch("src.oddspedia.cli.time.sleep", side_effect=cooldown_with_concurrent_failures):
            for _ in range(main.CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE):
                breaker.record_failure()

        self.assertEqual(metrics.pauses, 1)
        self.assertEqual(metrics.aborts, 0)
        self.assertFalse(breaker.aborted)

    def test_page_load_metric_keeps_the_recorded_milliseconds(self):
        metrics = Metrics()
        metrics.record_page_load(125)
        self.assertEqual(metrics.avg_page_load_ms, 125)

    def test_metrics_snapshot_is_embedded_in_manifest(self):
        metrics = Metrics()
        metrics.phase2_complete(total=4, success=3, skipped=1, duration_seconds=12)
        metrics.set_context(run_id="test-run")
        manifest = ScrapeManifest(date="2026-07-05", sport="football", total=4)
        manifest.update_metrics(metrics.manifest_snapshot())

        self.assertEqual(manifest.metrics["run_id"], "test-run")
        self.assertEqual(manifest.metrics["match_detail_extraction"]["success"], 3)
        self.assertEqual(manifest.metrics["match_detail_extraction"]["completed_progress_pct"], 100.0)

    def test_terminal_outcome_checkpoint_updates_manifest_and_metrics_together(self):
        metrics = Metrics()
        metrics.phase2_start(total=1)
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = os.path.join(directory, "manifest.json")
            manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
            with patch("src.oddspedia.manifest.get_manifest_path", return_value=manifest_path):
                from src.oddspedia.manifest import save_manifest

                save_manifest(manifest)
                checkpoint = TerminalOutcomeCheckpoint("2026-07-06", "football", metrics)
                persisted = checkpoint.skipped("42", "all_odds_unavailable")

        self.assertEqual(persisted.skipped["42"]["reason"], "all_odds_unavailable")
        self.assertEqual(persisted.metrics["match_detail_extraction"]["skipped"], 1)
        self.assertEqual(persisted.metrics["match_detail_extraction"]["completed_progress_pct"], 100.0)


if __name__ == "__main__":
    unittest.main()
