"""Offline tests for the opt-in Oddspedia ``--upload-s3`` flag (ADR 0035).

No test reaches S3 or a browser: the S3 client is an in-memory fake and the
scrape phase is replaced by a stub that returns a manifest.
"""

import hashlib
import io
import json
import tarfile
from contextlib import nullcontext
from datetime import date
from pathlib import Path
from unittest.mock import Mock

import pytest

from src.oddspedia.bronze.s3_sync import OddspediaBronzeS3Service, OddspediaS3UploadError
from src.oddspedia.scraping import cli
from src.oddspedia.scraping.manifest import ScrapeManifest

DATE = "20260314"
TODAY = date(2026, 11, 11)


class FakeS3Client:
    """In-memory object store implementing the service-facing S3 interface."""

    def __init__(self, fail_upload: bool = False) -> None:
        self.bucket_name = "scout-sport"
        self.objects: dict[str, bytes] = {}
        self.metadata: dict[str, dict] = {}
        self.upload_calls: list[str] = []
        self.fail_upload = fail_upload

    def object_exists(self, key: str) -> bool:
        return key in self.objects

    def upload_file(self, local_path: Path, key: str, sha256: str) -> None:
        self.upload_calls.append(key)
        if self.fail_upload:
            raise RuntimeError("simulated S3 outage")
        self.objects[key] = local_path.read_bytes()
        self.metadata[key] = {"Metadata": {"sha256": sha256}}


def _complete_manifest(date_str: str = DATE) -> ScrapeManifest:
    return ScrapeManifest(date=date_str, total=2, done=["1"], skipped={"2": {"reason": "x"}})


def _incomplete_manifest(date_str: str = DATE) -> ScrapeManifest:
    return ScrapeManifest(date=date_str, total=2, done=["1"], failed=["2"])


def _write_date(historical: Path, manifest: ScrapeManifest, date_str: str = DATE) -> None:
    month = date_str[:6]
    listing = historical / "daily_listings" / month / date_str
    priority = historical / "link_priorities" / month / date_str
    manifests = historical / "manifests" / month / date_str
    matches = historical / "matches" / month / date_str
    for directory in (listing, priority, manifests, matches):
        directory.mkdir(parents=True)
    (listing / "match_links.json").write_text("[]", encoding="utf-8")
    (priority / "prioritized_match_links.json").write_text("{}", encoding="utf-8")
    (manifests / "manifest.json").write_text(json.dumps(manifest.to_dict()), encoding="utf-8")
    (matches / f"{date_str}_matches.tar").write_bytes(b"archive")
    (matches / f".{date_str}_matches.abc.tar.tmp").write_bytes(b"interrupted")


def _snapshot(root: Path) -> dict[str, bytes]:
    return {
        str(path.relative_to(root)): path.read_bytes() for path in root.rglob("*") if path.is_file()
    }


# --- Service ----------------------------------------------------------------


def test_complete_date_uploads_one_checksummed_archive(tmp_path: Path) -> None:
    historical = tmp_path / "historical"
    _write_date(historical, _complete_manifest())
    before = _snapshot(historical)
    client = FakeS3Client()

    result = OddspediaBronzeS3Service(historical, client, current_date=TODAY).upload_date(DATE)

    key = "scout-sport/bronze/oddspedia/202603/20260314.tar.gz"
    assert result.status == "uploaded"
    assert result.key == key
    assert client.upload_calls == [key]
    assert result.sha256 == hashlib.sha256(client.objects[key]).hexdigest()
    assert client.metadata[key] == {"Metadata": {"sha256": result.sha256}}
    with tarfile.open(fileobj=io.BytesIO(client.objects[key]), mode="r:gz") as archive:
        names = {member.name for member in archive.getmembers() if member.isfile()}
    assert names == {
        "daily_listings/202603/20260314/match_links.json",
        "link_priorities/202603/20260314/prioritized_match_links.json",
        "manifests/202603/20260314/manifest.json",
        "matches/202603/20260314/20260314_matches.tar",
    }
    assert _snapshot(historical) == before


