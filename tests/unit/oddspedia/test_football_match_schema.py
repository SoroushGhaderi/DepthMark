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

from src.oddspedia.scraping.match_scraper import (
    _JS_EXTRACT_ODDS,
    _JS_FOOTBALL_MARKET_SELECTOR_TEXTS,
    FootballOddsCoverageError,
    FootballOddsRetryableError,
    FootballOddsUnavailableError,
    FootballScoreUnavailableError,
    MatchIdentityMismatchError,
    _apply_football_selector_context,
    _archived_match_url,
    _expand_football_market_card_lines,
    _expand_football_market_cards,
    _extract_football_odds,
    _football_missing_market_names,
    _football_odds_coverage_error,
    _football_odds_not_yet_available,
    _is_football_market_selector_text,
    _football_selector_rendered,
    _merge_odds_markets,
    _normalize_football_odds,
    _parse_football_score_payload,
    scrape_match,
)
from src.oddspedia.scraping.utils import load_json, save_json


class _FootballDriver:
    title = "Oddspedia Football"

    def execute_script(self, script, *args):
        if "var d = {" in script:
            return {
                "home": "Mexico",
                "away": "Ecuador",
                "league": "International Friendly",
                "date": "2026-07-09 19:00:00+00",
                "status": "finished",
                "winner": "draw",
                "home_score": 1,
                "away_score": 1,
                "result_unavailable": False,
            }
        if "var markets  = []" in script:
            return [
                {
                    "market": "Full Time Result",
                    "lines": [
                        {"type": "main", "label": "", "home": 2.1, "draw": 3.2, "away": 3.4},
                    ],
                },
                {
                    "market": "Both Teams To Score",
                    "lines": [
                        {"type": "main", "label": "", "yes": 1.8, "no": 1.95},
                    ],
                },
            ]
        if "looksLikeMarketText" in script:
            return []
        if (
            "return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))"
            in script
        ):
            return []
        return 1000


