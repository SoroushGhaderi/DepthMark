"""Filesystem storage helpers for Oddspedia Bronze payloads.

Historical match payloads use the same local compression protocol as FotMob:
individual JSON payloads are gzip-compressed and stored in one uncompressed
TAR archive for the date.  The source-owned file names remain Oddspedia's
existing ``{match_id}.json`` contract.
"""

import gzip
import io
import json
import os
import shutil
import tarfile
import tempfile
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from src.common.logging import get_logger
from src.oddspedia.scraping.config import (
    get_match_file,
    get_matches_dir,
    normalize_date,
    normalize_sport,
)

logger = get_logger(__name__)


def _storage_date(date_str: str) -> str:
    """Accept the canonical date plus the legacy dashed internal form."""
    value = str(date_str).strip()
    if len(value) == 10 and value[4] == "-" and value[7] == "-":
        value = value.replace("-", "")
    return normalize_date(value)


@dataclass(frozen=True)
class StoredMatchPayload:
    """One payload and the artifact from which it was read."""

    match_id: str
    payload: dict
    source_file: str
    size_bytes: int


def get_match_archive_file(date_str: str, sport: str = "football") -> str:
    """Return the canonical local archive path for one Oddspedia date."""
    date_id = _storage_date(date_str)
    normalize_sport(sport)
    return os.path.join(get_matches_dir(date_id, sport=sport), f"{date_id}_matches.tar")


def read_match_payload(
    date_str: str, match_id: str, sport: str = "football"
) -> StoredMatchPayload | None:
    """Read one payload from plain JSON, then from the date archive.

    Plain JSON takes precedence so a newly re-scraped payload can replace an
    archived version before the next date compression pass.
    """
    date_id = _storage_date(date_str)
    match_id = str(match_id)
    plain_path = Path(get_match_file(date_id, match_id, sport=sport))
    if plain_path.exists():
        try:
            with plain_path.open(encoding="utf-8") as source:
                payload = json.load(source)
            if isinstance(payload, dict):
                return StoredMatchPayload(
                    match_id, payload, str(plain_path), plain_path.stat().st_size
                )
        except (OSError, json.JSONDecodeError) as exc:
            logger.warning("oddspedia_payload_read_failed", path=str(plain_path), error=str(exc))
            return None

    archive_path = Path(get_match_archive_file(date_id, sport=sport))
    if not archive_path.exists():
        return None

    member_names = (f"{match_id}.json.gz", f"match_{match_id}.json.gz")
    try:
        with tarfile.open(archive_path, "r") as archive:
            member = next(
                (archive.getmember(name) for name in member_names if name in archive.getnames()),
                None,
            )
            if member is None:
                return None
            extracted = archive.extractfile(member)
            if extracted is None:
                return None
            with gzip.open(io.BytesIO(extracted.read()), "rt", encoding="utf-8") as source:
                payload = json.load(source)
            if not isinstance(payload, dict):
                return None
            return StoredMatchPayload(
                match_id,
                payload,
                f"{archive_path}#{member.name}",
                len(json.dumps(payload, ensure_ascii=False).encode("utf-8")),
            )
    except (OSError, tarfile.TarError, gzip.BadGzipFile, json.JSONDecodeError) as exc:
        logger.warning(
            "oddspedia_archive_payload_read_failed", path=str(archive_path), error=str(exc)
        )
        return None


def iter_match_payloads(date_str: str, sport: str = "football") -> Iterator[StoredMatchPayload]:
    """Yield every stored payload once, preferring new plain JSON over archives."""
    date_id = _storage_date(date_str)
    matches_dir = Path(get_matches_dir(date_id, sport=sport))
    payloads: dict[str, StoredMatchPayload] = {}

    archive_path = Path(get_match_archive_file(date_id, sport=sport))
    if archive_path.exists():
        try:
            with tarfile.open(archive_path, "r") as archive:
                for member in archive.getmembers():
                    if not member.isfile() or not member.name.endswith(".json.gz"):
                        continue
                    filename = Path(member.name).name
                    match_id = filename.removesuffix(".json.gz").removeprefix("match_")
                    extracted = archive.extractfile(member)
                    if extracted is None:
                        continue
                    with gzip.open(io.BytesIO(extracted.read()), "rt", encoding="utf-8") as source:
                        payload = json.load(source)
                    if isinstance(payload, dict):
                        payloads[match_id] = StoredMatchPayload(
                            match_id,
                            payload,
                            f"{archive_path}#{member.name}",
                            len(json.dumps(payload, ensure_ascii=False).encode("utf-8")),
                        )
        except (OSError, tarfile.TarError, gzip.BadGzipFile, json.JSONDecodeError) as exc:
            logger.warning(
                "oddspedia_archive_listing_failed", path=str(archive_path), error=str(exc)
            )

    if matches_dir.exists():
        for path in sorted(matches_dir.glob("*.json")):
            match_id = path.stem.removeprefix("match_")
            stored = read_match_payload(date_id, match_id, sport=sport)
            if stored is not None:
                payloads[match_id] = stored

    yield from (payloads[match_id] for match_id in sorted(payloads))


