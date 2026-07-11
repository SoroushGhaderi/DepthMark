import os
import json
import sys
import unittest
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from src.oddspedia.match_collector import (
    _JS_SPORT_STATE,
    _fetch_all_matches,
    _is_full_time_match,
    _listing_status_token,
    _merge_league_names,
    _match_country,
    _match_country_slug,
    _match_league_name,
    _is_league_name,
    collect_match_links,
)


class _FakeDriver:
    pass


class FullTimeFilterTests(unittest.TestCase):
    def test_match_league_name_accepts_archived_api_shapes(self):
        self.assertEqual(_match_league_name({"league_name": "Premier League"}), "Premier League")
        self.assertEqual(_match_league_name({"league": {"name": "NPL Queensland"}}), "NPL Queensland")
        self.assertEqual(_match_league_name({"competition": {"title": "Chile Cup"}}), "Chile Cup")

    def test_match_league_name_rejects_card_navigation_and_score_text(self):
        self.assertFalse(_is_league_name("Odds"))
        self.assertFalse(_is_league_name("FT Portsmouth Bombers Mahaut Soca Strikers 1 0"))
        self.assertEqual(_match_league_name({"league": "Odds"}), "")

    def test_match_country_supports_listing_and_archive_shapes(self):
        self.assertEqual(_match_country({"category_name": "Australia"}), "Australia")
        self.assertEqual(_match_country({"country": {"name": "England"}}), "England")
        self.assertEqual(_match_country_slug({"category_slug": "australia"}), "australia")

    def test_merge_league_names_matches_archived_dom_path(self):
        matches = {
            "101": {
                "matchId": "101",
                "matchKey": "away-home-123",
                "url": "/a/football/away-home-123",
                "league_name": "",
            }
        }
        dom_links = {
            "123": {
                "numericId": "123",
                "path": "/a/football/away-home-123",
                "slug": "away-home-123",
                "league": "Women's Primera A",
                "country": "Chile",
                "country_slug": "chile",
                "league_slug": "primera-a-women",
            }
        }

        _merge_league_names(matches, dom_links)

        self.assertEqual(matches["101"]["league_name"], "Women's Primera A")
        self.assertEqual(matches["101"]["country"], "Chile")
        self.assertEqual(matches["101"]["country_slug"], "chile")
        self.assertEqual(matches["101"]["league_slug"], "primera-a-women")

    def test_merge_league_names_uses_internal_match_id_when_urls_are_missing(self):
        fixture_path = os.path.join(ROOT, "tests", "fixtures", "oddspedia", "phase1_league_sources.json")
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)

        _merge_league_names(fixture["matches"], fixture["source_events"])

        match = fixture["matches"]["10128494"]
        self.assertEqual(match["league_name"], "FIFA World Cup")
        self.assertEqual(match["country"], "World")

    def test_merge_league_names_matches_archived_event_by_teams_and_date(self):
        fixture_path = os.path.join(ROOT, "tests", "fixtures", "oddspedia", "phase1_league_sources.json")
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)

        _merge_league_names(fixture["archived_matches"], fixture["archived_source_events"])

        match = fixture["archived_matches"]["10128475"]
        self.assertEqual(match["league_name"], "Primera A Women")
        self.assertEqual(match["country"], "Argentina")

    @patch("src.oddspedia.match_collector._extract_dom_links", return_value={})
    @patch("src.oddspedia.match_collector.time.sleep", return_value=None)
    def test_fetch_all_matches_continues_after_an_empty_page(self, _sleep, _dom_links):
        class Driver:
            def __init__(self):
                self.page = 1

            def execute_script(self, script, *_args):
                if "sport.loadNextPage" in script:
                    self.page += 1
                    return None
                if script == _JS_SPORT_STATE:
                    size = 50 if self.page < 3 else 100
                    return {
                        "matchList": [
                            {"id": i, "ht": f"Home {i}", "at": f"Away {i}"}
                            for i in range(size)
                        ],
                        "currentPage": self.page,
                        "totalPages": 3,
                        "isLoadingNextPage": False,
                        "sampleMatches": [],
                    }
                return None

        matches = _fetch_all_matches(Driver(), sport="football")

        self.assertEqual(len(matches), 100)

    @patch("src.oddspedia.match_collector._extract_dom_links", return_value={})
    @patch("src.oddspedia.match_collector.time.sleep", return_value=None)
    def test_fetch_result_marks_stalled_pagination_incomplete(self, _sleep, _dom_links):
        class Driver:
            def execute_script(self, script, *_args):
                if script == _JS_SPORT_STATE:
                    return {
                        "matchList": [{"id": 1, "ht": "Home", "at": "Away"}],
                        "currentPage": 1,
                        "totalPages": 2,
                        "isLoadingNextPage": False,
                        "sampleMatches": [],
                    }
                return None

        result = _fetch_all_matches(Driver(), sport="football", return_result=True)

        self.assertFalse(result.complete)
        self.assertEqual(result.expected_pages, 2)
        self.assertEqual(result.observed_pages, 1)
        self.assertIn("pagination_stalled", result.anomalies)

    def test_structured_league_name_overrides_dom_fallback(self):
        matches = {
            "101": {
                "matchId": "101",
                "url": "/football/away-home-123",
                "league_name": "Odds",
            }
        }
        sports_events = {
            "123": {
                "url": "/football/away-home-123",
                "league": "Bundesliga",
            }
        }

        _merge_league_names(matches, sports_events, overwrite=True)

        self.assertEqual(matches["101"]["league_name"], "Bundesliga")

    def test_is_full_time_match_requires_ft(self):
        self.assertTrue(_is_full_time_match({"status": "FT"}))
        self.assertTrue(_is_full_time_match({"status": " ft "}))
        self.assertTrue(_is_full_time_match({"status": "OT"}))
        self.assertTrue(_is_full_time_match({"status": "PEN"}))
        self.assertTrue(_is_full_time_match({"inplay_status": "FT", "status": "[score payload]"}))
        self.assertFalse(_is_full_time_match({"status": "LIVE"}))
        self.assertFalse(_is_full_time_match({"status": "Postponed"}))
        self.assertFalse(_is_full_time_match({"matchstatus": 4, "special_status": "Postponed"}))
        self.assertFalse(_is_full_time_match({"status": ""}))

    def test_listing_status_preserves_non_terminal_statuses(self):
        self.assertEqual(_listing_status_token({"status": "LIVE"}), "LIVE")
        self.assertEqual(_listing_status_token({"status": "Not Started"}), "NOTSTARTED")
        self.assertEqual(
            _listing_status_token({"status": "https://schema.org/EventScheduled"}),
            "EVENTSCHEDULED",
        )

    def test_listing_status_ignores_score_payload_and_uses_fallback(self):
        match = {
            "status": '[{"home":1,"away":0}]',
            "inplay_status": "FT",
        }

        self.assertEqual(_listing_status_token(match), "FT")

    @patch("src.oddspedia.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.match_collector._build_urls")
    @patch("src.oddspedia.match_collector._extract_dom_links")
    @patch("src.oddspedia.match_collector._extract_matches_vuex")
    @patch("src.oddspedia.match_collector._extract_matches_from_sports_events")
    @patch("src.oddspedia.match_collector._fetch_all_matches")
    @patch("src.oddspedia.match_collector._navigate_to_date", return_value=True)
    @patch("src.oddspedia.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.match_collector.safe_get", return_value=True)
    def test_collect_match_links_keeps_all_matches_with_statuses(
        self,
        _safe_get,
        _dismiss_cookie_popup,
        _navigate_to_date,
        fetch_all_matches,
        extract_sports_events,
        extract_vuex,
        extract_dom_links,
        build_urls,
        _sleep,
    ):
        driver = _FakeDriver()
        fetch_all_matches.return_value = {
            "1": {
                "matchId": "1",
                "matchKey": "team-a-team-b-1",
                "home": "Team A",
                "away": "Team B",
                "league": "League",
                "date": "2026-07-01",
                "status": "FT",
                "url": "/football/team-a-team-b-1",
                "full_url": "https://oddspedia.com/football/team-a-team-b-1",
            },
            "2": {
                "matchId": "2",
                "matchKey": "team-c-team-d-2",
                "home": "Team C",
                "away": "Team D",
                "league": "League",
                "date": "2026-07-01",
                "status": "LIVE",
                "url": "/football/team-c-team-d-2",
                "full_url": "https://oddspedia.com/football/team-c-team-d-2",
            },
        }
        extract_dom_links.return_value = {}

        matches = collect_match_links(driver, target_date="2026-07-01", sport="football")

        self.assertEqual(len(matches), 2)
        self.assertEqual({m["id"] for m in matches}, {"1", "2"})
        self.assertEqual({m["status"] for m in matches}, {"FT", "LIVE"})
        extract_sports_events.assert_called_once()
        extract_vuex.assert_not_called()
        build_urls.assert_called_once()

    @patch("src.oddspedia.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.match_collector._build_urls")
    @patch("src.oddspedia.match_collector._extract_dom_links")
    @patch("src.oddspedia.match_collector._extract_matches_vuex")
    @patch("src.oddspedia.match_collector._extract_matches_from_sports_events")
    @patch("src.oddspedia.match_collector._fetch_all_matches")
    @patch("src.oddspedia.match_collector._navigate_to_date", return_value=True)
    @patch("src.oddspedia.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.match_collector.safe_get", return_value=True)
    def test_collect_match_links_preserves_listing_metadata(
        self,
        _safe_get,
        _dismiss_cookie_popup,
        _navigate_to_date,
        fetch_all_matches,
        extract_sports_events,
        extract_vuex,
        extract_dom_links,
        build_urls,
        _sleep,
    ):
        driver = _FakeDriver()
        fetch_all_matches.return_value = {
            "10128494": {
                "matchId": "10128494",
                "matchKey": "australia-egypt-1979571",
                "home": "Australia",
                "away": "Egypt",
                "date": "2026-07-04 17:00:00+00",
                "status": "PEN",
                "url": "/football/australia-egypt-1979571",
                "full_url": "https://oddspedia.com/football/australia-egypt-1979571",
            }
        }
        extract_dom_links.return_value = {
            "1979571": {
                "path": "/football/australia-egypt-1979571",
                "slug": "australia-egypt-1979571",
                "numericId": "1979571",
                "archived": False,
                "status": "PEN",
            }
        }
        extract_sports_events.return_value = {
            "1979571": {
                "id": "1979571",
                "url": "/football/australia-egypt-1979571",
                "league_name": "FIFA World Cup",
            }
        }

        matches = collect_match_links(driver, target_date="2026-07-04", sport="football")

        self.assertEqual(len(matches), 1)
        match = matches[0]
        self.assertEqual(match["status"], "PEN")
        self.assertEqual(match["league_name"], "FIFA World Cup")
        self.assertNotIn("league", match)
        self.assertNotIn("tournament", match)
        extract_sports_events.assert_called_once()
        extract_vuex.assert_not_called()
        build_urls.assert_called_once()


if __name__ == "__main__":
    unittest.main()
