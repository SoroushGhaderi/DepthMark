"""Opt-in S3 upload of completed Oddspedia Historical dates (ADR 0035).

This mirrors the FotMob Bronze S3 Sync contract without sharing its source
rules: one checksummed ``tar.gz`` per date, stored at
``{S3_BUCKET}/bronze/oddspedia/YYYYMM/YYYYMMDD.tar.gz`` when a bucket name is
known (otherwise ``bronze/oddspedia/YYYYMM/YYYYMMDD.tar.gz``). An existing
object under either key is never overwritten. The service only reads local
artifacts: it builds the transfer archive in a temporary directory and never
changes or deletes the scraped files.
"""

import hashlib
import re
import tarfile
import tempfile
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from src.integrations.s3 import S3Client
from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.paths import get_storage_aspect
from src.oddspedia.scraping.utils import load_json

DATE_PATTERN = re.compile(r"^\d{8}$")
CANONICAL_PREFIX = "bronze/oddspedia/"
# Historical artifact directories carried by one date archive. Locks and run
# logs are operational state, not source artifacts, and are never uploaded.
ARTIFACT_DIRECTORIES = ("daily_listings", "link_priorities", "manifests", "matches")


class OddspediaS3UploadError(RuntimeError):
    """Raised when one Oddspedia date cannot be safely uploaded."""


@dataclass(frozen=True)
class OddspediaS3UploadResult:
    """Deterministic outcome for one date upload."""

    date: str
    status: str
    key: str
    message: str
    size_bytes: int = 0
    sha256: str = ""


class OddspediaBronzeS3Service:
    """Upload completed Oddspedia Historical dates to S3."""

    def __init__(
        self,
        historical_path: Path,
        s3_client: S3Client,
        current_date: date | None = None,
    ) -> None:
        self.historical_path = historical_path
        self.s3_client = s3_client
        self.current_date = current_date

    @staticmethod
    def object_key(date_str: str) -> str:
        """Return the canonical object key for one Oddspedia date archive."""
        OddspediaBronzeS3Service._validate_date(date_str)
        return f"{CANONICAL_PREFIX}{date_str[:6]}/{date_str}.tar.gz"

    def upload_date(self, date_str: str) -> OddspediaS3UploadResult:
        """Validate, archive, and upload one complete Historical date.

        Returns a ``skipped`` result when the object already exists.

        Raises:
            OddspediaS3UploadError: When the date is Live, future, or not
                terminally complete, or its artifacts are missing.
        """
        keys = self._remote_object_keys(date_str)
        self._validate_upload_source(date_str)

        existing_key = next((key for key in keys if self.s3_client.object_exists(key)), "")
        if existing_key:
            return OddspediaS3UploadResult(
                date_str, "skipped", existing_key, "remote object already exists"
            )

        with tempfile.TemporaryDirectory(prefix="depthmark-oddspedia-s3-upload-") as temp_dir:
            archive_path = Path(temp_dir) / f"{date_str}.tar.gz"
            self._create_archive(date_str, archive_path)
            checksum = _sha256(archive_path)
            self.s3_client.upload_file(archive_path, keys[0], checksum)
            size_bytes = archive_path.stat().st_size

        return OddspediaS3UploadResult(
            date_str,
            "uploaded",
            keys[0],
            "uploaded completed Oddspedia date archive",
            size_bytes=size_bytes,
            sha256=checksum,
        )

    def _remote_object_keys(self, date_str: str) -> tuple[str, ...]:
        """Return the preferred key first, then the bucket-less compatible key."""
        canonical_key = self.object_key(date_str)
        bucket_name = getattr(self.s3_client, "bucket_name", "")
        if not bucket_name:
            return (canonical_key,)
        return (f"{bucket_name}/{canonical_key}", canonical_key)

    def _artifact_dir(self, artifact: str, date_str: str) -> Path:
        return self.historical_path / artifact / date_str[:6] / date_str

    def _validate_upload_source(self, date_str: str) -> None:
        try:
            aspect = get_storage_aspect(date_str, current_date=self.current_date)
        except ValueError as exc:
            raise OddspediaS3UploadError(str(exc)) from exc
        if aspect != "historical":
            raise OddspediaS3UploadError(f"Live date {date_str} is never uploaded")

        manifest_path = self._artifact_dir("manifests", date_str) / "manifest.json"
        if not manifest_path.is_file():
            raise OddspediaS3UploadError(f"scrape manifest not found: {manifest_path}")
        try:
            manifest = ScrapeManifest.from_dict(load_json(str(manifest_path)))
        except (OSError, TypeError, ValueError) as exc:
            raise OddspediaS3UploadError(
                f"could not read scrape manifest {manifest_path}: {exc}"
            ) from exc
        if not manifest.is_terminally_complete:
            raise OddspediaS3UploadError(
                f"Oddspedia date {date_str} is not complete: total={manifest.total} "
                f"done={manifest.completed_count} skipped={manifest.skipped_count} "
                f"failed={manifest.failed_count} incomplete={manifest.incomplete_count} "
                f"in_progress={len(manifest.in_progress)}"
            )

        matches_path = self._artifact_dir("matches", date_str)
        if not matches_path.is_dir():
            raise OddspediaS3UploadError(f"match payload directory not found: {matches_path}")

    def _create_archive(self, date_str: str, archive_path: Path) -> None:
        with tarfile.open(archive_path, "w:gz") as archive:
            for artifact in ARTIFACT_DIRECTORIES:
                source = self._artifact_dir(artifact, date_str)
                if source.exists():
                    archive.add(
                        source,
                        arcname=f"{artifact}/{date_str[:6]}/{date_str}",
                        filter=_exclude_temporary_files,
                    )

    @staticmethod
    def _validate_date(date_str: str) -> None:
        if not DATE_PATTERN.fullmatch(date_str):
            raise OddspediaS3UploadError(f"invalid date {date_str!r}; expected YYYYMMDD")
        try:
            datetime.strptime(date_str, "%Y%m%d")
        except ValueError as exc:
            raise OddspediaS3UploadError(f"invalid calendar date {date_str!r}") from exc


def _exclude_temporary_files(member: tarfile.TarInfo) -> tarfile.TarInfo | None:
    """Leave out interrupted atomic-write temporaries such as ``.x.tar.tmp``."""
    name = Path(member.name).name
    if name.startswith(".") and name.endswith(".tmp"):
        return None
    return member


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file_obj:
        for chunk in iter(lambda: file_obj.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
