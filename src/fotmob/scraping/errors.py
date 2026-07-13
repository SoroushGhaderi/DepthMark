"""FotMob scraper-specific errors."""

from typing import Any, Dict


class FotMobMatchDataNotFoundError(Exception):
    """FotMob listed the match but returned no detail payload."""

    def __init__(self, match_id: str):
        self.match_id = match_id
        super().__init__(f"FotMob data not found for match {match_id}")


def is_fotmob_data_not_found_response(response_data: Dict[str, Any]) -> bool:
    """Return True when FotMob's matchDetails API has no data for a listed match."""
    if not isinstance(response_data, dict):
        return False

    if response_data.get("error") is not True:
        return False

    message = str(response_data.get("message", "")).strip().lower()
    return message == "data not found"