def test_incomplete_date_is_rejected_without_upload(tmp_path: Path) -> None:
    historical = tmp_path / "historical"
    _write_date(historical, _incomplete_manifest())
    client = FakeS3Client()
    service = OddspediaBronzeS3Service(historical, client, current_date=TODAY)

    with pytest.raises(OddspediaS3UploadError, match="not complete"):
        service.upload_date(DATE)

    assert client.upload_calls == []


@pytest.mark.parametrize(
    "existing_key",
    [
        "scout-sport/bronze/oddspedia/202603/20260314.tar.gz",
        "bronze/oddspedia/202603/20260314.tar.gz",
    ],
)
def test_existing_object_is_skipped(tmp_path: Path, existing_key: str) -> None:
    historical = tmp_path / "historical"
    _write_date(historical, _complete_manifest())
    client = FakeS3Client()
    client.objects[existing_key] = b"already there"

    result = OddspediaBronzeS3Service(historical, client, current_date=TODAY).upload_date(DATE)

    assert result.status == "skipped"
    assert result.key == existing_key
    assert client.upload_calls == []
    assert client.objects[existing_key] == b"already there"


def test_live_date_is_never_uploaded(tmp_path: Path) -> None:
    today = TODAY.strftime("%Y%m%d")
    historical = tmp_path / "historical"
    _write_date(historical, _complete_manifest(today), date_str=today)
    client = FakeS3Client()
    service = OddspediaBronzeS3Service(historical, client, current_date=TODAY)

    with pytest.raises(OddspediaS3UploadError, match="Live date"):
        service.upload_date(today)

    assert client.upload_calls == []


def test_upload_error_keeps_local_artifacts(tmp_path: Path) -> None:
    historical = tmp_path / "historical"
    _write_date(historical, _complete_manifest())
    before = _snapshot(historical)
    client = FakeS3Client(fail_upload=True)

    with pytest.raises(RuntimeError, match="simulated S3 outage"):
        OddspediaBronzeS3Service(historical, client, current_date=TODAY).upload_date(DATE)

    assert _snapshot(historical) == before


# --- CLI wiring -------------------------------------------------------------


