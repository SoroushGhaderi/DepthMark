"""Oddspedia Bronze loader identity-safety tests."""

from types import SimpleNamespace

from src.oddspedia.bronze.loader import OddspediaBronzeLoader


def test_bronze_loader_skips_legacy_market_salvage_payloads(monkeypatch) -> None:
    """Do not load odds attributed to a different rendered event."""
    payloads = [
        SimpleNamespace(
            source_file="/tmp/mismatched.json",
            payload={
                "id": "9970625",
                "source_event_id": "9970600",
                "identity_validation": "market_salvaged",
                "scraped_at": "2026-08-05T09:45:14+00:00",
                "odds": [
                    {
                        "market": "Total Goals",
                        "lines": [{"label": "2.5", "over": 1.8, "under": 2.0}],
                    }
                ],
            },
        ),
        SimpleNamespace(
            source_file="/tmp/verified.json",
            payload={
                "id": "9970626",
                "source_event_id": "9970626",
                "scraped_at": "2026-08-05T09:45:14+00:00",
                "odds": [
                    {
                        "market": "Total Goals",
                        "lines": [{"label": "2.5", "over": 1.8, "under": 2.0}],
                    }
                ],
            },
        ),
    ]
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.iter_match_payloads", lambda _date_id: payloads
    )

    payload_rows, market_rows = OddspediaBronzeLoader(client=None)._payload_rows("20260313")

    assert [row["oddspedia_match_id"] for row in payload_rows] == ["9970626"]
    assert [row["oddspedia_match_id"] for row in market_rows] == ["9970626"]
