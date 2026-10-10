"""Oddspedia Bronze loader admission and identity-safety tests."""

import json
from datetime import datetime
from types import SimpleNamespace

import pytest

from src.oddspedia.bronze.loader import (
    OddspediaBronzeAdmissionError,
    OddspediaBronzeLoader,
    _parse_datetime,
)
from src.oddspedia.scraping.link_prioritization import source_inventory_checksum
from src.oddspedia.scraping.manifest import ScrapeManifest


def _accepted_manifest(date_id: str, records, *, done=None) -> ScrapeManifest:
    manifest = ScrapeManifest(date=date_id, sport="football", total=len(done or []))
    manifest.discovery = {
        "status": "no_events" if not records else "accepted",
        "match_count": len(records),
        "inventory_checksum": source_inventory_checksum(records),
        "empty_confirmed": not records,
    }
    manifest.done = list(done or [])
    return manifest


def _accepted_payload(match_id: str = "42"):
    return {
        "sport": "football",
        "id": match_id,
        "source_event_id": match_id,
        "home": "Home",
        "away": "Away",
        "tournament": "League",
        "date": "2026-03-13",
        "url": "https://oddspedia.com/football/home-away-42",
        "status": "FT",
        "score": {"home": 1, "away": 0, "winner": "home"},
        "odds": [
            {
                "market": "Full Time Result",
                "lines": [{"label": "Main Line", "home": 2.0, "draw": 3.0, "away": 4.0}],
            }
        ],
        "scraped_at": "2026-03-13T23:45:14+03:30",
    }


def test_bronze_load_rejects_a_missing_discovery_manifest(monkeypatch, tmp_path) -> None:
    records = [{"id": "42", "home": "Home", "away": "Away", "date": "2026-03-13"}]
    links_path = tmp_path / "match_links.json"
    links_path.write_text(json.dumps(records), encoding="utf-8")
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.get_match_links_file", lambda _date_id: str(links_path)
    )
    monkeypatch.setattr("src.oddspedia.bronze.loader.load_manifest", lambda *_args, **_kwargs: None)

    with pytest.raises(OddspediaBronzeAdmissionError, match="manifest"):
        OddspediaBronzeLoader(client=None).load_date("20260313", dry_run=True)


def test_bronze_load_rejects_an_incomplete_existing_payload(monkeypatch, tmp_path) -> None:
    records = [
        {
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-03-13",
            "url": "https://oddspedia.com/football/home-away-42",
        }
    ]
    links_path = tmp_path / "match_links.json"
    links_path.write_text(json.dumps(records), encoding="utf-8")
    manifest = _accepted_manifest("20260313", records, done=["42"])
    incomplete = _accepted_payload()
    incomplete["status"] = ""
    incomplete["odds"] = []
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.get_match_links_file", lambda _date_id: str(links_path)
    )
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.load_manifest", lambda *_args, **_kwargs: manifest
    )
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.iter_match_payloads",
        lambda _date_id: [
            SimpleNamespace(
                match_id="42",
                source_file="/tmp/match_42.json",
                payload=incomplete,
                size_bytes=900,
            )
        ],
    )

    with pytest.raises(OddspediaBronzeAdmissionError, match="not accepted"):
        OddspediaBronzeLoader(client=None).load_date("20260313", dry_run=True)


def test_bronze_load_accepts_audited_payload_and_normalizes_utc(monkeypatch, tmp_path) -> None:
    records = [
        {
            "id": "42",
            "home": "Home",
            "away": "Away",
            "date": "2026-03-13",
            "url": "https://oddspedia.com/football/home-away-42",
        }
    ]
    links_path = tmp_path / "match_links.json"
    links_path.write_text(json.dumps(records), encoding="utf-8")
    manifest = _accepted_manifest("20260313", records, done=["42"])
    payload = _accepted_payload()
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.get_match_links_file", lambda _date_id: str(links_path)
    )
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.load_manifest", lambda *_args, **_kwargs: manifest
    )
    monkeypatch.setattr(
        "src.oddspedia.bronze.loader.iter_match_payloads",
        lambda _date_id: [
            SimpleNamespace(
                match_id="42",
                source_file="/tmp/match_42.json",
                payload=payload,
                size_bytes=1200,
            )
        ],
    )

    result = OddspediaBronzeLoader(client=None).load_date("20260313", dry_run=True)

    assert result.event_rows == 1
    assert result.payload_rows == 1
    assert result.market_rows == 1
    assert _parse_datetime("2026-03-13T23:45:14+03:30") == datetime(2026, 3, 13, 20, 15, 14)


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


