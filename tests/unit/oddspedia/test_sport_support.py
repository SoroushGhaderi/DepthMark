import os
import subprocess
import sys
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from src.oddspedia.scraping.config import (
    BASE_URL,
    get_manifest_file,
    get_match_file,
    get_match_links_file,
    get_matches_dir,
    get_prioritized_match_links_file,
    get_sport_listing_url,
    get_storage_aspect,
    normalize_sport,
)
from src.oddspedia.scraping.match_collector import _build_urls
from src.oddspedia.scraping.utils import (
    MATCH_LINKS_ARTIFACT,
    MATCH_PAYLOAD_ARTIFACT,
    DataValidationError,
    load_json,
    save_json,
)


class SportConfigTests(unittest.TestCase):
    def test_football_uses_local_default_paths(self):
        self.assertTrue(get_match_links_file("20260227").startswith(os.path.join(ROOT, "data")))
        self.assertEqual(
            get_match_links_file("20260227"), get_match_links_file("20260227", sport="football")
        )
        self.assertTrue(
            get_match_links_file("20260227").endswith(
                os.path.join(
                    "historical", "daily_listings", "202602", "20260227", "match_links.json"
                )
            )
        )
        self.assertTrue(
            get_manifest_file("20260227").endswith(
                os.path.join("historical", "manifests", "202602", "20260227", "manifest.json")
            )
        )
        self.assertTrue(
            get_matches_dir("20260227").endswith(
                os.path.join("historical", "matches", "202602", "20260227")
            )
        )
        self.assertTrue(
            get_match_file("20260227", "123").endswith(
                os.path.join("historical", "matches", "202602", "20260227", "123.json")
            )
        )
        self.assertTrue(
            get_prioritized_match_links_file("20260227").endswith(
                os.path.join(
                    "historical",
                    "link_priorities",
                    "202602",
                    "20260227",
                    "prioritized_match_links.json",
                )
            )
        )

    def test_storage_aspect_uses_live_for_current_date(self):
        today = date(2026, 7, 11)
        self.assertEqual(get_storage_aspect("20260710", current_date=today), "historical")
        self.assertEqual(get_storage_aspect("20260711", current_date=today), "live")
        with self.assertRaises(ValueError):
            get_storage_aspect("20260712", current_date=today)

    def test_project_rejects_tennis(self):
        with self.assertRaises(ValueError):
            normalize_sport("tennis")

    def test_sport_listing_url(self):
        self.assertEqual(get_sport_listing_url("football"), f"{BASE_URL}/football")

    def test_normalize_sport_rejects_unknown_sport(self):
        with self.assertRaises(ValueError):
            normalize_sport("basketball")

    def test_event_intake_exposes_the_compatibility_cli(self):
        result = subprocess.run(
            [sys.executable, os.path.join(ROOT, "scripts", "oddspedia", "events.py"), "--help"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        for option in (
            "discover",
            "prioritize",
            "scrape",
            "run",
            "status",
            "--collect",
            "--retry-failed",
            "--retry-incomplete",
            "--log-format",
            "--month",
            "--priority-tier",
            "--silver-reference-window-ready",
        ):
            self.assertIn(option, result.stdout)

    def test_canonical_oddspedia_scripts_expose_phase_specific_help(self):
        scripts = (
            "discover_oddspedia_events.py",
            "prioritize_oddspedia_events.py",
            "scrape_oddspedia_matches.py",
            "run_oddspedia_pipeline.py",
            "setup_oddspedia_warehouse.py",
            "load_oddspedia_bronze.py",
            "resolve_oddspedia_events.py",
        )
        for script in scripts:
            with self.subTest(script=script):
                result = subprocess.run(
                    [sys.executable, os.path.join(ROOT, "scripts", "oddspedia", script), "--help"],
                    cwd=ROOT,
                    check=True,
                    capture_output=True,
                    text=True,
                )
                self.assertIn("usage:", result.stdout)

        report_result = subprocess.run(
            [sys.executable, os.path.join(ROOT, "scripts", "report_scraping.py"), "--help"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("usage:", report_result.stdout)
        self.assertNotIn("deprecated", report_result.stderr.lower())

        result = subprocess.run(
            [
                sys.executable,
                os.path.join(ROOT, "scripts", "oddspedia", "run_oddspedia_pipeline.py"),
                "--help",
            ],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertNotIn("{discover,prioritize,scrape,run,pipeline,status}", result.stdout)

    def test_legacy_priority_and_reference_flags_remain_accepted(self):
        from src.oddspedia.scraping.cli import main

        with patch("src.oddspedia.scraping.cli.prioritize_date") as prioritize:
            main(
                [
                    "prioritize",
                    "--date",
                    "20260301",
                    "--priority",
                    "lower",
                    "--depthmark-window-ready",
                ]
            )

        prioritize.assert_called_once()


class MatchCollectorUrlTests(unittest.TestCase):
    def test_build_urls_uses_requested_sport(self):
        matches = {
            "1": {"matchId": "1", "matchKey": "arsenal-chelsea"},
            "2": {"matchId": "2", "matchKey": "legacy"},
        }

        _build_urls(matches, sport="football")

        self.assertEqual(matches["1"]["url"], "/football/arsenal-chelsea-1?m=1")
        self.assertEqual(matches["1"]["full_url"], f"{BASE_URL}/football/arsenal-chelsea-1?m=1")
        self.assertEqual(matches["2"]["url"], "/football/legacy-2?m=2")

    def test_save_json_validates_match_links_list(self):
        data = [
            {
                "id": "10128494",
                "sport": "football",
                "home": "Australia",
                "away": "Egypt",
                "league_name": "FIFA World Cup",
                "date": "2026-07-04 17:00:00+00",
                "status": "PEN",
                "url": "/football/australia-egypt-1979571",
                "full_url": "https://oddspedia.com/football/australia-egypt-1979571",
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "match_links.json")
            save_json(data, path, artifact_type=MATCH_LINKS_ARTIFACT)
            saved = load_json(path)

        self.assertEqual(saved[0]["league_name"], "FIFA World Cup")
        self.assertNotIn("league", saved[0])
        self.assertNotIn("tournament", saved[0])

    def test_save_json_preserves_listing_structure_without_model_defaults(self):
        data = [
            {
                "sport": "football",
                "id": "42",
                "home": "Home",
                "away": "Away",
                "date": "2026-03-01 12:00:00+00",
                "url": "/football/home-away-42?m=42",
                "source_only": {"unchanged": True},
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "match_links.json")
            save_json(data, path, artifact_type=MATCH_LINKS_ARTIFACT)
            saved = load_json(path)

        self.assertEqual(saved, data)

    def test_save_json_preserves_match_payload_structure_without_model_defaults(self):
        data = {
            "sport": "football",
            "id": "42",
            "home": "Home",
            "away": "Away",
            "tournament": "League",
            "date": "2026-03-01 12:00:00+00",
            "url": "/football/home-away-42?m=42",
            "status": "finished",
            "odds": [
                {
                    "market": "Both Teams to Score",
                    "lines": [{"type": "main", "label": "Full Time", "yes": 1.8, "no": 2.0}],
                }
            ],
            "stats": [],
            "scraped_at": "2026-08-12T00:00:00+00:00",
            "source_only": {"unchanged": True},
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "42.json")
            save_json(data, path, artifact_type=MATCH_PAYLOAD_ARTIFACT)
            saved = load_json(path)

        self.assertEqual(saved, data)

    def test_save_json_rejects_invalid_nested_odds_before_creating_a_file(self):
        data = {
            "sport": "football",
            "id": "42",
            "home": "Home",
            "away": "Away",
            "tournament": "League",
            "date": "2026-03-01 12:00:00+00",
            "url": "/football/home-away-42?m=42",
            "status": "finished",
            "odds": [{"market": "Result", "lines": [{"label": "Full Time", "home": 2.0}]}],
            "stats": [],
            "scraped_at": "2026-08-12T00:00:00+00:00",
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "42.json")
            with self.assertRaises(DataValidationError):
                save_json(data, path, artifact_type=MATCH_PAYLOAD_ARTIFACT)
            self.assertFalse(os.path.exists(path))


if __name__ == "__main__":
    unittest.main()
