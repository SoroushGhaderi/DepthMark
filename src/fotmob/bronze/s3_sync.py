"""Application service for independent FotMob Bronze uploads and downloads."""

import hashlib
import json
import re
import shutil
import tarfile
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set, Tuple

from src.common.logging import get_logger
from src.integrations.s3 import S3Client

logger = get_logger(__name__)

DATE_PATTERN = re.compile(r"^\d{8}$")
MATCH_FILE_PATTERN = re.compile(r"^match_(\d+)\.json(?:\.gz)?$")
REMOTE_KEY_PATTERN = re.compile(r"^bronze/fotmob/\d{6}/(\d{8})\.tar\.gz$")


class BronzeS3SyncError(RuntimeError):
    """Raised when one date cannot be safely synchronized."""


@dataclass(frozen=True)
class BronzeS3SyncResult:
    """Deterministic outcome for one date-scoped sync operation."""

    date: str
    action: str
    status: str
    key: str
    message: str
    size_bytes: int = 0
    sha256: str = ""


class BronzeS3Service:
    """Synchronize date-scoped FotMob Bronze artifacts with S3."""

    def __init__(self, bronze_path: Path, s3_client: S3Client) -> None:
        self.bronze_path = bronze_path
        self.s3_client = s3_client

    @staticmethod
    def object_key(date_str: str) -> str:
        """Return the stable object key for a Bronze date archive."""
        BronzeS3Service._validate_date(date_str)
        return f"bronze/fotmob/{date_str[:6]}/{date_str}.tar.gz"

    def list_local_dates(self) -> List[str]:
        """List dates found in either canonical local Bronze directory."""
        dates: Set[str] = set()
        for parent_name in ("matches", "daily_listings"):
            parent = self.bronze_path / parent_name
            if not parent.exists():
                continue
            dates.update(
                child.name
                for child in parent.glob("??????/????????")
                if child.is_dir() and DATE_PATTERN.fullmatch(child.name)
            )
        return sorted(dates)

    def list_remote_dates(self) -> List[str]:
        """List dates represented by compatible remote object keys."""
        dates = []
        for prefix in self._remote_object_prefixes():
            for key in self.s3_client.list_keys(prefix):
                match = REMOTE_KEY_PATTERN.fullmatch(self._canonical_remote_key(key))
                if match:
                    dates.append(match.group(1))
        return sorted(set(dates))

    def upload_date(
        self,
        date_str: str,
        force: bool = False,
        allow_incomplete: bool = False,
        dry_run: bool = False,
    ) -> BronzeS3SyncResult:
        """Validate, archive, and upload one local Bronze date."""
        key = self._preferred_remote_object_key(date_str)
        self._validate_upload_source(date_str, allow_incomplete=allow_incomplete)

        existing_key = self._find_remote_object_key(date_str)
        if existing_key and not force:
            return BronzeS3SyncResult(
                date_str, "upload", "skipped", existing_key, "remote object already exists"
            )
        if dry_run:
            verb = "overwrite" if force else "upload"
            return BronzeS3SyncResult(
                date_str, "upload", "planned", key, f"would {verb} validated Bronze artifacts"
            )

        with tempfile.TemporaryDirectory(prefix="depthmark-s3-upload-") as temp_dir:
            archive_path = Path(temp_dir) / f"{date_str}.tar.gz"
            self._create_archive(date_str, archive_path)
            checksum = self._sha256(archive_path)
            self.s3_client.upload_file(archive_path, key, checksum)
            size_bytes = archive_path.stat().st_size

        return BronzeS3SyncResult(
            date_str,
            "upload",
            "uploaded",
            key,
            "uploaded validated Bronze archive",
            size_bytes=size_bytes,
            sha256=checksum,
        )

    def download_date(
        self, date_str: str, force: bool = False, dry_run: bool = False
    ) -> BronzeS3SyncResult:
        """Download, validate, and restore one Bronze date."""
        key = self._find_remote_object_key(date_str)
        if not key:
            raise BronzeS3SyncError(
                "remote object does not exist: " + ", ".join(self._remote_object_keys(date_str))
            )

        local_targets = self._local_targets(date_str)
        existing_targets = [path for path in local_targets if path.exists()]
        if existing_targets and not force:
            paths = ", ".join(str(path) for path in existing_targets)
            raise BronzeS3SyncError(
                f"local Bronze data already exists ({paths}); use --force to replace it"
            )
        if dry_run:
            verb = "replace" if existing_targets else "restore"
            return BronzeS3SyncResult(
                date_str, "download", "planned", key, f"would {verb} local Bronze artifacts"
            )

        metadata = self.s3_client.object_metadata(key)
        expected_checksum = metadata.get("Metadata", {}).get("sha256", "")

        with tempfile.TemporaryDirectory(prefix="depthmark-s3-download-") as temp_dir:
            temp_path = Path(temp_dir)
            archive_path = temp_path / f"{date_str}.tar.gz"
            extract_path = temp_path / "extracted"
            extract_path.mkdir()
            self.s3_client.download_file(key, archive_path)
            checksum = self._sha256(archive_path)
            if expected_checksum and checksum != expected_checksum:
                raise BronzeS3SyncError(
                    f"checksum mismatch for {key}: expected {expected_checksum}, got {checksum}"
                )
            self._safe_extract(archive_path, extract_path)
            staged_targets = self._resolve_archive_layout(date_str, extract_path)
            self._install_targets(date_str, staged_targets, force=force)
            size_bytes = archive_path.stat().st_size

        return BronzeS3SyncResult(
            date_str,
            "download",
            "downloaded",
            key,
            "downloaded and restored Bronze artifacts",
            size_bytes=size_bytes,
            sha256=checksum,
        )

    def _remote_object_prefixes(self) -> Tuple[str, ...]:
        """Return canonical and legacy archive prefixes to discover."""
        canonical_prefix = "bronze/fotmob/"
        bucket_name = getattr(self.s3_client, "bucket_name", "")
        if not bucket_name:
            return (canonical_prefix,)
        return (canonical_prefix, f"{bucket_name}/{canonical_prefix}")

    def _remote_object_keys(self, date_str: str) -> Tuple[str, ...]:
        """Return preferred and compatibility key candidates for one archive."""
        canonical_key = self.object_key(date_str)
        bucket_name = getattr(self.s3_client, "bucket_name", "")
        if not bucket_name:
            return (canonical_key,)
        return (f"{bucket_name}/{canonical_key}", canonical_key)

    def _preferred_remote_object_key(self, date_str: str) -> str:
        """Return the bucket-prefixed key used for new archives when available."""
        return self._remote_object_keys(date_str)[0]

    def _find_remote_object_key(self, date_str: str) -> str:
        """Find the first available canonical or legacy archive key."""
        for key in self._remote_object_keys(date_str):
            if self.s3_client.object_exists(key):
                return key
        return ""

    def _canonical_remote_key(self, key: str) -> str:
        """Strip the supported bucket-named legacy prefix from an object key."""
        bucket_name = getattr(self.s3_client, "bucket_name", "")
        legacy_prefix = f"{bucket_name}/" if bucket_name else ""
        if legacy_prefix and key.startswith(legacy_prefix):
            return key[len(legacy_prefix) :]
        return key

    def _validate_upload_source(self, date_str: str, allow_incomplete: bool) -> None:
        matches_path, listing_directory = self._local_targets(date_str)
        listing_path = listing_directory / "matches.json"
        if not matches_path.exists() and not listing_directory.exists():
            raise BronzeS3SyncError(f"no local Bronze artifacts found for {date_str}")
        if allow_incomplete:
            return
        if not listing_path.exists():
            raise BronzeS3SyncError(
                f"daily listing is required to prove completeness: {listing_path}"
            )

        try:
            listing = json.loads(listing_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise BronzeS3SyncError(f"could not read daily listing {listing_path}: {exc}") from exc

        expected = {str(match_id) for match_id in listing.get("match_ids", [])}
        unavailable = {
            str(match_id)
            for match_id in listing.get("storage", {}).get("unavailable_match_ids", [])
        }
        stored = self._stored_match_ids(matches_path)
        missing = sorted(expected - unavailable - stored)
        if missing:
            preview = ", ".join(missing[:10])
            suffix = "..." if len(missing) > 10 else ""
            raise BronzeS3SyncError(
                f"Bronze date {date_str} is incomplete; {len(missing)} match files missing: "
                f"{preview}{suffix}"
            )

    def _create_archive(self, date_str: str, archive_path: Path) -> None:
        matches_path, listing_path = self._local_targets(date_str)
        with tarfile.open(archive_path, "w:gz") as archive:
            if matches_path.exists():
                archive.add(matches_path, arcname=f"matches/{date_str[:6]}/{date_str}")
            if listing_path.exists():
                archive.add(listing_path, arcname=f"daily_listings/{date_str[:6]}/{date_str}")

    def _local_targets(self, date_str: str) -> Tuple[Path, Path]:
        return (
            self.bronze_path / "matches" / date_str[:6] / date_str,
            self.bronze_path / "daily_listings" / date_str[:6] / date_str,
        )

    @staticmethod
    def _stored_match_ids(matches_path: Path) -> Set[str]:
        stored: Set[str] = set()
        if not matches_path.exists():
            return stored
        for path in matches_path.iterdir():
            file_match = MATCH_FILE_PATTERN.fullmatch(path.name)
            if file_match:
                stored.add(file_match.group(1))
                continue
            if not path.name.endswith("_matches.tar"):
                continue
            try:
                with tarfile.open(path, "r") as archive:
                    for member in archive.getmembers():
                        member_match = MATCH_FILE_PATTERN.fullmatch(Path(member.name).name)
                        if member_match:
                            stored.add(member_match.group(1))
            except (OSError, tarfile.TarError) as exc:
                raise BronzeS3SyncError(f"could not read local archive {path}: {exc}") from exc
        return stored

    @staticmethod
    def _safe_extract(archive_path: Path, destination: Path) -> None:
        try:
            with tarfile.open(archive_path, "r:gz") as archive:
                destination_resolved = destination.resolve()
                for member in archive.getmembers():
                    if member.issym() or member.islnk():
                        raise BronzeS3SyncError(f"archive contains unsupported link: {member.name}")
                    if not member.isfile() and not member.isdir():
                        raise BronzeS3SyncError(
                            f"archive contains unsupported entry type: {member.name}"
                        )
                    target = (destination / member.name).resolve()
                    try:
                        target.relative_to(destination_resolved)
                    except ValueError as exc:
                        raise BronzeS3SyncError(
                            f"archive contains unsafe path: {member.name}"
                        ) from exc
                archive.extractall(destination)
        except (OSError, tarfile.TarError) as exc:
            raise BronzeS3SyncError(f"invalid archive {archive_path}: {exc}") from exc

    @staticmethod
    def _resolve_archive_layout(date_str: str, extract_path: Path) -> Dict[str, Path]:
        new_matches = extract_path / "matches" / date_str[:6] / date_str
        new_listing = extract_path / "daily_listings" / date_str[:6] / date_str
        if new_matches.exists() or new_listing.exists():
            if not (new_listing / "matches.json").is_file():
                raise BronzeS3SyncError("new-format archive is missing its daily listing")
            return {"matches": new_matches, "daily_listings": new_listing}

        previous_matches = extract_path / "matches" / date_str
        previous_listing = extract_path / "daily_listings" / date_str
        if previous_matches.exists() or previous_listing.exists():
            if not (previous_listing / "matches.json").is_file():
                raise BronzeS3SyncError("previous-format archive is missing its daily listing")
            return {"matches": previous_matches, "daily_listings": previous_listing}

        legacy_matches = extract_path / date_str
        if legacy_matches.exists() and legacy_matches.is_dir():
            return {"matches": legacy_matches}
        raise BronzeS3SyncError(
            "archive does not contain a supported Bronze layout "
            f"(expected matches/{date_str[:6]}/{date_str}, matches/{date_str}, or {date_str})"
        )

    def _install_targets(self, date_str: str, staged_targets: Dict[str, Path], force: bool) -> None:
        self.bronze_path.mkdir(parents=True, exist_ok=True)
        backup_root = Path(tempfile.mkdtemp(prefix="depthmark-s3-backup-", dir=self.bronze_path))
        installed: List[Path] = []
        backups: List[Tuple[Path, Path]] = []
        try:
            if force:
                for parent_name in ("matches", "daily_listings"):
                    target = self.bronze_path / parent_name / date_str[:6] / date_str
                    if not target.exists():
                        continue
                    backup = backup_root / parent_name / date_str[:6] / date_str
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    target.replace(backup)
                    backups.append((backup, target))
            for parent_name, staged_path in staged_targets.items():
                if not staged_path.exists():
                    continue
                target = self.bronze_path / parent_name / date_str[:6] / date_str
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    raise BronzeS3SyncError(f"local target already exists: {target}")
                shutil.move(str(staged_path), str(target))
                installed.append(target)
        except Exception:
            for target in reversed(installed):
                if target.exists():
                    shutil.rmtree(target)
            for backup, target in reversed(backups):
                target.parent.mkdir(parents=True, exist_ok=True)
                backup.replace(target)
            raise
        finally:
            shutil.rmtree(backup_root, ignore_errors=True)

    @staticmethod
    def _sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as file_obj:
            for chunk in iter(lambda: file_obj.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    @staticmethod
    def _validate_date(date_str: str) -> None:
        if not DATE_PATTERN.fullmatch(date_str):
            raise BronzeS3SyncError(f"invalid date {date_str!r}; expected YYYYMMDD")
        try:
            datetime.strptime(date_str, "%Y%m%d")
        except ValueError as exc:
            raise BronzeS3SyncError(f"invalid calendar date {date_str!r}") from exc
