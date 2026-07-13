"""Unit tests for the independent Bronze S3 sync service."""

import hashlib
import io
import json
import tarfile
from pathlib import Path
from typing import Dict, List

import pytest

from src.fotmob.bronze.s3_sync import BronzeS3Service, BronzeS3SyncError


class FakeS3Client:
    """In-memory object store implementing the service-facing S3 interface."""

    def __init__(self) -> None:
        self.bucket_name = "scout-sport"
        self.objects: Dict[str, bytes] = {}
        self.metadata: Dict[str, Dict] = {}
        self.upload_calls: List[str] = []

    def object_exists(self, key: str) -> bool:
        return key in self.objects

    def object_metadata(self, key: str) -> Dict:
        return self.metadata.get(key, {"Metadata": {}})

    def upload_file(self, local_path: Path, key: str, sha256: str) -> None:
        payload = local_path.read_bytes()
        self.objects[key] = payload
        self.metadata[key] = {"Metadata": {"sha256": sha256}}
        self.upload_calls.append(key)

    def download_file(self, key: str, local_path: Path) -> None:
        local_path.write_bytes(self.objects[key])

    def list_keys(self, prefix: str) -> List[str]:
        return sorted(key for key in self.objects if key.startswith(prefix))


def create_complete_date(bronze_path: Path, date_str: str = "20251208") -> None:
    matches_path = bronze_path / "matches" / date_str[:6] / date_str
    listing_path = bronze_path / "daily_listings" / date_str[:6] / date_str
    matches_path.mkdir(parents=True)
    listing_path.mkdir(parents=True)
    (matches_path / "match_101.json").write_text('{"id": 101}', encoding="utf-8")
    (listing_path / "matches.json").write_text(
        json.dumps(
            {
                "match_ids": [101, 102],
                "storage": {"unavailable_match_ids": [102]},
            }
        ),
        encoding="utf-8",
    )


