from src.oddspedia.scraping.match_collector import _merge_league_names


def test_jsonld_event_url_preserves_canonical_team_slug():
    matches = {
        "9955415": {
            "id": "9955415",
            "home": "Algeciras",
            "away": "CD Teruel",
            "url": "/football/algeciras-cd-teruel-1660684",
            "full_url": "https://oddspedia.com/football/algeciras-cd-teruel-1660684",
            "matchKey": "algeciras-cd-teruel-1660684",
        }
    }
    league_matches = {
        "1660684": {
            "matchId": "9955415",
            "home": "Algeciras CF",
            "away": "CD Teruel",
            "league": "Primera RFEF Group 2",
            "url": "/football/algeciras-cf-cd-teruel-1660684",
        }
    }

    _merge_league_names(matches, league_matches, overwrite=True)

    assert matches["9955415"]["url"] == "/football/algeciras-cf-cd-teruel-1660684"
    assert matches["9955415"]["full_url"] == (
        "https://oddspedia.com/football/algeciras-cf-cd-teruel-1660684"
    )
    assert matches["9955415"]["matchKey"] == "algeciras-cf-cd-teruel-1660684"
