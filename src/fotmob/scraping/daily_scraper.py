"""Scraper for fetching daily match listings."""

import os
from typing import Any, Dict, List

from .base_scraper import BaseScraper


class DailyScraper(BaseScraper):
    """Scraper for fetching all matches for a given date."""

    def fetch_matches_for_date(self, date_str: str) -> List[int]:
        """
        Fetch all match IDs for a specific date.

        Args:
            date_str: Date in YYYYMMDD format

        Returns:
            List of match IDs
        """
        self.logger.info(f"Fetching matches for date: {date_str}")

        url = f"{self.config.api.base_url}/matches"
        timezone = os.getenv("FOTMOB_TIMEZONE", "Asia/Tehran")
        params = {"date": date_str, "timezone": timezone}

        response_data = self.make_request(url, params=params)

        if not response_data:
            self.logger.error(f"Failed to fetch matches for date: {date_str}")
            return []

        match_ids = self._extract_match_ids(response_data)
        self.logger.info(f"Found {len(match_ids)} matches for {date_str}")

        return match_ids

    def _extract_match_ids(self, response_data: Dict[str, Any]) -> List[int]:
        """
        Extract all match IDs from the API response.

        Args:
            response_data: API response data

        Returns:
            List of match IDs (filtered by status if enabled)
        """
        match_ids = []
        filtered_count = 0
        status_counts = {}

        leagues = response_data.get("leagues", [])
        if not isinstance(leagues, list):
            self.logger.warning("No leagues found in response")
            return match_ids

        for league in leagues:
            if not isinstance(league, dict):
                continue

            matches = league.get("matches", [])
            if not isinstance(matches, list):
                continue

            for match in matches:
                if not isinstance(match, dict) or "id" not in match:
                    continue

                match_status = match.get("status", {})
                if isinstance(match_status, dict):
                    status_text = match_status.get("finished", False)
                    status_reason = match_status.get("reason", {})
                    if isinstance(status_reason, dict):
                        status_short = status_reason.get("short", "Unknown")
                    else:
                        status_short = "Unknown"
                else:
                    status_text = False
                    status_short = "Unknown"

                status_counts[status_short] = status_counts.get(status_short, 0) + 1

                if self.config.scraping.filter_by_status:
                    if status_text or status_short in self.config.scraping.allowed_match_statuses:
                        match_ids.append(match["id"])
                    else:
                        filtered_count += 1
                        self.logger.debug(
                            f"Filtered out match {match['id']} " f"with status: {status_short}"
                        )
                else:
                    match_ids.append(match["id"])

        if self.config.scraping.filter_by_status:
            self.logger.info(
                f"Status filter: {len(match_ids)} matches included, "
                f"{filtered_count} matches filtered out"
            )
        self.logger.debug(f"Status breakdown: {status_counts}")

        return match_ids
