from src.oddspedia.scraping.utils import pin_oddspedia_event_url


def test_pin_oddspedia_event_url_adds_event_selector_to_matchup_url():
    expected = (
        "https://oddspedia.com/football/" "deportes-recoleta-union-san-felipe-133331?m=9876168"
    )

    assert (
        pin_oddspedia_event_url(
            "https://oddspedia.com/football/deportes-recoleta-union-san-felipe-133331",
            "9876168",
        )
        == expected
    )


def test_pin_oddspedia_event_url_replaces_stale_selector_and_preserves_other_query_values():
    expected = "/football/union-san-felipe-deportes-recoleta-133331?tab=odds&m=9876168#markets"

    assert (
        pin_oddspedia_event_url(
            "/football/union-san-felipe-deportes-recoleta-133331?tab=odds&m=9876090#markets",
            "9876168",
        )
        == expected
    )