@pytest.fixture
def scrape_stubs(monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    """Replace browser, scrape, and filesystem side effects of one scrape date."""
    links_file = tmp_path / "match_links.json"
    links_file.write_text(json.dumps([{"id": "1"}, {"id": "2"}]), encoding="utf-8")
    stubs = Mock()
    stubs.manifest = _complete_manifest()
    stubs.phase2 = Mock(side_effect=lambda *args, **kwargs: stubs.manifest)
    stubs.compress = Mock()
    stubs.driver = Mock()

    monkeypatch.setattr(cli, "configure_logging", Mock())
    monkeypatch.setattr(cli, "get_run_logs_dir", lambda date, sport="football": str(tmp_path))
    monkeypatch.setattr(cli, "oddspedia_date_lock", lambda *args, **kwargs: nullcontext())
    monkeypatch.setattr(cli, "DriverManager", Mock(return_value=stubs.driver))
    monkeypatch.setattr(cli, "get_match_links_file", lambda date, sport="football": str(links_file))
    monkeypatch.setattr(cli, "_discovery_is_accepted", lambda date, sport="football": True)
    monkeypatch.setattr(cli, "_existing_inventory_matches_target", lambda *a, **k: True)
    monkeypatch.setattr(cli, "_needs_discovery_retry", lambda *a, **k: False)
    monkeypatch.setattr(cli, "phase1_collect", lambda *a, **k: [{"id": "1"}, {"id": "2"}])
    monkeypatch.setattr(cli, "prioritize_date", Mock())
    monkeypatch.setattr(
        cli, "_selected_priority_matches", lambda *a, **k: [{"id": "1"}, {"id": "2"}]
    )
    monkeypatch.setattr(cli, "phase2_scrape", stubs.phase2)
    monkeypatch.setattr(cli, "_compress_completed_date", stubs.compress)
    monkeypatch.setattr(cli, "load_manifest", lambda date, sport="football": None)
    return stubs


def _fake_uploader(monkeypatch: pytest.MonkeyPatch, client: FakeS3Client, tmp_path: Path):
    historical = tmp_path / "historical"
    _write_date(historical, _complete_manifest())
    uploader = OddspediaBronzeS3Service(historical, client, current_date=TODAY)
    factory = Mock(return_value=uploader)
    monkeypatch.setattr(cli, "_create_s3_uploader", factory)
    return factory, historical


def test_flag_off_never_reads_s3_settings_or_uploads(monkeypatch, scrape_stubs) -> None:
    factory = Mock(side_effect=AssertionError("S3 must not be configured without --upload-s3"))
    monkeypatch.setattr(cli, "_create_s3_uploader", factory)
    client_factory = Mock(side_effect=AssertionError("no S3 client without --upload-s3"))
    monkeypatch.setattr(cli, "create_s3_client", client_factory)

    cli.main(["scrape", "--date", DATE])

    scrape_stubs.phase2.assert_called_once()
    scrape_stubs.compress.assert_called_once()
    factory.assert_not_called()
    client_factory.assert_not_called()


def test_flag_on_uploads_a_complete_scraped_date(monkeypatch, scrape_stubs, tmp_path) -> None:
    client = FakeS3Client()
    factory, _historical = _fake_uploader(monkeypatch, client, tmp_path)

    cli.main(["scrape", "--date", DATE, "--upload-s3"])

    factory.assert_called_once_with()
    assert client.upload_calls == ["scout-sport/bronze/oddspedia/202603/20260314.tar.gz"]


def test_flag_on_uploads_after_the_full_run(monkeypatch, scrape_stubs, tmp_path) -> None:
    client = FakeS3Client()
    _fake_uploader(monkeypatch, client, tmp_path)

    cli.main(["run", "--date", DATE, "--silver-reference-window-ready", "--upload-s3"])

    assert client.upload_calls == ["scout-sport/bronze/oddspedia/202603/20260314.tar.gz"]


def test_flag_on_skips_an_incomplete_date(monkeypatch, scrape_stubs, tmp_path) -> None:
    scrape_stubs.manifest = _incomplete_manifest()
    client = FakeS3Client()
    _fake_uploader(monkeypatch, client, tmp_path)

    cli.main(["scrape", "--date", DATE, "--upload-s3"])

    assert client.upload_calls == []


def test_flag_on_skips_an_existing_object(monkeypatch, scrape_stubs, tmp_path) -> None:
    client = FakeS3Client()
    client.objects["scout-sport/bronze/oddspedia/202603/20260314.tar.gz"] = b"already there"
    _fake_uploader(monkeypatch, client, tmp_path)

    cli.main(["scrape", "--date", DATE, "--upload-s3"])

    assert client.upload_calls == []


def test_upload_error_exits_non_zero_and_keeps_scraped_data(
    monkeypatch, scrape_stubs, tmp_path
) -> None:
    client = FakeS3Client(fail_upload=True)
    _factory, historical = _fake_uploader(monkeypatch, client, tmp_path)
    before = _snapshot(historical)

    with pytest.raises(SystemExit) as exit_info:
        cli.main(["scrape", "--date", DATE, "--upload-s3"])

    assert exit_info.value.code == 1
    assert client.upload_calls == ["scout-sport/bronze/oddspedia/202603/20260314.tar.gz"]
    scrape_stubs.compress.assert_called_once()
    assert _snapshot(historical) == before


def test_missing_credentials_fail_fast_before_scraping(monkeypatch, scrape_stubs) -> None:
    for name in ("S3_ENDPOINT", "S3_ACCESS_KEY", "S3_SECRET_KEY", "S3_BUCKET"):
        monkeypatch.setenv(name, "")

    with pytest.raises(SystemExit) as exit_info:
        cli.main(["scrape", "--date", DATE, "--upload-s3"])

    assert exit_info.value.code == 1
    scrape_stubs.phase2.assert_not_called()
    cli.DriverManager.assert_not_called()


@pytest.mark.parametrize("command", ["discover", "prioritize"])
def test_flag_is_rejected_outside_scrape_and_run(command: str) -> None:
    with pytest.raises(SystemExit) as exit_info:
        cli.main([command, "--date", DATE, "--silver-reference-window-ready", "--upload-s3"])

    assert exit_info.value.code == 2