def compress_date_files(date_str: str, force: bool = False, sport: str = "football") -> dict:
    """Compress one complete Oddspedia date using the FotMob local protocol.

    The archive is rebuilt in a temporary file and replaced only after every
    member can be read and decompressed. Existing archive members are retained
    when a later priority tier adds new plain JSON payloads.
    """
    date_id = _storage_date(date_str)
    sport = normalize_sport(sport)
    date_dir = Path(get_matches_dir(date_id, sport=sport))
    archive_path = Path(get_match_archive_file(date_id, sport=sport))

    json_files = sorted(date_dir.glob("*.json")) if date_dir.exists() else []
    gz_files = sorted(date_dir.glob("*.json.gz")) if date_dir.exists() else []
    if archive_path.exists() and not force and not json_files and not gz_files:
        return {
            "compressed": 0,
            "size_before_mb": 0,
            "size_after_mb": round(archive_path.stat().st_size / (1024 * 1024), 2),
            "saved_mb": 0,
            "saved_pct": 0,
            "archive_file": str(archive_path),
            "status": "already_compressed",
        }
    if not date_dir.exists():
        return {
            "compressed": 0,
            "size_before_mb": 0,
            "size_after_mb": 0,
            "archive_file": None,
            "status": "no_directory",
        }

    if not archive_path.exists() and not json_files and not gz_files:
        return {
            "compressed": 0,
            "size_before_mb": 0,
            "size_after_mb": 0,
            "archive_file": None,
            "status": "no_files",
        }

    temp_gz_paths = []
    temp_archive_path = None
    try:
        replacement_names = {f"{path.name}.gz" for path in json_files}
        total_before = sum(path.stat().st_size for path in json_files + gz_files)
        for json_path in json_files:
            fd, temp_name = tempfile.mkstemp(
                dir=date_dir, prefix=f".{json_path.name}.", suffix=".gz.tmp"
            )
            os.close(fd)
            temp_gz = Path(temp_name)
            with (
                json_path.open("rb") as source,
                gzip.open(temp_gz, "wb", compresslevel=6) as target,
            ):
                shutil.copyfileobj(source, target)
            temp_gz_paths.append((temp_gz, f"{json_path.name}.gz"))

        fd, temp_name = tempfile.mkstemp(
            dir=date_dir, prefix=f".{date_id}_matches.", suffix=".tar.tmp"
        )
        os.close(fd)
        temp_archive_path = Path(temp_name)
        with tarfile.open(temp_archive_path, "w") as output:
            if archive_path.exists():
                with tarfile.open(archive_path, "r") as existing:
                    for member in existing.getmembers():
                        if member.name in replacement_names or not member.isfile():
                            continue
                        extracted = existing.extractfile(member)
                        if extracted is not None:
                            output.addfile(member, extracted)
            for gz_path, member_name in ((path, name) for path, name in temp_gz_paths):
                output.add(gz_path, arcname=member_name)
            for gz_path in gz_files:
                if gz_path.name not in replacement_names:
                    output.add(gz_path, arcname=gz_path.name)

        with tarfile.open(temp_archive_path, "r") as verified:
            members = [member for member in verified.getmembers() if member.isfile()]
            if not members or any(not member.name.endswith(".json.gz") for member in members):
                raise ValueError("archive contains no valid Oddspedia JSON.GZ members")
            for member in members:
                extracted = verified.extractfile(member)
                if extracted is None:
                    raise ValueError(f"archive member cannot be read: {member.name}")
                with gzip.open(io.BytesIO(extracted.read()), "rt", encoding="utf-8") as source:
                    json.load(source)

        os.replace(temp_archive_path, archive_path)
        temp_archive_path = None
        for json_path in json_files:
            json_path.unlink()
        for gz_path in gz_files:
            gz_path.unlink()

        total_after = archive_path.stat().st_size
        size_before_mb = total_before / (1024 * 1024)
        size_after_mb = total_after / (1024 * 1024)
        return {
            "compressed": len(json_files) + len(gz_files),
            "size_before_mb": round(size_before_mb, 2),
            "size_after_mb": round(size_after_mb, 2),
            "saved_mb": round(size_before_mb - size_after_mb, 2),
            "saved_pct": round(
                ((size_before_mb - size_after_mb) / max(size_before_mb, 1e-12)) * 100, 1
            ),
            "archive_file": str(archive_path),
            "status": "success",
        }
    except Exception as exc:
        logger.exception("oddspedia_date_compression_failed", date=date_id, error=str(exc))
        return {
            "compressed": 0,
            "size_before_mb": 0,
            "size_after_mb": 0,
            "archive_file": None,
            "status": "error",
            "error": str(exc),
        }
    finally:
        for temp_gz, _ in temp_gz_paths:
            temp_gz.unlink(missing_ok=True)
        if temp_archive_path is not None:
            temp_archive_path.unlink(missing_ok=True)
