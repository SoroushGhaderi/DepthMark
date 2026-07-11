import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from src.oddspedia.audit import audit_match_json


class FootballAuditTests(unittest.TestCase):
    def test_finished_football_result_without_score_is_requeued(self):
        payload = {
            "sport": "football", "id": "missing-score", "home": "Home", "away": "Away",
            "tournament": "Tournament", "date": "2026-07-05", "status": "finished",
            "score": {"home": "", "away": "", "winner": ""},
            "odds": [{"market": "Full Time Result", "lines": [{"home": 2.0, "draw": 3.0, "away": 4.0}]}],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "missing-score.json")
            with open(path, "w", encoding="utf-8") as file:
                json.dump(payload, file)
            audit = audit_match_json("2026-07-05", "missing-score", path, sport="football")

        self.assertEqual(audit.status, "incomplete")
        self.assertIn("finished football match is missing a final score", audit.reasons)

    def test_two_market_football_result_is_accepted_with_coverage_observation(self):
        payload = {
            "sport": "football",
            "id": "10128182",
            "home": "Broadmeadow Magic Reserves",
            "away": "Weston Workers Reserves",
            "tournament": "Northern NSW Reserves",
            "date": "2026-07-02",
            "url": "https://oddspedia.com/football/example",
            "status": "FT",
            "score": {"home": 2, "away": 1, "winner": "home"},
            "odds": [
                {"market": "Full Time Result", "lines": [{"home": 1.8, "draw": 3.9, "away": 3.6}]},
                {"market": "Total Goals", "lines": [{"over": 1.85, "under": 1.8}]},
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "10128182.json")
            with open(path, "w", encoding="utf-8") as file:
                json.dump(payload, file)
            audit = audit_match_json("2026-07-02", "10128182", path, sport="football")

        self.assertEqual(audit.status, "accepted_data_present")
        self.assertIn("limited football odds coverage (2 markets)", audit.observations)

    def test_missing_total_corners_is_a_coverage_observation(self):
        payload = {
            "sport": "football", "id": "10126510", "home": "Mexico", "away": "Ecuador",
            "tournament": "Friendly", "date": "2026-07-01", "status": "FT",
            "url": "https://oddspedia.com/football/example",
            "score": {"home": 1, "away": 1, "winner": "draw"},
            "odds": [
                {"market": "Full Time Result", "lines": [{"home": 2.0, "draw": 3.0, "away": 4.0}]},
                {"market": "Asian Handicap Corners", "lines": [{"home": 1.8, "away": 1.9}]},
                {"market": "Corners Odd or Even", "lines": [{"odd": 1.9, "even": 1.9}]},
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "10126510.json")
            with open(path, "w", encoding="utf-8") as file:
                json.dump(payload, file)
            audit = audit_match_json("2026-07-01", "10126510", path, sport="football")

        self.assertEqual(audit.status, "accepted_data_present")
        self.assertIn("Total Corners missing while other corners markets are present", audit.observations)

    def test_rich_football_page_missing_selector_market_is_not_requeued(self):
        markets = [
            "Full Time Result", "Total Goals", "Asian Handicap", "Both Teams to Score",
            "Double Chance", "Draw No Bet", "Correct Score", "European Handicap",
            "Half Time / Full Time", "Next Goal", "Corners Odd or Even", "Clean Sheet",
            "To Win Both Halves", "To Score in Both Halves", "To Score a Penalty", "Total Corners",
        ]
        payload = {
            "sport": "football", "id": "rich-page", "home": "Home", "away": "Away",
            "tournament": "Tournament", "date": "2026-07-02", "status": "FT",
            "url": "https://oddspedia.com/football/example",
            "score": {"home": 1, "away": 0, "winner": "home"},
            "odds": [{"market": name, "lines": [{"type": "main", "label": ""}]} for name in markets],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "rich-page.json")
            with open(path, "w", encoding="utf-8") as file:
                json.dump(payload, file)
            audit = audit_match_json("2026-07-02", "rich-page", path, sport="football")

        self.assertEqual(audit.status, "accepted_data_present")
        self.assertTrue(any("first team to score" in item for item in audit.observations))


if __name__ == "__main__":
    unittest.main()