class FootballMatchSchemaTests(unittest.TestCase):
    def test_explicit_no_odds_page_is_detected(self):
        class Driver:
            def execute_script(self, script, *args):
                if "no-results-found" in script:
                    return True
                return False

        self.assertTrue(_football_odds_not_yet_available(Driver()))

    def test_odds_coverage_uses_the_page_market_total(self):
        odds = [
            {"market": "Full Time Result", "lines": [{"label": "Main Line"}]},
            {"market": "Total Goals", "lines": [{"label": "2.5"}]},
            {"market": "Asian Handicap", "lines": [{"label": "-0.5"}]},
            {"market": "Both Teams to Score", "lines": [{"label": "Main Line"}]},
        ]

        self.assertIn(
            "4/6",
            _football_odds_coverage_error(odds, total_markets=6),
        )
        self.assertIsNone(_football_odds_coverage_error(odds, total_markets=4))
        self.assertIn(
            "2/4",
            _football_odds_coverage_error(odds[:2], total_markets=4),
        )

    def test_missing_market_inventory_returns_only_uncovered_market_names(self):
        odds = [
            {
                "market": "Full Time Result",
                "lines": [{"label": "Main Line", "home": 2.0, "draw": 3.0, "away": 4.0}],
            },
            {
                "market": "Both Teams to Score",
                "lines": [{"label": "Main Line", "yes": 1.8, "no": 2.0}],
            },
        ]

        self.assertEqual(
            _football_missing_market_names(
                ["Full Time Result", "Both Teams to Score", "Corners Odd or Even"],
                odds,
            ),
            ["Corners Odd or Even"],
        )

    def test_scrape_match_does_not_return_partial_market_inventory_as_success(self):
        metadata = {
            "event_id": "9401941",
            "home": "Aston Villa",
            "away": "Chelsea",
            "league": "Premier League",
            "date": "2026-03-04 19:30:00+00",
            "status": "finished",
            "home_score": 1,
            "away_score": 0,
        }
        truncated_odds = [
            {"market": "Full Time Result", "lines": [{"label": "Main Line"}]},
            {"market": "Total Goals", "lines": [{"label": "2.5"}]},
            {"market": "Asian Handicap", "lines": [{"label": "-0.5"}]},
            {"market": "Both Teams to Score", "lines": [{"label": "Main Line"}]},
        ]
        with patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True), patch(
            "src.oddspedia.scraping.match_scraper._wait_for_event_metadata",
            return_value=metadata,
        ), patch("src.oddspedia.scraping.match_scraper._scroll_page"), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_list"
        ), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_cards"
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_market_inventory",
            return_value={"total_markets": 6, "market_names": []},
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_odds_not_yet_available",
            return_value=False,
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds",
            return_value=truncated_odds,
        ):
            with self.assertRaises(FootballOddsCoverageError):
                scrape_match(
                    _FootballDriver(),
                    {
                        "id": "9401941",
                        "sport": "football",
                        "home": "Aston Villa",
                        "away": "Chelsea",
                        "date": "2026-03-04 19:30:00+00",
                        "full_url": "https://oddspedia.com/football/aston-villa-chelsea-9401941",
                    },
                    sport="football",
                )

    def test_coverage_error_carries_partial_odds_and_missing_market_names(self):
        metadata = {
            "event_id": "9401941",
            "home": "Aston Villa",
            "away": "Chelsea",
            "league": "Premier League",
            "date": "2026-03-04 19:30:00+00",
            "status": "finished",
            "home_score": 1,
            "away_score": 0,
        }
        partial_odds = [
            {
                "market": name,
                "lines": [{"label": "Main Line", "home": 2.0, "away": 3.0}],
            }
            for name in (
                "Full Time Result",
                "Total Goals",
                "Asian Handicap",
                "Both Teams to Score",
                "Double Chance",
                "Draw No Bet",
            )
        ]
        inventory_names = [*partial_odds, {"market": "Corners Odd or Even"}]
        with patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True), patch(
            "src.oddspedia.scraping.match_scraper._wait_for_event_metadata",
            return_value=metadata,
        ), patch("src.oddspedia.scraping.match_scraper._scroll_page"), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_list"
        ), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_cards"
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_market_inventory",
            return_value={
                "total_markets": 7,
                "market_names": [market["market"] for market in inventory_names],
            },
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_odds_not_yet_available",
            return_value=False,
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds",
            return_value=(partial_odds, ["Corners Odd or Even"]),
        ):
            with self.assertRaises(FootballOddsCoverageError) as context:
                scrape_match(
                    _FootballDriver(),
                    {
                        "id": "9401941",
                        "sport": "football",
                        "home": "Aston Villa",
                        "away": "Chelsea",
                        "date": "2026-03-04 20:00:00+00",
                        "full_url": "https://oddspedia.com/football/aston-villa-chelsea-9401941",
                    },
                    sport="football",
                )

        self.assertEqual(context.exception.missing_markets, ["Corners Odd or Even"])
        self.assertEqual(context.exception.partial_odds, partial_odds)

    def test_empty_football_odds_is_retryable_until_the_terminal_attempt(self):
        metadata = {
            "event_id": "empty-odds",
            "home": "Home",
            "away": "Away",
            "league": "League",
            "date": "2026-03-04 19:30:00+00",
            "status": "scheduled",
            "home_score": "",
            "away_score": "",
        }
        match_info = {
            "id": "empty-odds",
            "sport": "football",
            "home": "Home",
            "away": "Away",
            "date": "2026-03-04 19:30:00+00",
            "status": "scheduled",
            "full_url": "https://oddspedia.com/football/home-away-empty-odds",
        }
        with patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True), patch(
            "src.oddspedia.scraping.match_scraper._wait_for_event_metadata",
            return_value=metadata,
        ), patch("src.oddspedia.scraping.match_scraper._scroll_page"), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_list"
        ), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_cards"
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_market_inventory",
            return_value={"total_markets": 6, "market_names": []},
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_odds_not_yet_available",
            return_value=False,
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds",
            return_value=[],
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_overall_stats",
            return_value={"tabs": []},
        ):
            with self.assertRaises(FootballOddsRetryableError):
                scrape_match(
                    _FootballDriver(),
                    match_info,
                    sport="football",
                    odds_attempt=1,
                    odds_max_attempts=3,
                )

            with self.assertRaises(FootballOddsCoverageError):
                scrape_match(
                    _FootballDriver(),
                    match_info,
                    sport="football",
                    odds_attempt=3,
                    odds_max_attempts=3,
                    previous_empty_odds_attempts=1,
                )

            result = scrape_match(
                _FootballDriver(),
                match_info,
                sport="football",
                odds_attempt=3,
                odds_max_attempts=3,
                previous_empty_odds_attempts=2,
            )

        self.assertEqual(result["odds"], [])
        self.assertTrue(result["odds_unavailable"])
        self.assertEqual(result["odds_total_markets"], 6)
        self.assertEqual(result["odds_extracted_markets"], 0)
        self.assertEqual(result["odds_empty_attempts"], 3)

    @patch(
        "src.oddspedia.scraping.match_scraper._football_odds_not_yet_available",
        return_value=True,
    )
    @patch("src.oddspedia.scraping.match_scraper._expand_football_market_list")
    @patch("src.oddspedia.scraping.match_scraper._expand_football_market_cards")
    @patch("src.oddspedia.scraping.match_scraper._extract_overall_stats", return_value={"tabs": []})
    @patch("src.oddspedia.scraping.match_scraper._scroll_page")
    @patch("src.oddspedia.scraping.match_scraper._wait_for_event_metadata")
    @patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True)
    def test_explicit_no_odds_page_is_saved_as_a_successful_empty_result(
        self,
        _safe_get,
        wait_metadata,
        _scroll,
        _overall_stats,
        expand_cards,
        expand_list,
        _availability,
    ):
        wait_metadata.return_value = {
            "event_id": "9649678",
            "home": "Wellington Phoenix",
            "away": "Perth Glory",
            "league": "A-League",
            "date": "2026-08-08 09:00:00+00",
            "status": "scheduled",
            "home_score": "",
            "away_score": "",
        }

        result = scrape_match(
            _FootballDriver(),
            {
                "id": "9649678",
                "sport": "football",
                "home": "Wellington Phoenix",
                "away": "Perth Glory",
                "date": "2026-08-08 09:00:00+00",
                "status": "scheduled",
                "full_url": "https://oddspedia.com/football/wellington-phoenix-perth-glory-141805",
            },
            sport="football",
            odds_attempt=1,
            odds_max_attempts=3,
            previous_empty_odds_attempts=0,
        )

        self.assertEqual(result["odds"], [])
        self.assertTrue(result["odds_unavailable"])
        self.assertEqual(result["odds_unavailable_reason"], "source_notice")
        self.assertEqual(result["odds_empty_attempts"], 1)
        expand_list.assert_not_called()
        expand_cards.assert_not_called()

    def test_archived_match_url_uses_away_home_route(self):
        url = _archived_match_url(
            "https://oddspedia.com/football/algeciras-cd-teruel-1660684",
            {
                "status": "FT",
                "home": "Algeciras",
                "away": "CD Teruel",
                "home_slug": "algeciras-cf",
                "away_slug": "cd-teruel",
                "matchKey": "algeciras-cd-teruel-1660684",
            },
        )

        self.assertEqual(
            url,
            "https://oddspedia.com/a/football/cd-teruel-algeciras-cf-1660684",
        )

    def test_archived_match_url_does_not_guess_from_short_display_names(self):
        self.assertIsNone(
            _archived_match_url(
                "https://oddspedia.com/football/algeciras-cd-teruel-1660684",
                {
                    "status": "FT",
                    "home": "Algeciras",
                    "away": "CD Teruel",
                    "matchKey": "algeciras-cd-teruel-1660684",
                },
            )
        )

    def test_finished_match_falls_back_to_archived_route_when_listing_redirects(self):
        driver = _FootballDriver()
        driver.current_url = "https://oddspedia.com/football"
        driver.title = "Football Live Scores & Stats » Today's Fixtures, Results and News"
        requested_urls = []

        def fake_safe_get(driver_obj, requested_url):
            requested_urls.append(requested_url)
            if len(requested_urls) == 1:
                driver_obj.current_url = "https://oddspedia.com/football"
                driver_obj.title = (
                    "Football Live Scores & Stats » Today's Fixtures, Results and News"
                )
                return False
            driver_obj.current_url = requested_url
            driver_obj.title = "Algeciras vs CD Teruel Live Score"
            return True

        with patch(
            "src.oddspedia.scraping.match_scraper.safe_get", side_effect=fake_safe_get
        ), patch(
            "src.oddspedia.scraping.match_scraper._wait_for_event_metadata",
            return_value={
                "event_id": "9955415",
                "home": "Algeciras",
                "away": "CD Teruel",
                "date": "2026-07-01",
                "status": "finished",
                "home_score": 1,
                "away_score": 0,
            },
        ), patch(
            "src.oddspedia.scraping.match_scraper._scroll_page"
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_overall_stats", return_value={"tabs": []}
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds", return_value=[]
        ), patch(
            "src.oddspedia.scraping.match_scraper.now_iso", return_value="2026-08-03T00:00:00Z"
        ):
            result = scrape_match(
                driver,
                {
                    "id": "9955415",
                    "sport": "football",
                    "home": "Algeciras",
                    "away": "CD Teruel",
                    "home_slug": "algeciras-cf",
                    "away_slug": "cd-teruel",
                    "status": "FT",
                    "matchKey": "algeciras-cd-teruel-1660684",
                    "full_url": "https://oddspedia.com/football/algeciras-cd-teruel-1660684",
                },
                sport="football",
            )

        self.assertEqual(
            requested_urls,
            [
                "https://oddspedia.com/football/algeciras-cd-teruel-1660684?m=9955415",
                "https://oddspedia.com/a/football/cd-teruel-algeciras-cf-1660684?m=9955415",
            ],
        )
        self.assertEqual(result["url"], requested_urls[-1])

    def test_stale_listing_rejects_matchup_page_showing_different_teams(self):
        class IdentityDriver(_FootballDriver):
            current_url = ""
            title = "Oddspedia Football"

            def execute_script(self, script, *args):
                if "var d = {" in script:
                    return {
                        "event_id": "later-fixture",
                        "home": "Marseille",
                        "away": "Nice",
                        "home_slug": "olympique-lyon",
                        "away_slug": "celta-de-vigo",
                        "date": "2026-03-19 17:45:00+00",
                        "status": "finished",
                        "home_score": 0,
                        "away_score": 2,
                    }
                return super().execute_script(script, *args)

        driver = IdentityDriver()
        requested_urls = []

        def fake_safe_get(driver_obj, requested_url):
            requested_urls.append(requested_url)
            driver_obj.current_url = requested_url
            return True

        with patch("src.oddspedia.scraping.match_scraper.safe_get", side_effect=fake_safe_get):
            with self.assertRaises(MatchIdentityMismatchError):
                scrape_match(
                    driver,
                    {
                        "id": "9956611",
                        "sport": "football",
                        "home": "Celta Vigo",
                        "away": "Lyon",
                        "date": "2026-03-12 20:00:00+00",
                        "status": "2HALF",
                        "matchKey": "celta-de-vigo-olympique-lyon-1178135",
                        "full_url": (
                            "https://oddspedia.com/football/" "celta-de-vigo-olympique-lyon-1178135"
                        ),
                    },
                    sport="football",
                )

        self.assertEqual(
            requested_urls,
            ["https://oddspedia.com/football/celta-de-vigo-olympique-lyon-1178135?m=9956611"],
        )

    def test_same_team_identity_mismatch_is_rejected_before_odds_score_or_stats(self):
        class DelayedEventDriver(_FootballDriver):
            def execute_script(self, script, *args):
                if "var d = {" in script:
                    return {
                        "event_id": "rendered-event-2",
                        "home": "Away FC",
                        "away": "Home FC",
                        "date": "2026-08-01 20:00:00+00",
                        "status": "finished",
                        "home_score": 1,
                        "away_score": 0,
                    }
                return super().execute_script(script, *args)

        available_odds = [
            {
                "market": "Full Time Result",
                "lines": [{"type": "main", "label": "Main Line", "home": 2.1, "away": 3.2}],
            }
        ]
        with patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds",
            side_effect=AssertionError("mismatched pages must not reach odds extraction"),
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_overall_stats",
            side_effect=AssertionError("mismatched pages must not reach stats extraction"),
        ):
            with self.assertRaises(MatchIdentityMismatchError):
                scrape_match(
                    DelayedEventDriver(),
                    {
                        "id": "listing-event-1",
                        "sport": "football",
                        "home": "Home FC",
                        "away": "Away FC",
                        "date": "2026-03-13 20:00:00+00",
                        "full_url": "https://oddspedia.com/football/home-fc-away-fc-1",
                    },
                    sport="football",
                )

    @patch("src.oddspedia.scraping.match_scraper.now_iso", return_value="2026-07-09T12:00:00Z")
    @patch(
        "src.oddspedia.scraping.match_scraper._extract_live_odds",
        side_effect=AssertionError("football must not scrape live odds"),
    )
    @patch("src.oddspedia.scraping.match_scraper._extract_overall_stats")
    @patch("src.oddspedia.scraping.match_scraper._expand_all_odds_lines", return_value=1)
    @patch("src.oddspedia.scraping.match_scraper._scroll_page")
    @patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True)
    @patch("src.oddspedia.scraping.match_scraper.time.sleep", return_value=None)
    def test_football_match_uses_football_schema_and_live_stats(
        self,
        _sleep,
        _safe_get,
        _scroll_page,
        _expand,
        extract_overall_stats,
        _extract_live_odds,
        _now_iso,
    ):
        extract_overall_stats.return_value = {
            "tabs": [
                {
                    "tab": "Live Stats",
                    "metrics": [
                        {
                            "name": "Ball possession",
                            "home": "43%",
                            "away": "57%",
                            "view": "horizontal",
                        },
                        {"name": "Shots on target", "home": "9", "away": "6", "view": "shots"},
                    ],
                }
            ]
        }

        result = scrape_match(
            _FootballDriver(),
            {
                "id": "1979571",
                "sport": "football",
                "home": "Mexico",
                "away": "Ecuador",
                "league_name": "International Friendly",
                "date": "2026-07-09",
                "full_url": "https://oddspedia.com/football/mexico-ecuador-1979571",
            },
            sport="football",
        )

        self.assertEqual(result["sport"], "football")
        self.assertEqual(result["score"], {"home": 1, "away": 1, "winner": "draw"})
        self.assertEqual(result["stats_source"], "Live Stats")
        self.assertEqual(
            [m["name"] for m in result["stats"]], ["Ball possession", "Shots on target"]
        )
        self.assertEqual(len(result["odds"]), 2)
        self.assertNotIn("result_unavailable", result)
        self.assertNotIn("live_odds", result)
        self.assertNotIn("set_scores", result)
        self.assertNotIn("point_by_point", result)

    def test_save_json_does_not_add_default_live_odds_to_football(self):
        data = {
            "sport": "football",
            "id": "1979571",
            "home": "Mexico",
            "away": "Ecuador",
            "tournament": "International Friendly",
            "date": "2026-07-09",
            "status": "finished",
            "score": {"home": 1, "away": 1, "winner": "draw"},
            "odds": [
                {
                    "market": "Full Time Result",
                    "lines": [{"type": "main", "label": "", "home": 2.1, "draw": 3.2, "away": 3.4}],
                }
            ],
            "stats": [{"name": "Ball possession", "home": "43%", "away": "57%"}],
            "scraped_at": "2026-07-09T12:00:00Z",
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "match.json")
            save_json(data, path)
            saved = load_json(path)

        self.assertNotIn("live_odds", saved)
        self.assertNotIn("set_scores", saved)
        self.assertEqual(saved["score"]["home"], 1)

    def test_football_score_can_be_derived_from_period_status_payload(self):
        status = """[
            {"period_type":"regular_period","period_number":1,"home":2,"away":0,"tiebreak":null},
            {"period_type":"regular_period","period_number":2,"home":0,"away":0,"tiebreak":null}
        ]"""

        self.assertEqual(_parse_football_score_payload(status), {"home": 2, "away": 0})

    def test_finished_football_match_without_score_fails_instead_of_saving_blank_result(self):
        class BlankScoreDriver(_FootballDriver):
            def execute_script(self, script, *args):
                result = super().execute_script(script, *args)
                if "var d = {" in script:
                    result.update(home_score="", away_score="", winner="")
                return result

        with patch("src.oddspedia.scraping.match_scraper.safe_get", return_value=True), patch(
            "src.oddspedia.scraping.match_scraper._scroll_page"
        ), patch("src.oddspedia.scraping.match_scraper._expand_football_market_list"), patch(
            "src.oddspedia.scraping.match_scraper._expand_football_market_cards"
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_football_odds", return_value=[]
        ), patch(
            "src.oddspedia.scraping.match_scraper._extract_overall_stats", return_value={"tabs": []}
        ), patch(
            "src.oddspedia.scraping.match_scraper._football_score_from_dom", return_value=None
        ), patch(
            "src.oddspedia.scraping.match_scraper.time.sleep"
        ):
            with self.assertRaises(FootballScoreUnavailableError):
                scrape_match(
                    BlankScoreDriver(),
                    {
                        "id": "blank",
                        "sport": "football",
                        "full_url": "https://oddspedia.com/football/test",
                    },
                    sport="football",
                )

    def test_football_named_outcomes_are_saved_as_team_fields(self):
        odds = [
            {
                "market": "Draw No Bet",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"Canada": 1.8, "Morocco": 2.0},
                    }
                ],
            },
            {
                "market": "First Team to Score",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"Canada": 1.9, "Morocco": 2.1, "No Goal": 8.5},
                    }
                ],
            },
        ]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(
            normalized[0]["lines"][0],
            {"type": "main", "label": "Main Line", "home": 1.8, "away": 2.0},
        )
        self.assertEqual(
            normalized[1]["lines"][0],
            {
                "type": "main",
                "label": "Main Line",
                "home": 1.9,
                "away": 2.1,
                "no_goal": 8.5,
            },
        )

    def test_full_time_result_keeps_only_the_full_time_line(self):
        odds = [
            {
                "market": "Full Time Result",
                "lines": [
                    {"type": "main", "label": "", "home": 2.07, "draw": 3.25, "away": 4.5},
                    {"type": "main", "label": "", "home": 2.4, "draw": 2.38, "away": 4.5},
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="Switzerland", away="Algeria")

        self.assertEqual(
            normalized[0]["lines"],
            [
                {
                    "type": "main",
                    "label": "Main Line",
                    "home": 2.07,
                    "draw": 3.25,
                    "away": 4.5,
                }
            ],
        )

    def test_odds_extractor_keeps_middle_outcomes_and_no_goal(self):
        """Regression guard for football rows with three or more outcomes."""
        self.assertIn("else if (t.indexOf('NO GOAL') >= 0) dir = 'no_goal';", _JS_EXTRACT_ODDS)
        self.assertIn("buttons.forEach(function(button)", _JS_EXTRACT_ODDS)
        self.assertIn("entry.no_goal = s.val", _JS_EXTRACT_ODDS)

    def test_european_handicap_extracts_logo_backed_tie_as_draw(self):
        """European Handicap's logo odds boxes must preserve the third outcome."""
        self.assertIn(
            ".odd-box-with-label__label, .odd-box-with-logo__label",
            _JS_EXTRACT_ODDS,
        )
        self.assertIn("hasToken(t, 'TIE') || hasToken(t, 'X')", _JS_EXTRACT_ODDS)
        self.assertIn(
            "lbl === 'DRAW' || lbl === 'TIE' || lbl === 'X'",
            _JS_EXTRACT_ODDS,
        )
        self.assertIn("Home|Draw|Tie|X|Away", _JS_EXTRACT_ODDS)

    def test_odds_extractor_supports_nested_and_single_outcome_rows(self):
        """Correct Score and Double Chance use non-standard card row layouts."""
        self.assertIn("var candidates = Array.from(row.querySelectorAll", _JS_EXTRACT_ODDS)
        self.assertIn("containsOddsChild", _JS_EXTRACT_ODDS)
        self.assertIn("parsedCount >= 2 || entry.outcomes", _JS_EXTRACT_ODDS)
        self.assertIn("function parseLooseCard(card, market)", _JS_EXTRACT_ODDS)
        loose_card_source = _JS_EXTRACT_ODDS.split("function parseLooseCard(card, market)", 1)[1]
        loose_card_source = loose_card_source.split("function getMarketName(card)", 1)[0]
        self.assertIn(
            "return count >= 2 || entry.outcomes ? entry : null;",
            loose_card_source,
        )
        self.assertIn("var fragmented = lines.length", _JS_EXTRACT_ODDS)

    def test_odds_extractor_recovers_nested_threshold_and_handicap_labels(self):
        """Line labels share a wrapper with odds controls on football cards."""
        self.assertIn("function looksLikeLineLabel(text)", _JS_EXTRACT_ODDS)
        self.assertIn('[class*="label"], [class*="line"], [class*="handicap"]', _JS_EXTRACT_ODDS)
        self.assertIn('if (node.closest(\'button, a, [role="button"]', _JS_EXTRACT_ODDS)
        self.assertIn("left every total/handicap line with an empty label", _JS_EXTRACT_ODDS)
        self.assertIn("var node = row", _JS_EXTRACT_ODDS)
        self.assertIn("node = node.parentElement", _JS_EXTRACT_ODDS)
        self.assertIn('.matchup-handicap-line-info > [class*="text-capitalize"]', _JS_EXTRACT_ODDS)

    def test_odds_extractor_skips_hidden_period_tabs(self):
        """Hidden 1st/2nd-half panes must not be added to Full Time Result."""
        self.assertIn("function isRendered(el)", _JS_EXTRACT_ODDS)
        self.assertIn("if (!isRendered(rows[r])) continue;", _JS_EXTRACT_ODDS)
        self.assertIn("if (!isRendered(allRows[r])) continue;", _JS_EXTRACT_ODDS)
        self.assertIn('"1:0 Compare', _JS_EXTRACT_ODDS)

    def test_merge_removes_a_duplicate_fallback_schema_line(self):
        unmatched = {
            "market": "Half Time / Full Time",
            "schema_status": "unmatched",
            "lines": [
                {
                    "type": "main",
                    "label": "",
                    "schema_status": "unmatched",
                    "combinations": {"home_home": 2.0, "draw_draw": 8.5},
                }
            ],
        }
        normalized = {
            "market": "Half Time / Full Time",
            "lines": [
                {
                    "type": "main",
                    "label": "",
                    "combinations": {"home_home": 2.0, "draw_draw": 8.5},
                }
            ],
        }

        merged = _merge_odds_markets([], [unmatched, normalized])

        self.assertEqual(len(merged), 1)
        self.assertEqual(len(merged[0]["lines"]), 1)
        self.assertNotIn("schema_status", merged[0])
        self.assertNotIn("schema_status", merged[0]["lines"][0])

    def test_odds_extractor_preserves_half_time_full_time_combinations(self):
        self.assertIn("var isCompositeOutcome = /[\\/→>]/.test(explicitLabel);", _JS_EXTRACT_ODDS)
        self.assertIn(
            "return {dir: 'outcome', outcome: explicitLabel, val: val};", _JS_EXTRACT_ODDS
        )

    def test_market_selector_clicks_the_specific_control(self):
        from src.oddspedia.scraping.match_scraper import _click_football_market_selector

        # The callable's script is intentionally kept outside the test driver;
        # this guards against reintroducing broad market/filter ancestors.
        class Driver:
            def execute_script(self, script, *_args):
                self.script = script
                return None

        driver = Driver()
        _click_football_market_selector(driver, "Double Chance")
        self.assertIn("function controlFor(el)", driver.script)
        self.assertIn(".btn-group-item__btn, .btn-group-item, li, [tabindex]", driver.script)
        self.assertNotIn('[class*="market"], [class*="filter"]', driver.script)

    def test_market_selector_uses_native_click(self):
        from src.oddspedia.scraping.match_scraper import _click_football_market_selector

        class Clickable:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.element = Clickable()
                self.calls = 0

            def execute_script(self, *_args):
                self.calls += 1
                return self.element if self.calls == 1 else None

        driver = Driver()
        self.assertTrue(_click_football_market_selector(driver, "Correct Score"))
        self.assertTrue(driver.element.clicked)

    @patch(
        "src.oddspedia.scraping.match_scraper._current_odds_dom_signature", return_value="before"
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._click_football_market_selector", return_value=True
    )
    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_odds", return_value=[])
    def test_all_unresolved_exposed_markets_are_terminally_unavailable(
        self, _wait, _click, _signature
    ):
        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return ["Double Chance"]
                return []

        with self.assertRaisesRegex(FootballOddsUnavailableError, "Double Chance"):
            _extract_football_odds(Driver(), [], home="Spain", away="Austria")

    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_card", return_value=True)
    @patch("src.oddspedia.scraping.match_scraper._click_football_market_card", return_value=True)
    def test_collapsed_football_cards_are_expanded_before_parsing(self, click_card, wait_card):
        class Driver:
            def execute_script(self, script, *_args):
                if (
                    "return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))"
                    in script
                ):
                    return ["Double Chance", "Correct Score"]
                return None

        _expand_football_market_cards(Driver())
        self.assertEqual(click_card.call_args_list[0].args[1], "Double Chance")
        self.assertEqual(wait_card.call_args_list[1].args[1], "Correct Score")

    @patch(
        "src.oddspedia.scraping.match_scraper._expand_football_market_card_lines", return_value=1
    )
    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_card", return_value=True)
    @patch("src.oddspedia.scraping.match_scraper._click_football_market_card", return_value=True)
    def test_targeted_market_card_expansion_skips_completed_markets(
        self, click_card, wait_card, expand_lines
    ):
        class Driver:
            def execute_script(self, *_args):
                return ["Double Chance", "Correct Score"]

        _expand_football_market_cards(Driver(), market_names=["Correct Score"])

        click_card.assert_called_once_with(unittest.mock.ANY, "Correct Score")
        wait_card.assert_called_once_with(unittest.mock.ANY, "Correct Score")
        expand_lines.assert_called_once_with(unittest.mock.ANY, "Correct Score")

    @patch(
        "src.oddspedia.scraping.match_scraper._expand_football_market_card_lines", return_value=0
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._wait_for_football_market_odds",
        return_value=[
            {"market": "Correct Score", "lines": [{"label": "1-0", "scores": {"1-0": 7.0}}]}
        ],
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._click_football_market_selector", return_value=True
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._current_odds_dom_signature", return_value="before"
    )
    def test_targeted_market_extraction_clicks_only_the_requested_missing_market(
        self, _signature, click_selector, _wait, _expand_lines
    ):
        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return ["Double Chance", "Correct Score"]
                if script == _JS_EXTRACT_ODDS:
                    return [
                        {
                            "market": "Correct Score",
                            "lines": [{"type": "main", "label": "1-0", "outcomes": {"1-0": 7.0}}],
                        }
                    ]
                return []

        odds, unresolved = _extract_football_odds(
            Driver(),
            [],
            home="Home",
            away="Away",
            target_markets=["Correct Score"],
            raise_on_unresolved=False,
            return_unresolved=True,
        )

        click_selector.assert_called_once_with(unittest.mock.ANY, "Correct Score")
        self.assertEqual([market["market"] for market in odds], ["Correct Score"])
        self.assertEqual(unresolved, [])

    def test_expands_show_more_lines_within_the_market_card(self):
        class Button:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.button = Button()
                self.calls = 0

            def execute_script(self, script, *_args):
                self.calls += 1
                self.last_script = script
                return self.button if self.calls == 1 else None

        driver = Driver()
        self.assertEqual(_expand_football_market_card_lines(driver, "Total Corners"), 1)
        self.assertTrue(driver.button.clicked)
        self.assertIn("show more", driver.last_script.lower())

    def test_football_market_list_expansion_uses_one_scoped_control(self):
        from src.oddspedia.scraping.match_scraper import _expand_football_market_list

        class Button:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.button = Button()
                self.card_count = 4
                self.market_list_queries = 0

            def execute_script(self, script, *_args):
                self.last_script = script
                if "return {button: button" in script:
                    self.selector_script = script
                    self.market_list_queries += 1
                    return {
                        "button": self.button if self.market_list_queries == 1 else None,
                        "cards": self.card_count,
                    }
                if "querySelectorAll('.matchup-odds-comparison-card').length" in script:
                    self.card_count = 22
                    return self.card_count
                return None

        driver = Driver()
        expanded = _expand_football_market_list(driver)

        self.assertEqual(expanded, 18)
        self.assertTrue(driver.button.clicked)
        self.assertIn("show all(?: markets)?", driver.selector_script.lower())

    @patch(
        "src.oddspedia.scraping.match_scraper._expand_football_market_card_lines", return_value=1
    )
    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_card", return_value=True)
    @patch("src.oddspedia.scraping.match_scraper._click_football_market_card", return_value=True)
    def test_european_handicap_card_expands_its_alternative_lines(
        self, click_card, wait_card, expand_lines
    ):
        class Driver:
            def execute_script(self, *_args):
                return ["European Handicap"]

        _expand_football_market_cards(Driver())

        click_card.assert_called_once_with(unittest.mock.ANY, "European Handicap")
        wait_card.assert_called_once_with(unittest.mock.ANY, "European Handicap")
        expand_lines.assert_called_once_with(unittest.mock.ANY, "European Handicap")

    @patch(
        "src.oddspedia.scraping.match_scraper._expand_football_market_card_lines", return_value=0
    )
    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_odds")
    @patch(
        "src.oddspedia.scraping.match_scraper._click_football_market_selector", return_value=True
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._current_odds_dom_signature", return_value="before"
    )
    def test_captured_european_handicap_is_reopened_to_collect_alternative_lines(
        self, _signature, _click, wait_for_market, _expand_lines
    ):
        fixture_path = os.path.join(
            ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json"
        )
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)
        wait_for_market.return_value = fixture["initial"]

        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return ["European Handicap"]
                if script == _JS_EXTRACT_ODDS:
                    return fixture["expanded"]
                return []

        odds = _extract_football_odds(Driver(), fixture["initial"], home="Canada", away="Morocco")

        self.assertEqual(odds[0]["lines"], fixture["expanded"][0]["lines"])
        _click.assert_called_once_with(unittest.mock.ANY, "European Handicap")

    def test_expanded_european_handicap_fixture_preserves_every_line(self):
        fixture_path = os.path.join(
            ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json"
        )
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)

        normalized = _normalize_football_odds(fixture["expanded"], home="Canada", away="Morocco")

        self.assertEqual(normalized[0]["lines"], fixture["expanded"][0]["lines"])

    def test_total_goals_alternative_lines_are_preserved(self):
        odds = [
            {
                "market": "Total Goals",
                "lines": [
                    {"type": "main", "label": "2.5", "over": 3.6, "under": 1.2},
                    {"type": "alternative", "label": "1.5", "over": 1.2, "under": 4.4},
                    {"type": "alternative", "label": "3.5", "over": 6.0, "under": 1.1},
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="PAEEK FC", away="Nea Salamis")

        self.assertEqual(normalized[0]["lines"], odds[0]["lines"])

    def test_odds_extractor_uses_parameterized_market_line_containers(self):
        self.assertIn(".matchup-handicap-line,", _JS_EXTRACT_ODDS)

    @patch(
        "src.oddspedia.scraping.match_scraper._expand_football_market_card_lines", return_value=0
    )
    @patch("src.oddspedia.scraping.match_scraper._wait_for_football_market_odds")
    @patch(
        "src.oddspedia.scraping.match_scraper._click_football_market_selector", return_value=True
    )
    @patch(
        "src.oddspedia.scraping.match_scraper._current_odds_dom_signature", return_value="before"
    )
    def test_unlabeled_european_handicap_is_skipped_without_retrying_match(
        self, _signature, _click, wait_for_market, _expand_lines
    ):
        fixture_path = os.path.join(
            ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json"
        )
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)
        wait_for_market.return_value = fixture["incomplete"]

        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return []
                if script == _JS_EXTRACT_ODDS:
                    return fixture["incomplete"]
                return []

        odds = _extract_football_odds(
            Driver(), fixture["incomplete"], home="Canada", away="Morocco"
        )

        self.assertEqual(odds, [])

    def test_football_correct_score_outcomes_are_saved_as_scores(self):
        odds = [
            {
                "market": "Correct Score",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"1-0": 7.0, "0-0": 9.5},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(normalized[0]["lines"][0]["scores"], {"1-0": 7.0, "0-0": 9.5})
        self.assertNotIn("outcomes", normalized[0]["lines"][0])

    def test_football_single_correct_score_outcome_is_saved(self):
        odds = [
            {
                "market": "Correct Score",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"4 : 4": 90.0},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="CA Chaco For Ever", away="Godoy Cruz")

        self.assertEqual(
            normalized,
            [
                {
                    "market": "Correct Score",
                    "lines": [
                        {
                            "type": "main",
                            "label": "Main Line",
                            "scores": {"4 : 4": 90.0},
                        }
                    ],
                }
            ],
        )

    def test_football_market_contract_drops_ambiguous_parameterized_lines(self):
        odds = [
            {
                "market": "Total Goals",
                "lines": [
                    {"type": "main", "label": "2.5", "over": 1.9, "under": 1.9},
                    {"type": "alternative", "label": "1.25", "under": 6.4, "home_away": 1.12},
                ],
            },
            {
                "market": "Asian Handicap",
                "lines": [{"type": "main", "label": "", "yes": 1.83, "no": 1.95}],
            },
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")

        self.assertEqual(len(normalized), 1)
        self.assertEqual(normalized[0]["market"], "Total Goals")
        self.assertEqual(
            normalized[0]["lines"][0], {"type": "main", "label": "2.5", "over": 1.9, "under": 1.9}
        )

    def test_football_market_contract_maps_dash_separated_half_time_full_time_outcomes(self):
        odds = [
            {
                "market": "Half Time / Full Time",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"USA - USA": 2.0, "Draw - USA": 4.5},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")

        self.assertEqual(normalized[0]["market"], "Half Time / Full Time")
        self.assertEqual(
            normalized[0]["lines"][0]["combinations"],
            {"home_home": 2.0, "draw_home": 4.5},
        )
        self.assertNotIn("schema_status", normalized[0])

    def test_football_half_time_full_time_maps_one_x_two_outcomes(self):
        odds = [
            {
                "market": "Half Time / Full Time",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {
                            "1/1": 2.0,
                            "1/X": 12.0,
                            "1/2": 29.0,
                            "X/1": 7.0,
                            "X/X": 8.5,
                            "X/2": 12.0,
                            "2/1": 34.0,
                            "2/X": 15.0,
                            "2/2": 5.5,
                        },
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(
            normalized[0]["lines"][0]["combinations"],
            {
                "home_home": 2.0,
                "home_draw": 12.0,
                "home_away": 29.0,
                "draw_home": 7.0,
                "draw_draw": 8.5,
                "draw_away": 12.0,
                "away_home": 34.0,
                "away_draw": 15.0,
                "away_away": 5.5,
            },
        )

    def test_football_half_time_full_time_preserves_canonical_combination_keys(self):
        normalized = _normalize_football_odds(
            [
                {
                    "market": "Half Time / Full Time",
                    "schema_status": "unmatched",
                    "lines": [
                        {
                            "type": "main",
                            "label": "",
                            "schema_status": "unmatched",
                            "combinations": {
                                "home_home": 2.0,
                                "draw_draw": 8.5,
                                "away_away": 5.5,
                            },
                        }
                    ],
                }
            ],
            home="Canada",
            away="Morocco",
        )

        self.assertEqual(
            normalized[0]["lines"][0]["combinations"],
            {"home_home": 2.0, "draw_draw": 8.5, "away_away": 5.5},
        )
        self.assertEqual(normalized[0]["lines"][0]["label"], "Main Line")
        self.assertNotIn("schema_status", normalized[0])
        self.assertNotIn("schema_status", normalized[0]["lines"][0])

    def test_football_selector_context_does_not_relabel_known_stale_market(self):
        markets = [
            {
                "market": "Both Teams to Score",
                "lines": [{"type": "main", "label": "", "yes": 1.9, "no": 1.8}],
            }
        ]

        contextual = _apply_football_selector_context(markets, "Asian Handicap")

        self.assertEqual(contextual[0]["market"], "Both Teams to Score")

    def test_football_selector_requires_the_requested_market(self):
        stale = [
            {
                "market": "Total Goals",
                "lines": [{"type": "main", "label": "2.5", "over": 1.9, "under": 1.9}],
            }
        ]
        rendered = [
            {
                "market": "Total Corners",
                "lines": [{"type": "main", "label": "9.5", "over": 1.9, "under": 1.9}],
            }
        ]

        self.assertFalse(_football_selector_rendered(stale, "Total Corners"))
        self.assertTrue(_football_selector_rendered(rendered, "Total Corners"))

    def test_period_selector_requires_period_context(self):
        markets = [
            {
                "market": "1st Half - Total Goals",
                "lines": [{"type": "main", "label": "0.5", "over": 1.8, "under": 2.0}],
            }
        ]

        self.assertTrue(_football_selector_rendered(markets, "1st Half"))
        self.assertFalse(_football_selector_rendered(markets, "2nd Half"))

    def test_football_world_cup_market_shapes_are_explicit(self):
        odds = [
            {
                "market": "Full Time Result",
                "lines": [{"type": "main", "label": "", "home": 1.4, "draw": 5.0, "away": 8.0}],
            },
            {
                "market": "1st Half - Total Goals",
                "lines": [{"type": "main", "label": "1.5", "over": 2.0, "under": 1.8}],
            },
            {
                "market": "Asian Handicap",
                "lines": [{"type": "main", "label": "-1/+1", "home": 1.9, "away": 1.9}],
            },
            {
                "market": "Both Teams to Score",
                "lines": [{"type": "main", "label": "", "yes": 1.95, "no": 1.83}],
            },
            {
                "market": "Double Chance",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "home_draw": 1.1,
                        "draw_away": 3.2,
                        "home_away": 1.2,
                    }
                ],
            },
            {
                "market": "Draw No Bet",
                "lines": [{"type": "main", "label": "", "home": 1.2, "away": 4.5}],
            },
            {
                "market": "First Team to Score",
                "lines": [{"type": "main", "label": "", "home": 1.4, "away": 3.1, "no_goal": 9.0}],
            },
            {
                "market": "Correct Score",
                "lines": [{"type": "main", "label": "", "outcomes": {"1-0": 7.0, "2-0": 9.0}}],
            },
            {
                "market": "European Handicap",
                "lines": [
                    {"type": "main", "label": "-1/+1", "home": 2.1, "draw": 3.7, "away": 3.3}
                ],
            },
            {
                "market": "Half Time / Full Time",
                "lines": [
                    {"type": "main", "label": "", "outcomes": {"USA/USA": 2.0, "Draw/USA": 4.5}}
                ],
            },
            {
                "market": "Next Goal",
                "lines": [{"type": "main", "label": "", "home": 1.3, "away": 3.8, "no_goal": 12.0}],
            },
            {
                "market": "Corners Odd or Even",
                "lines": [{"type": "main", "label": "", "odd": 1.9, "even": 1.9}],
            },
            {
                "market": "Clean Sheet",
                "lines": [{"type": "main", "label": "", "home": 2.0, "away": 8.0}],
            },
            {
                "market": "To Win Both Halves",
                "lines": [{"type": "main", "label": "", "home": 3.0, "away": 34.0}],
            },
            {
                "market": "To Score in Both Halves",
                "lines": [{"type": "main", "label": "", "home": 2.8, "away": 20.0}],
            },
            {
                "market": "To Score a Penalty",
                "lines": [{"type": "main", "label": "", "home": 5.0, "away": 8.0}],
            },
            {
                "market": "Total Corners",
                "lines": [{"type": "main", "label": "9.5", "over": 1.9, "under": 1.9}],
            },
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")
        by_market = {market["market"]: market["lines"][0] for market in normalized}

        self.assertNotIn("1st Half - Total Goals", by_market)
        self.assertEqual(
            set(by_market),
            {market["market"] for market in odds if not market["market"].startswith("1st Half -")},
        )
        self.assertEqual(
            by_market["Half Time / Full Time"]["combinations"], {"home_home": 2.0, "draw_home": 4.5}
        )
        self.assertEqual(by_market["Correct Score"]["scores"], {"1-0": 7.0, "2-0": 9.0})
        self.assertEqual(by_market["Corners Odd or Even"]["odd"], 1.9)
        self.assertNotIn("outcomes", by_market["Half Time / Full Time"])

    def test_market_discovery_excludes_period_tabs_and_card_headers(self):
        self.assertIn(
            "if (/^(1st|2nd) half$/i.test(text)) return;", _JS_FOOTBALL_MARKET_SELECTOR_TEXTS
        )
        self.assertIn(
            "control.classList.contains('matchup-odds-comparison-card__header')",
            _JS_FOOTBALL_MARKET_SELECTOR_TEXTS,
        )

    def test_market_discovery_excludes_money_on_betting_data_links(self):
        self.assertFalse(_is_football_market_selector_text("44% of Money on Draw Betting data"))
        self.assertTrue(_is_football_market_selector_text("Draw No Bet"))
        self.assertIn(r"\bmoney\s+on\b", _JS_FOOTBALL_MARKET_SELECTOR_TEXTS)
        self.assertIn(r"\bbetting\s+data\b", _JS_FOOTBALL_MARKET_SELECTOR_TEXTS)

    def test_extract_football_odds_does_not_click_money_on_betting_data_link(self):
        class Driver:
            def execute_script(self, script, *_args):
                if script == _JS_FOOTBALL_MARKET_SELECTOR_TEXTS:
                    return ["44% of Money on Draw Betting data"]
                return False

        base_odds = [
            {
                "market": "Full Time Result",
                "lines": [{"type": "main", "label": "", "home": 2.1, "draw": 3.2, "away": 3.4}],
            }
        ]
        with patch(
            "src.oddspedia.scraping.match_scraper._click_football_market_selector"
        ) as click_selector:
            odds = _extract_football_odds(Driver(), base_odds, home="Blackburn", away="Portsmouth")

        click_selector.assert_not_called()
        self.assertEqual([market["market"] for market in odds], ["Full Time Result"])

    def test_normalization_keeps_only_full_time_markets(self):
        odds = [
            {
                "market": "European Handicap",
                "lines": [
                    {"type": "main", "label": "-1/+1", "home": 3.3, "draw": 3.75, "away": 2.0}
                ],
            },
            {
                "market": "1st Half - European Handicap",
                "lines": [
                    {"type": "main", "label": "-1/+1", "home": 6.0, "draw": 4.0, "away": 1.5}
                ],
            },
            {
                "market": "2nd Half - Total Goals",
                "lines": [{"type": "main", "label": "1.5", "over": 1.8, "under": 2.0}],
            },
        ]

        normalized = _normalize_football_odds(odds, home="Brazil", away="Norway")

        self.assertEqual([market["market"] for market in normalized], ["European Handicap"])

    def test_european_handicap_maps_live_tie_outcome_to_draw(self):
        odds = [
            {
                "market": "European Handicap",
                "lines": [
                    {
                        "type": "main",
                        "label": "-1/+1",
                        "outcomes": {"Home": 3.3, "Tie": 3.75, "Away": 2.0},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="Brazil", away="Norway")

        self.assertEqual(
            normalized[0]["lines"],
            [{"type": "main", "label": "-1/+1", "home": 3.3, "draw": 3.75, "away": 2.0}],
        )


if __name__ == "__main__":
    unittest.main()
