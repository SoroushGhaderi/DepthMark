import os
import sys
import unittest
from datetime import date
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from src.oddspedia.scraping.match_collector import _navigate_to_date, collect_match_links


class _FakeDriver:
    pass


class _NavigationDriver:
    def __init__(self):
        self.execute_script_calls = []

    def execute_script(self, script, *args):
        self.execute_script_calls.append((script, args))
        if args and args[0] == "2026-07-06":
            return "no-day-match"
        if args and args[0] == "next":
            return "ok:BUTTONx2"
        return "Jul 6"


class CollectMatchLinksDateTests(unittest.TestCase):
    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.scraping.match_collector._fetch_all_matches")
    @patch("src.oddspedia.scraping.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.scraping.match_collector._navigate_to_date", return_value=False)
    @patch("src.oddspedia.scraping.match_collector.safe_get", return_value=True)
    def test_aborts_when_date_navigation_fails(
        self,
        _safe_get,
        navigate_to_date,
        dismiss_cookie_popup,
        fetch_all_matches,
        _sleep,
    ):
        driver = _FakeDriver()

        matches = collect_match_links(driver, target_date="20260701", sport="football")

        self.assertEqual(matches, [])
        navigate_to_date.assert_called_once_with(driver, "20260701")
        dismiss_cookie_popup.assert_called_once_with(driver)
        fetch_all_matches.assert_not_called()

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.scraping.match_collector._fetch_all_matches", return_value={})
    @patch("src.oddspedia.scraping.match_collector._extract_matches_from_sports_events", return_value={})
    @patch("src.oddspedia.scraping.match_collector._extract_matches_vuex", return_value={})
    @patch("src.oddspedia.scraping.match_collector._navigate_to_date", return_value=True)
    @patch("src.oddspedia.scraping.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.scraping.match_collector.safe_get")
    def test_reuses_rendered_listing_without_reloading(
        self, safe_get, dismiss_cookie_popup, navigate_to_date, _extract_vuex, _extract_sports_events,
        _fetch_all_matches, _sleep,
    ):
        matches = collect_match_links(
            _FakeDriver(), target_date="20260702", sport="football", reuse_listing=True
        )

        self.assertEqual(matches, [])
        safe_get.assert_not_called()
        dismiss_cookie_popup.assert_not_called()
        navigate_to_date.assert_called_once()

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.scraping.match_collector._fetch_all_matches")
    @patch("src.oddspedia.scraping.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.scraping.match_collector._navigate_to_date", side_effect=[False, False])
    @patch("src.oddspedia.scraping.match_collector.safe_get", return_value=True)
    def test_reused_listing_reloads_once_after_navigation_failure(
        self, safe_get, navigate_to_date, dismiss_cookie_popup, fetch_all_matches, _sleep
    ):
        matches = collect_match_links(
            _FakeDriver(), target_date="20260702", sport="football", reuse_listing=True
        )

        self.assertEqual(matches, [])
        self.assertEqual(navigate_to_date.call_count, 2)
        safe_get.assert_called_once()
        dismiss_cookie_popup.assert_called_once()
        fetch_all_matches.assert_not_called()

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch("src.oddspedia.scraping.match_collector._extract_matches_from_sports_events", return_value={})
    @patch("src.oddspedia.scraping.match_collector._build_urls")
    @patch("src.oddspedia.scraping.match_collector._fetch_all_matches")
    @patch("src.oddspedia.scraping.match_collector._navigate_to_date", return_value=True)
    @patch("src.oddspedia.scraping.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.scraping.match_collector.safe_get", return_value=True)
    def test_rejects_listing_when_source_events_do_not_include_target_date(
        self, _safe_get, _dismiss, _navigate, fetch, _build, _events, _sleep
    ):
        fetch.return_value = {
            "1": {
                "matchId": "1", "home": "Home", "away": "Away",
                "date": "2026-04-03T19:00:00+00:00",
            }
        }

        discovery = collect_match_links(
            _FakeDriver(), target_date="20260404", sport="football", return_result=True
        )

        self.assertFalse(discovery.complete)
        self.assertIn("listing_target_date_missing", discovery.anomalies)

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch(
        "src.oddspedia.scraping.match_collector._read_displayed_date",
        side_effect=[date(2026, 7, 5), date(2026, 7, 6)],
    )
    def test_arrow_fallback_accepts_yyyymmdd_and_passes_iso_date_to_calendar(
        self, _read_displayed_date, _sleep
    ):
        driver = _NavigationDriver()

        self.assertTrue(_navigate_to_date(driver, "20260706"))
        self.assertEqual(driver.execute_script_calls[0][1], ("2026-07-06",))


if __name__ == "__main__":
    unittest.main()
