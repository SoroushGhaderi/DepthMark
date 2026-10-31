import json
import os
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

from selenium.common.exceptions import InvalidSessionIdException, WebDriverException

from src.oddspedia.scraping import cli as main
from src.oddspedia.scraping.audit import DateAudit
from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.match_collector import DiscoveryResult
from src.oddspedia.scraping.match_scraper import FootballOddsCoverageError
from src.oddspedia.scraping.metrics import Metrics
from src.oddspedia.scraping.progress import TerminalOutcomeCheckpoint
from src.oddspedia.scraping.utils import DataValidationError, save_json


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
        manifest.record_discovery(
            {
                "complete": False,
                "anomalies": ["pagination_stalled"],
                "expected_pages": 11,
                "observed_pages": 5,
                "match_count": 241,
                "dom_count": 5,
                "snapshot": "data/links/202607/discovery_partial_20260706.json",
            }
        )

        restored = ScrapeManifest.from_dict(manifest.to_dict())

        self.assertEqual(restored.discovery["status"], "rescrape_candidate")
        self.assertEqual(restored.discovery["attempts"], 1)
        self.assertEqual(restored.discovery["observed_pages"], 5)
        self.assertIn("next_attempt_at", restored.discovery)

    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=False)
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

    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=False)
    def test_phase1_persists_verified_no_events_as_an_accepted_inventory(
        self, _exists, collect, save, record_discovery
    ):
        collect.return_value = DiscoveryResult(
            matches={},
            expected_pages=1,
            observed_pages=1,
            empty_confirmed=True,
        )

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [])
        save.assert_called_once()
        self.assertEqual(save.call_args.args[0], [])
        record_discovery.assert_called_once()
        self.assertTrue(record_discovery.call_args.args[2].complete)

    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=False)
    def test_phase1_retries_date_navigation_from_fresh_listing(
        self, _exists, collect, save, _record
    ):
        collect.side_effect = [
            DiscoveryResult(anomalies=["date_navigation_failed"]),
            DiscoveryResult(
                matches={"42": {"id": "42", "home": "Home", "away": "Away"}},
                expected_pages=1,
                observed_pages=1,
            ),
        ]

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [{"id": "42", "home": "Home", "away": "Away"}])
        self.assertEqual(collect.call_count, 2)
        self.assertFalse(collect.call_args_list[0].kwargs["reuse_listing"])
        self.assertFalse(collect.call_args_list[1].kwargs["reuse_listing"])
        save.assert_called_once()

    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=False)
    def test_phase1_retries_every_incomplete_discovery_until_links_are_complete(
        self, _exists, collect, save, _record
    ):
        collect.side_effect = [
            DiscoveryResult(anomalies=["initial_page_load_failed"]),
            DiscoveryResult(anomalies=["sport_component_not_found"]),
            DiscoveryResult(
                matches={"42": {"id": "42", "home": "Home", "away": "Away"}},
                expected_pages=1,
                observed_pages=1,
            ),
        ]

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [{"id": "42", "home": "Home", "away": "Away"}])
        self.assertEqual(collect.call_count, 3)
        self.assertFalse(collect.call_args_list[0].kwargs["reuse_listing"])
        self.assertFalse(collect.call_args_list[1].kwargs["reuse_listing"])
        self.assertFalse(collect.call_args_list[2].kwargs["reuse_listing"])
        save.assert_called_once()

    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=False)
    def test_phase1_never_persists_partial_links_as_date_inventory(
        self, _exists, collect, save, record_discovery
    ):
        partial = DiscoveryResult(
            matches={"42": {"id": "42", "home": "Home", "away": "Away"}},
            expected_pages=3,
            observed_pages=1,
            anomalies=["pagination_stalled"],
        )
        collect.side_effect = [partial, partial, partial]

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [])
        self.assertEqual(collect.call_count, 3)
        save.assert_called_once()
        self.assertEqual(save.call_args.args[0], list(partial.matches.values()))
        self.assertTrue(save.call_args.args[1].endswith("discovery_partial.json"))
        record_discovery.assert_called_once()
        self.assertFalse(record_discovery.call_args.args[2].complete)

    @patch("src.oddspedia.scraping.cli._needs_discovery_retry", return_value=True)
    @patch("src.oddspedia.scraping.cli._existing_inventory_matches_target", return_value=True)
    @patch("src.oddspedia.scraping.cli.os.path.exists", return_value=True)
    @patch("src.oddspedia.scraping.cli.save_json")
    @patch("src.oddspedia.scraping.cli._record_discovery")
    @patch("src.oddspedia.scraping.cli.collect_match_links")
    def test_phase1_refreshes_valid_inventory_when_manifest_needs_retry(
        self, collect, _record, save, _exists, _inventory_matches_target, _needs_retry
    ):
        collect.return_value = DiscoveryResult(
            matches={"42": {"id": "42", "home": "Home", "away": "Away"}},
            expected_pages=1,
            observed_pages=1,
        )

        matches = main.phase1_collect(object(), "20260706")

        self.assertEqual(matches, [{"id": "42", "home": "Home", "away": "Away"}])
        collect.assert_called_once()
        save.assert_called_once()

    def test_non_playable_football_status_is_skipped_before_scraping(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
        matches = [
            {
                "id": "42",
                "status": "CANCELED",
                "url": "/football/home-away-42",
                "full_url": "https://oddspedia.com/football/home-away-42",
            }
        ]
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
            "sport": "football",
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/example",
            "status": "FT",
            "score": {"home": 1, "away": 0},
            "odds": [
                {
                    "market": "Full Time Result",
                    "lines": [{"label": "Main Line", "home": 2.0}],
                }
            ],
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

    def test_done_match_with_partial_tracked_market_coverage_is_rescraped(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
        manifest.mark_done("42")
        payload = {
            "sport": "football",
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/example",
            "status": "FT",
            "score": {"home": 1, "away": 0},
            "odds_total_markets": 6,
            "odds_extracted_markets": 4,
            "odds": [
                {
                    "market": "Full Time Result",
                    "lines": [{"label": "Main Line", "home": 2.0, "draw": 3.0, "away": 4.0}],
                },
                {
                    "market": "Total Goals",
                    "lines": [{"label": "2.5", "over": 2.0, "under": 1.8}],
                },
                {
                    "market": "Asian Handicap",
                    "lines": [{"label": "-0.5", "home": 2.0, "away": 1.8}],
                },
                {
                    "market": "Both Teams to Score",
                    "lines": [{"label": "Main Line", "yes": 1.9, "no": 1.9}],
                },
            ],
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

        self.assertEqual([match["id"] for match in selected], ["42"])
        self.assertEqual(skipped, 0)
        self.assertIn("42", manifest.incomplete)
        self.assertNotIn("42", manifest.done)

    def test_priority_expansion_scrapes_only_newly_selected_matches(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=2)
        manifest.mark_done("already-scraped")
        completed_payload = {
            "sport": "football",
            "id": "already-scraped",
            "home": "Home",
            "away": "Away",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/completed",
            "status": "FT",
            "score": {"home": 1, "away": 0},
            "odds": [
                {
                    "market": "Full Time Result",
                    "lines": [{"label": "Main Line", "home": 2.0}],
                }
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            with open(
                os.path.join(directory, "already-scraped.json"), "w", encoding="utf-8"
            ) as file:
                json.dump(completed_payload, file)
            selected, skipped, _ = main._select_matches_to_scrape(
                [
                    {"id": "already-scraped", "status": "FT"},
                    {"id": "newly-matched", "status": "FT"},
                ],
                directory,
                manifest,
                "2026-07-06",
                sport="football",
            )

        self.assertEqual([match["id"] for match in selected], ["newly-matched"])
        self.assertEqual(skipped, 1)

    def test_scrape_scope_progress_ignores_completed_matches_outside_run_scope(self):
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=269)
        manifest.mark_done("outside-selected-run")

        matches = [{"id": str(match_id)} for match_id in range(1, 87)]

        self.assertEqual(main._scrape_scope_progress(matches, manifest), 0.0)

        for match_id in range(1, 85):
            manifest.mark_done(str(match_id))
        manifest.mark_done("85")
        self.assertEqual(main._scrape_scope_progress(matches, manifest), 98.84)

    def test_scoped_checkpoint_metrics_ignore_unselected_manifest_outcomes(self):
        metrics = Metrics()
        metrics.phase2_start(total=2)
        manifest = ScrapeManifest(date="2026-07-06", sport="football", total=269)
        manifest.mark_done("selected-1")
        manifest.mark_done("outside-selected-run")

        checkpoint = TerminalOutcomeCheckpoint("2026-07-06", "football", metrics)
        checkpoint.set_scope(["selected-1", "selected-2"])
        checkpoint.sync(manifest)

        self.assertEqual(metrics.phase_2_success, 1)
        self.assertEqual(metrics.phase_2_skipped, 0)
        self.assertEqual(metrics.phase2_completed_progress, 50.0)

    @patch("src.oddspedia.scraping.cli.logger.info")
    def test_progress_reporter_logs_prior_scraped_matches_as_skipped(self, log_info):
        reporter = main._MatchProgressReporter(
            "2026-07-06",
            "football",
            total=2,
            previously_scraped=3,
            previously_skipped=1,
        )

        reporter.record("success", "42")

        fields = log_info.call_args.kwargs
        self.assertEqual(log_info.call_args.args[0], "[PROGRESS] Match processing update")
        self.assertEqual(fields["completed"], 1)
        self.assertEqual(fields["total"], 2)
        self.assertEqual(fields["progress_pct"], 50.0)
        self.assertEqual(fields["successful_matches"], 1)
        self.assertEqual(fields["failed_matches"], 0)
        self.assertEqual(fields["skipped_matches"], 4)
        self.assertEqual(fields["previously_scraped_matches"], 3)

    def test_coverage_errors_do_not_restart_chrome(self):
        self.assertFalse(main._driver_restart_required(FootballOddsCoverageError("missing card")))
        self.assertFalse(
            main._driver_restart_required(WebDriverException("element not interactable"))
        )
        self.assertTrue(main._driver_restart_required(InvalidSessionIdException("gone")))
        self.assertTrue(
            main._driver_restart_required(WebDriverException("disconnected from DevTools"))
        )

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

    def test_phase2_does_not_mark_an_incomplete_saved_payload_done(self):
        match = {
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/home-away-42",
            "status": "FT",
        }
        incomplete_payload = {
            "sport": "football",
            "id": "42",
            "home": "Home",
            "away": "Away",
            "tournament": "League",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/home-away-42",
            "status": "",
            "score": {"home": "", "away": "", "winner": ""},
            "odds": [],
            "scraped_at": "2026-07-07T00:00:00+00:00",
        }

        with tempfile.TemporaryDirectory() as directory:
            manifest_path = os.path.join(directory, "manifest.json")
            output_path = os.path.join(directory, "match_42.json")
            manifest = ScrapeManifest(date="20260706", sport="football", total=1)
            with (
                patch(
                    "src.oddspedia.scraping.manifest.get_manifest_path",
                    return_value=manifest_path,
                ),
                patch("src.oddspedia.scraping.cli.get_matches_dir", return_value=directory),
                patch("src.oddspedia.scraping.cli.get_match_file", return_value=output_path),
                patch(
                    "src.oddspedia.scraping.cli._audit_before_scrape",
                    return_value=(
                        DateAudit(date="20260706", sport="football", expected=1),
                        manifest,
                    ),
                ),
                patch(
                    "src.oddspedia.scraping.cli._select_matches_to_scrape",
                    return_value=([match], 0, 0),
                ),
                patch("src.oddspedia.scraping.cli.scrape_match", return_value=incomplete_payload),
                patch("src.oddspedia.scraping.cli._warmup_cloudflare"),
            ):
                from src.oddspedia.scraping.manifest import save_manifest

                save_manifest(manifest)
                persisted = main.phase2_scrape(
                    object(), [match], "20260706", max_retries=0, workers=1
                )

        self.assertNotIn("42", persisted.done)
        self.assertIn("42", persisted.failed)

    def test_partial_football_retry_reuses_saved_markets_and_targets_missing_names(self):
        match = {
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-07-06",
            "url": "https://oddspedia.com/football/home-away-42",
            "status": "FT",
        }
        partial_odds = [{"market": "Full Time Result", "lines": [{"label": "Main Line"}]}]
        coverage_error = FootballOddsCoverageError(
            "Football odds market coverage incomplete: extracted 1/2 markets",
            missing_markets=["Corners Odd or Even"],
            partial_odds=partial_odds,
        )
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = os.path.join(directory, "manifest.json")
            output_path = os.path.join(directory, "match_42.json")
            manifest = ScrapeManifest(date="20260706", sport="football", total=1)
            with (
                patch(
                    "src.oddspedia.scraping.manifest.get_manifest_path",
                    return_value=manifest_path,
                ),
                patch("src.oddspedia.scraping.cli.get_matches_dir", return_value=directory),
                patch("src.oddspedia.scraping.cli.get_match_file", return_value=output_path),
                patch(
                    "src.oddspedia.scraping.cli._audit_before_scrape",
                    return_value=(
                        DateAudit(date="20260706", sport="football", expected=1),
                        manifest,
                    ),
                ),
                patch(
                    "src.oddspedia.scraping.cli._select_matches_to_scrape",
                    return_value=([match], 0, 0),
                ),
                patch(
                    "src.oddspedia.scraping.cli.scrape_match",
                    side_effect=[coverage_error, {"id": "42"}],
                ) as scrape,
                patch("src.oddspedia.scraping.cli.save_json"),
                patch("src.oddspedia.scraping.cli.require_accepted_match_json"),
                patch("src.oddspedia.scraping.cli._warmup_cloudflare"),
                patch("src.oddspedia.scraping.cli._retry_delay", return_value=0),
                patch("src.oddspedia.scraping.cli.random.uniform", return_value=0),
                patch("src.oddspedia.scraping.cli.time.sleep"),
                patch("src.oddspedia.scraping.cli.random_delay"),
            ):
                from src.oddspedia.scraping.manifest import save_manifest

                save_manifest(manifest)
                persisted = main.phase2_scrape(
                    object(), [match], "20260706", max_retries=1, workers=1
                )

        self.assertEqual(scrape.call_count, 2)
        self.assertIsNone(scrape.call_args_list[0].kwargs["previous_odds"])
        self.assertIsNone(scrape.call_args_list[0].kwargs["retry_market_names"])
        self.assertEqual(scrape.call_args_list[1].kwargs["previous_odds"], partial_odds)
        self.assertEqual(
            scrape.call_args_list[1].kwargs["retry_market_names"], ["Corners Odd or Even"]
        )
        self.assertIn("42", persisted.done)

    def test_concurrent_driver_initialization_failure_persists_every_match_failure(self):
        matches = [
            {"id": "41", "home": "A", "away": "B", "status": "FT"},
            {"id": "42", "home": "C", "away": "D", "status": "FT"},
        ]
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = os.path.join(directory, "manifest.json")
            manifest = ScrapeManifest(date="20260706", sport="football", total=2)
            with (
                patch(
                    "src.oddspedia.scraping.manifest.get_manifest_path",
                    return_value=manifest_path,
                ),
                patch("src.oddspedia.scraping.cli.get_matches_dir", return_value=directory),
                patch(
                    "src.oddspedia.scraping.cli._audit_before_scrape",
                    return_value=(
                        DateAudit(date="20260706", sport="football", expected=2),
                        manifest,
                    ),
                ),
                patch(
                    "src.oddspedia.scraping.cli._select_matches_to_scrape",
                    return_value=(matches, 0, 0),
                ),
                patch(
                    "src.oddspedia.scraping.cli.DriverManager",
                    side_effect=RuntimeError("driver unavailable"),
                ),
            ):
                from src.oddspedia.scraping.manifest import save_manifest

                save_manifest(manifest)
                persisted = main.phase2_scrape(None, matches, "20260706", max_retries=0, workers=2)

        self.assertEqual(set(persisted.failed), {"41", "42"})
        self.assertEqual(persisted.in_progress, {})

    def test_concurrent_failures_during_cooldown_count_as_one_pause(self):
        metrics = _Metrics()
        breaker = main._CircuitBreaker(metrics)

        def cooldown_with_concurrent_failures(_seconds):
            for _ in range(main.CIRCUIT_BREAKER_FAILURES_BEFORE_PAUSE):
                breaker.record_failure()

        with patch(
            "src.oddspedia.scraping.cli.time.sleep", side_effect=cooldown_with_concurrent_failures
        ):
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
        self.assertEqual(
            manifest.metrics["match_detail_extraction"]["completed_progress_pct"], 100.0
        )

    def test_terminal_outcome_checkpoint_updates_manifest_and_metrics_together(self):
        metrics = Metrics()
        metrics.phase2_start(total=1)
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = os.path.join(directory, "manifest.json")
            manifest = ScrapeManifest(date="2026-07-06", sport="football", total=1)
            with patch(
                "src.oddspedia.scraping.manifest.get_manifest_path", return_value=manifest_path
            ):
                from src.oddspedia.scraping.manifest import save_manifest

                save_manifest(manifest)
                checkpoint = TerminalOutcomeCheckpoint("2026-07-06", "football", metrics)
                persisted = checkpoint.skipped("42", "all_odds_unavailable")

        self.assertEqual(persisted.skipped["42"]["reason"], "all_odds_unavailable")
        self.assertEqual(persisted.metrics["match_detail_extraction"]["skipped"], 1)
        self.assertEqual(
            persisted.metrics["match_detail_extraction"]["completed_progress_pct"], 100.0
        )


if __name__ == "__main__":
    unittest.main()
