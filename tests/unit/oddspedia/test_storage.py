import gzip
import json
import tarfile
from pathlib import Path
from unittest.mock import patch

from src.oddspedia.scraping.cli import _compress_completed_date
from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.storage import (
    compress_date_files,
    iter_match_payloads,
    read_match_payload,
)


def _payload(match_id: str) -> dict:
    return {
        "sport": "football",
        "id": match_id,
        "home": "Home",
        "away": "Away",
        "date": "2026-07-01",
        "url": f"https://oddspedia.com/football/example-{match_id}",
        "status": "FT",
        "score": {"home": 1, "away": 0},
        "odds": [{"market": "Full Time Result", "lines": [{"home": 2.0}]}],
    }


def _write_payload(directory: Path, match_id: str) -> None:
    with (directory / f"{match_id}.json").open("w", encoding="utf-8") as output:
        json.dump(_payload(match_id), output)


def test_compress_date_uses_fotmob_archive_shape(tmp_path):
    date_dir = tmp_path / "historical" / "matches" / "202607" / "20260701"
    date_dir.mkdir(parents=True)
    _write_payload(date_dir, "101")
    _write_payload(date_dir, "102")

    with (
        patch("src.oddspedia.scraping.storage.get_matches_dir", return_value=str(date_dir)),
        patch(
            "src.oddspedia.scraping.storage.get_match_file",
            side_effect=lambda date, match_id, sport="football": str(date_dir / f"{match_id}.json"),
        ),
    ):
        result = compress_date_files("20260701")
        archive_path = date_dir / "20260701_matches.tar"
        stored = list(iter_match_payloads("20260701"))

    assert result["status"] == "success"
    assert archive_path.exists()
    assert not (date_dir / "101.json").exists()
    assert not (date_dir / "102.json").exists()
    with tarfile.open(archive_path, "r") as archive:
        assert sorted(member.name for member in archive.getmembers()) == [
            "101.json.gz",
            "102.json.gz",
        ]
        member = archive.extractfile("101.json.gz")
        assert member is not None
        with gzip.open(member, "rt", encoding="utf-8") as payload_file:
            assert json.load(payload_file)["id"] == "101"
    assert [item.match_id for item in stored] == ["101", "102"]


def test_compress_date_merges_new_payloads_into_existing_archive(tmp_path):
    date_dir = tmp_path / "historical" / "matches" / "202607" / "20260701"
    date_dir.mkdir(parents=True)
    _write_payload(date_dir, "101")

    with (
        patch("src.oddspedia.scraping.storage.get_matches_dir", return_value=str(date_dir)),
        patch(
            "src.oddspedia.scraping.storage.get_match_file",
            side_effect=lambda date, match_id, sport="football": str(date_dir / f"{match_id}.json"),
        ),
    ):
        assert compress_date_files("20260701")["status"] == "success"
        _write_payload(date_dir, "102")
        result = compress_date_files("20260701")
        stored = list(iter_match_payloads("20260701"))
        archived_101 = read_match_payload("20260701", "101")

    assert result["status"] == "success"
    assert [item.match_id for item in stored] == ["101", "102"]
    assert archived_101 is not None
    assert archived_101.source_file.endswith("20260701_matches.tar#101.json.gz")


def test_completed_historical_scrape_triggers_compression():
    manifest = ScrapeManifest(date="20260701", sport="football", total=1)
    manifest.mark_done("101")

    with (
        patch("src.oddspedia.scraping.cli.get_storage_aspect", return_value="historical"),
        patch(
            "src.oddspedia.scraping.cli.compress_date_files",
            return_value={"status": "success", "compressed": 1, "archive_file": "archive.tar"},
        ) as compress,
    ):
        _compress_completed_date(manifest, "20260701")

    compress.assert_called_once_with("20260701", sport="football")
