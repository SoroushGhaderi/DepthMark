"""Scraper for fetching detailed match data."""

from typing import Any, Dict, Optional

from .base_scraper import BaseScraper
from .errors import FotMobMatchDataNotFoundError, is_fotmob_data_not_found_response


class MatchScraper(BaseScraper):
    """Scraper for fetching detailed match information."""

    def fetch_match_details(
        self, match_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch detailed match data from FotMob API.

        Args:
            match_id: Match ID to fetch

        Returns:
            Match data as dictionary, or None if failed
        """
        self.logger.info(f"Fetching match details for ID: {match_id}")

        url = f"{self.config.api.base_url}/matchDetails"
        params = {"matchId": match_id}

        response_data = self.make_request(url, params=params)

        if not response_data:
            self.logger.error(
                f"Failed to fetch match details for ID: {match_id}"
            )
            return None

        if is_fotmob_data_not_found_response(response_data):
            self.logger.warning(
                "FotMob listed match but returned no detail data",
                extra={"match_id": match_id},
            )
            raise FotMobMatchDataNotFoundError(match_id)

        if not self._validate_match_response(response_data, match_id):
            return None

        self.logger.info(
            f"Successfully fetched match details for ID: {match_id}"
        )
        return response_data

    def _validate_match_response(
        self, response_data: Dict[str, Any], match_id: str
    ) -> bool:
        """
        Validate that the response contains expected match data structure.

        Args:
            response_data: API response data
            match_id: Match ID being validated

        Returns:
            True if response is valid, False otherwise
        """
        if "general" not in response_data:
            self.logger.error(
                f"Missing 'general' section for match {match_id}"
            )
            return False

        general = response_data.get("general", {})
        if not isinstance(general, dict):
            self.logger.error(
                f"Invalid 'general' section for match {match_id}"
            )
            return False

        returned_match_id = general.get("matchId")
        if returned_match_id is not None:
            try:
                if str(returned_match_id) != str(match_id):
                    self.logger.warning(
                        f"Match ID mismatch: requested {match_id}, "
                        f"got {returned_match_id}"
                    )
            except (ValueError, TypeError):
                self.logger.warning(
                    f"Invalid match ID format: requested {match_id}, "
                    f"got {returned_match_id}"
                )

        return True
