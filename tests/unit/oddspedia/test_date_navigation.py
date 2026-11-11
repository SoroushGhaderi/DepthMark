import itertools
import unittest
from datetime import date
from unittest.mock import patch

from src.oddspedia.scraping.match_collector import (
    _navigate_to_date,
    _read_displayed_date,
    _wait_for_listing_ready,
    collect_match_links,
)

DATE_BUTTON_SELECTOR = ".period-navigation__current-period-button"
REMOVED_DATE_BUTTON_SELECTOR = ".flex.align-items-center.p-0"


class _FakeDriver:
    """A driver whose listing page has already rendered."""

    title = "Football"

    def execute_script(self, script, *args):
        return {"matchList": []}


class _UnrenderedDriver:
    """A driver stuck on Cloudflare's shell page: no Sport component."""

    title = "oddspedia.com"

    def execute_script(self, script, *args):
        return None


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


class _PickerRetryDriver:
    def __init__(self):
        self.execute_script_calls = []
        self.picker_attempts = 0

    def execute_script(self, script, *args):
        self.execute_script_calls.append((script, args))
        if args and args[0] == "2026-07-06":
            self.picker_attempts += 1
            return (
                "no-day-match|no-input|vue-root-missing"
                if self.picker_attempts == 1
                else "input-set"
            )
        return "Jul 6"


class _DisplayedDateDriver:
    def __init__(self, value):
        self.value = value

    def execute_script(self, script, *args):
        return self.value


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
    @patch(
        "src.oddspedia.scraping.match_collector._extract_matches_from_sports_events",
        return_value={},
    )
    @patch("src.oddspedia.scraping.match_collector._extract_matches_vuex", return_value={})
    @patch("src.oddspedia.scraping.match_collector._navigate_to_date", return_value=True)
    @patch("src.oddspedia.scraping.match_collector._dismiss_cookie_popup")
    @patch("src.oddspedia.scraping.match_collector.safe_get")
    def test_reuses_rendered_listing_without_reloading(
        self,
        safe_get,
        dismiss_cookie_popup,
        navigate_to_date,
        _extract_vuex,
        _extract_sports_events,
        _fetch_all_matches,
        _sleep,
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
    @patch(
        "src.oddspedia.scraping.match_collector._extract_matches_from_sports_events",
        return_value={},
    )
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
                "matchId": "1",
                "home": "Home",
                "away": "Away",
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

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch(
        "src.oddspedia.scraping.match_collector._read_displayed_date",
        return_value=date(2026, 7, 6),
    )
    def test_calendar_picker_retries_transient_dom_failure(self, _read_displayed_date, _sleep):
        driver = _PickerRetryDriver()

        self.assertTrue(_navigate_to_date(driver, "20260706"))
        self.assertEqual(driver.picker_attempts, 2)

    def test_displayed_date_uses_nearest_year_at_year_boundary(self):
        driver = _DisplayedDateDriver("Dec 31")

        self.assertEqual(
            _read_displayed_date(driver, reference_date=date(2027, 1, 1)),
            date(2026, 12, 31),
        )

    def test_displayed_date_reads_the_live_day_month_format(self):
        # The football listing's date button reads "11 Nov" (2026-11-11).
        driver = _DisplayedDateDriver("11 Nov")

        self.assertEqual(
            _read_displayed_date(driver, reference_date=date(2026, 11, 9)),
            date(2026, 11, 11),
        )

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch(
        "src.oddspedia.scraping.match_collector._read_displayed_date",
        side_effect=[date(2026, 7, 5), date(2026, 7, 6)],
    )
    def test_date_navigation_targets_the_period_navigation_button(
        self, _read_displayed_date, _sleep
    ):
        driver = _NavigationDriver()

        self.assertTrue(_navigate_to_date(driver, "20260706"))
        scripts = [script for script, _args in driver.execute_script_calls]
        self.assertTrue(any(DATE_BUTTON_SELECTOR in script for script in scripts))
        self.assertFalse(any(REMOVED_DATE_BUTTON_SELECTOR in script for script in scripts))


class WaitForListingReadyTests(unittest.TestCase):
    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    def test_ready_when_sport_component_exposes_match_list(self, _sleep):
        self.assertTrue(_wait_for_listing_ready(_FakeDriver(), timeout=1))

    @patch("src.oddspedia.scraping.match_collector.time.sleep", return_value=None)
    @patch(
        "src.oddspedia.scraping.match_collector.time.time",
        side_effect=itertools.count(0, 0.6),
    )
    def test_not_ready_when_sport_component_never_mounts(self, _time, _sleep):
        self.assertFalse(_wait_for_listing_ready(_UnrenderedDriver(), timeout=1))

    @patch("src.oddspedia.scraping.match_collector._navigate_to_date")
    @patch("src.oddspedia.scraping.match_collector._wait_for_listing_ready", return_value=False)
    @patch("src.oddspedia.scraping.match_collector.safe_get", return_value=True)
    def test_discovery_stops_before_date_navigation_when_listing_never_renders(
        self, _safe_get, _wait, navigate_to_date
    ):
        discovery = collect_match_links(
            _UnrenderedDriver(), target_date="20261109", sport="football", return_result=True
        )

        self.assertFalse(discovery.complete)
        self.assertEqual(discovery.anomalies, ["listing_page_not_rendered"])
        navigate_to_date.assert_not_called()


if __name__ == "__main__":
    unittest.main()