def archive_bytes(entries: Dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        for name, payload in entries.items():
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
    return buffer.getvalue()


def test_upload_includes_matches_and_daily_listing(tmp_path: Path) -> None:
    bronze_path = tmp_path / "fotmob"
    create_complete_date(bronze_path)
    client = FakeS3Client()
    service = BronzeS3Service(bronze_path, client)

    result = service.upload_date("20251208")

    assert result.status == "uploaded"
    assert result.key == "scout-sport/bronze/fotmob/202512/20251208.tar.gz"
    assert result.sha256 == hashlib.sha256(client.objects[result.key]).hexdigest()
    with tarfile.open(fileobj=io.BytesIO(client.objects[result.key]), mode="r:gz") as archive:
        names = archive.getnames()
    assert "matches/202512/20251208/match_101.json" in names
    assert "daily_listings/202512/20251208/matches.json" in names
    assert (bronze_path / "matches" / "202512" / "20251208" / "match_101.json").exists()


def test_upload_rejects_incomplete_date_unless_explicitly_allowed(tmp_path: Path) -> None:
    bronze_path = tmp_path / "fotmob"
    create_complete_date(bronze_path)
    listing_path = bronze_path / "daily_listings" / "202512" / "20251208" / "matches.json"
    listing_path.write_text(
        json.dumps({"match_ids": [101, 103], "storage": {"unavailable_match_ids": []}}),
        encoding="utf-8",
    )
    client = FakeS3Client()
    service = BronzeS3Service(bronze_path, client)

    with pytest.raises(BronzeS3SyncError, match="1 match files missing"):
        service.upload_date("20251208")

    result = service.upload_date("20251208", allow_incomplete=True)
    assert result.status == "uploaded"


def test_upload_dry_run_does_not_create_remote_object(tmp_path: Path) -> None:
    bronze_path = tmp_path / "fotmob"
    create_complete_date(bronze_path)
    client = FakeS3Client()
    service = BronzeS3Service(bronze_path, client)

    result = service.upload_date("20251208", dry_run=True)

    assert result.status == "planned"
    assert client.objects == {}
    assert client.upload_calls == []


def test_download_restores_new_archive_and_checks_checksum(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = BronzeS3Service.object_key("20251208")
    payload = archive_bytes(
        {
            "matches/202512/20251208/match_101.json": b'{"id": 101}',
            "daily_listings/202512/20251208/matches.json": b'{"match_ids": [101]}',
        }
    )
    client.objects[key] = payload
    client.metadata[key] = {"Metadata": {"sha256": hashlib.sha256(payload).hexdigest()}}
    bronze_path = tmp_path / "fotmob"
    service = BronzeS3Service(bronze_path, client)

    result = service.download_date("20251208")

    assert result.status == "downloaded"
    assert (bronze_path / "matches" / "202512" / "20251208" / "match_101.json").exists()
    assert (bronze_path / "daily_listings" / "202512" / "20251208" / "matches.json").exists()


def test_download_supports_bucket_prefixed_legacy_object_key(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = "scout-sport/bronze/fotmob/202512/20251208.tar.gz"
    payload = archive_bytes(
        {
            "matches/202512/20251208/match_101.json": b'{"id": 101}',
            "daily_listings/202512/20251208/matches.json": b'{"match_ids": [101]}',
        }
    )
    client.objects[key] = payload
    client.metadata[key] = {"Metadata": {}}

    result = BronzeS3Service(tmp_path / "fotmob", client).download_date("20251208")

    assert result.key == key


def test_download_rejects_checksum_mismatch_without_local_mutation(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = BronzeS3Service.object_key("20251208")
    client.objects[key] = archive_bytes({"20251208/match_101.json": b"{}"})
    client.metadata[key] = {"Metadata": {"sha256": "incorrect"}}
    bronze_path = tmp_path / "fotmob"
    service = BronzeS3Service(bronze_path, client)

    with pytest.raises(BronzeS3SyncError, match="checksum mismatch"):
        service.download_date("20251208")

    assert not bronze_path.exists()


def test_download_rejects_new_archive_without_listing_file(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = BronzeS3Service.object_key("20251208")
    client.objects[key] = archive_bytes({"matches/202512/20251208/match_101.json": b"{}"})
    client.metadata[key] = {"Metadata": {}}
    service = BronzeS3Service(tmp_path / "fotmob", client)

    with pytest.raises(BronzeS3SyncError, match="missing its daily listing"):
        service.download_date("20251208")


def test_download_restores_previous_archive_layout_to_canonical_paths(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = BronzeS3Service.object_key("20251208")
    payload = archive_bytes(
        {
            "matches/20251208/match_101.json": b'{"id": 101}',
            "daily_listings/20251208/matches.json": b'{"match_ids": [101]}',
        }
    )
    client.objects[key] = payload
    client.metadata[key] = {"Metadata": {}}
    bronze_path = tmp_path / "fotmob"

    BronzeS3Service(bronze_path, client).download_date("20251208")

    assert (bronze_path / "matches" / "202512" / "20251208" / "match_101.json").exists()
    assert (bronze_path / "daily_listings" / "202512" / "20251208" / "matches.json").exists()


def test_download_supports_legacy_archive_and_force_replacement(tmp_path: Path) -> None:
    client = FakeS3Client()
    key = BronzeS3Service.object_key("20251208")
    client.objects[key] = archive_bytes({"20251208/match_202.json": b'{"id": 202}'})
    client.metadata[key] = {"Metadata": {}}
    bronze_path = tmp_path / "fotmob"
    create_complete_date(bronze_path)
    service = BronzeS3Service(bronze_path, client)

    with pytest.raises(BronzeS3SyncError, match="use --force"):
        service.download_date("20251208")

    service.download_date("20251208", force=True)
    assert (bronze_path / "matches" / "202512" / "20251208" / "match_202.json").exists()
    assert not (bronze_path / "matches" / "202512" / "20251208" / "match_101.json").exists()
    assert not (bronze_path / "daily_listings" / "202512" / "20251208").exists()


def test_remote_date_listing_ignores_unrelated_keys(tmp_path: Path) -> None:
    client = FakeS3Client()
    client.objects = {
        "bronze/fotmob/202512/20251208.tar.gz": b"archive",
        "scout-sport/bronze/fotmob/202512/20251209.tar.gz": b"legacy archive",
        "bronze/fotmob/not-a-date.txt": b"ignore",
        "bronze/other/202512/20251209.tar.gz": b"ignore",
    }
    service = BronzeS3Service(tmp_path / "fotmob", client)

    assert service.list_remote_dates() == ["20251208", "20251209"]


def test_object_key_rejects_invalid_calendar_date() -> None:
    with pytest.raises(BronzeS3SyncError, match="invalid calendar date"):
        BronzeS3Service.object_key("20251340")