def test_bronze_publication_stages_all_tables_before_first_partition_replace():
    class _BatchClient:
        def __init__(self):
            self.operations = []

        def execute(self, query, parameters=None):
            self.operations.append(("execute", query))
            if query.lstrip().startswith("SELECT count()"):
                return SimpleNamespace(result_rows=[(1,)])
            return SimpleNamespace(result_rows=[])

        def insert_dataframe(self, table, dataframe, database=None):
            self.operations.append(("insert", table, dataframe.iloc[0]["status"]))
            return len(dataframe)

        def insert_dataframe_qualified_table(self, table, dataframe, database=None):
            self.operations.append(("stage_insert", table))
            return len(dataframe)

    client = _BatchClient()
    loader = OddspediaBronzeLoader(client=client)
    row = {"oddspedia_match_id": "42", "event_date": datetime(2026, 3, 13).date()}
    loader._publish_date(
        "20260313",
        [dict(row, discovery_date=row["event_date"])],
        [row],
        [dict(row, market_name="1X2")],
        inventory_checksum="checksum",
        run_id="run123",
    )

    operations = client.operations
    create_positions = [
        index
        for index, operation in enumerate(operations)
        if operation[0] == "execute" and operation[1].startswith("CREATE TABLE")
    ]
    replace_positions = [
        index
        for index, operation in enumerate(operations)
        if operation[0] == "execute" and operation[1].startswith("ALTER TABLE")
    ]
    assert len(create_positions) == 3
    assert len(replace_positions) == 3
    assert max(create_positions) < min(replace_positions)
    assert all(
        operation[1].startswith("CREATE TABLE warehouse_stage._oddspedia_")
        for operation in (operations[index] for index in create_positions)
    )
    assert all(
        " FROM warehouse_stage._oddspedia_" in operations[index][1] for index in replace_positions
    )
    status_inserts = [operation for operation in operations if operation[0] == "insert"]
    assert [operation[2] for operation in status_inserts] == ["staging", "published"]


def test_bronze_publication_records_failed_status_when_partition_replace_fails():
    class _FailingBatchClient:
        def __init__(self):
            self.statuses = []
            self.replace_count = 0

        def execute(self, query, parameters=None):
            if query.lstrip().startswith("SELECT count()"):
                return SimpleNamespace(result_rows=[(1,)])
            if query.startswith("ALTER TABLE"):
                self.replace_count += 1
                if self.replace_count == 2:
                    raise RuntimeError("partition replace failed")
            return SimpleNamespace(result_rows=[])

        def insert_dataframe(self, table, dataframe, database=None):
            self.statuses.append(dataframe.iloc[0]["status"])
            return len(dataframe)

        def insert_dataframe_qualified_table(self, table, dataframe, database=None):
            return len(dataframe)

    client = _FailingBatchClient()
    loader = OddspediaBronzeLoader(client=client)
    row = {"oddspedia_match_id": "42", "event_date": datetime(2026, 3, 13).date()}

    with pytest.raises(RuntimeError, match="partition replace failed"):
        loader._publish_date(
            "20260313",
            [dict(row, discovery_date=row["event_date"])],
            [row],
            [dict(row, market_name="1X2")],
            inventory_checksum="checksum",
            run_id="run123",
        )

    assert client.statuses == ["staging", "failed"]
