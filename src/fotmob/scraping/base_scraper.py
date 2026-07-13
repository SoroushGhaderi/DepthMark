import random
import time
from typing import Any, Dict, Optional

from config import FotMobConfig

from src.core import ScraperProtocol
from src.common.logging import get_logger
from .playwright_fetcher import PlaywrightFetcher

logger = get_logger(__name__)


class BaseScraper(ScraperProtocol):
    """
    Base class for FotMob API scrapers.

    All HTTP requests are routed through a single headless Chromium instance
    (via PlaywrightFetcher) so that FotMob's client-side JavaScript can attach
    a valid, URL-specific x-mas token to every outgoing request automatically.
    """

    def __init__(self, config: FotMobConfig):
        self.config = config
        self.logger = logger
        self._fetcher = PlaywrightFetcher(config)

    def _delay_request(self):
        """Random inter-request delay to avoid rate-limiting."""
        delay = random.uniform(
            self.config.request.delay_min,
            self.config.request.delay_max,
        )
        self.logger.debug(f"Waiting {delay:.2f}s before next request")
        time.sleep(delay)

    def make_request(
        self,
        url: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> Optional[Dict[str, Any]]:
        """Make a browser-based GET request with automatic x-mas token injection."""
        self._delay_request()
        self.logger.debug(f"Browser request → {url}")

        result = self._fetcher.fetch_json(url, params)

        if result is None:
            self.logger.error(f"Request failed: {url}")

        return result

    def close(self):
        """Shut down the headless browser."""
        self._fetcher.close()
        self.logger.debug("Scraper closed")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
