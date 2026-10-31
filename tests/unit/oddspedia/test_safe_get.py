import unittest
from unittest.mock import patch

from src.oddspedia.scraping.utils import safe_get


class _FakeDriver:
    def __init__(self):
        self.current_url = "https://oddspedia.com/football"
        self.title = "Just a moment..."
        self.get_calls = []
        self.reconnect_calls = 0

    def get(self, url):
        self.get_calls.append(url)
        self.current_url = url

    def reconnect(self):
        self.reconnect_calls += 1


class SafeGetTests(unittest.TestCase):
    @patch("src.oddspedia.scraping.utils.random_delay")
    @patch("src.oddspedia.scraping.utils.time.sleep", return_value=None)
    def test_retries_after_cloudflare_timeout(self, _sleep, _random_delay):
        driver = _FakeDriver()
        attempts = {"count": 0}

        def wait_for_cloudflare(driver_obj, timeout=None):
            attempts["count"] += 1
            if attempts["count"] == 1:
                return False
            driver_obj.title = "Oddspedia Football"
            return True

        with patch(
            "src.oddspedia.scraping.utils.wait_for_cloudflare", side_effect=wait_for_cloudflare
        ):
            result = safe_get(driver, "https://oddspedia.com/football", retries=2)

        self.assertTrue(result)
        self.assertEqual(
            driver.get_calls, ["https://oddspedia.com/football", "https://oddspedia.com/football"]
        )
        self.assertEqual(driver.reconnect_calls, 1)

    @patch("src.oddspedia.scraping.utils.random_delay")
    @patch("src.oddspedia.scraping.utils.wait_for_cloudflare", return_value=True)
    def test_rejects_listing_shell_for_detail_url(self, _wait_for_cloudflare, _random_delay):
        driver = _FakeDriver()
        driver.title = "Football Live Scores & Stats » Today's Fixtures, Results and News"

        result = safe_get(
            driver,
            "https://oddspedia.com/football/algeciras-cd-teruel-1660684",
            retries=1,
        )

        self.assertFalse(result)
        self.assertEqual(
            driver.get_calls, ["https://oddspedia.com/football/algeciras-cd-teruel-1660684"]
        )


if __name__ == "__main__":
    unittest.main()
