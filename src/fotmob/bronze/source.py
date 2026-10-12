"""Stored FotMob Historical payloads, addressed by Source Date.

The Source Date is the name of the folder a payload is stored under,
``matches/YYYYMM/YYYYMMDD/``; it is never read from the payload. Loading and
removal both read a date's payloads through this module, so removing a Source
Date deletes exactly the matches loading it inserts (ADR 0032).
"""

import gzip
import io
import json
import tarfile
from pathlib import Path
from typing import Any, Dict, Iterator, Tuple

from src.fotmob.bronze.errors import BronzeSourceError, BronzeSourceMissingError


def get_matches_dir(historical_root: Path, date_str: str) -> Path:
    """Return the canonical ``matches/YYYYMM/YYYYMMDD`` directory for a Source Date."""
    return historical_root / "matches" / date_str[:6] / date_str


def iter_match_payloads(matches_dir: Path, date_str: str) -> Iterator[Tuple[str, Dict[str, Any]]]:
    """Yield ``(source, payload)`` for every stored match of a Source Date.

    The date archive ``<date>_matches.tar`` is authoritative when it exists;
    otherwise loose ``match_*.json.gz`` files are read, then ``match_*.json``.
    Raises :class:`BronzeSourceError` naming the artifact that cannot be read.
    """
    archive_path = matches_dir / f"{date_str}_matches.tar"
    if archive_path.exists():
        yield from _iter_archive_payloads(archive_path)
        return

    loose_files = sorted(matches_dir.glob("match_*.json.gz")) or sorted(
        matches_dir.glob("match_*.json")
    )
    for file_path in loose_files:
        try:
            if file_path.name.endswith(".gz"):
                with gzip.open(file_path, "rt", encoding="utf-8") as handle:
                    file_data = json.load(handle)
            else:
                with open(file_path, "r", encoding="utf-8") as handle:
                    file_data = json.load(handle)
        except (OSError, EOFError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise BronzeSourceError(f"Cannot read FotMob payload {file_path}: {error}") from error
        yield str(file_path), _payload_from_file(file_data, str(file_path))


def _iter_archive_payloads(archive_path: Path) -> Iterator[Tuple[str, Dict[str, Any]]]:
    try:
        with tarfile.open(archive_path, "r") as archive:
            for member in archive.getmembers():
                if not member.isfile() or not member.name.endswith(".json.gz"):
                    continue
                source = f"{archive_path}:{member.name}"
                handle = archive.extractfile(member)
                if handle is None:
                    raise BronzeSourceError(f"Cannot read FotMob payload {source}")
                try:
                    with gzip.open(io.BytesIO(handle.read()), "rt", encoding="utf-8") as payload:
                        file_data = json.load(payload)
                except (OSError, EOFError, UnicodeDecodeError, json.JSONDecodeError) as error:
                    raise BronzeSourceError(
                        f"Cannot read FotMob payload {source}: {error}"
                    ) from error
                yield source, _payload_from_file(file_data, source)
    except tarfile.TarError as error:
        raise BronzeSourceError(f"Cannot read FotMob archive {archive_path}: {error}") from error


def _payload_from_file(file_data: Any, source: str) -> Dict[str, Any]:
    """Unwrap the stored ``{"data": payload}`` envelope used by Bronze storage."""
    payload = file_data.get("data", file_data) if isinstance(file_data, dict) else None
    if not isinstance(payload, dict):
        raise BronzeSourceError(f"FotMob payload {source} is not a JSON object")
    return payload


def source_date_match_ids(historical_root: Path, date_str: str) -> Tuple[int, ...]:
    """Return the match ids stored under a Source Date, from each payload's ``general.matchId``.

    Raises :class:`BronzeSourceMissingError` when the date has no stored payloads,
    because its Bronze rows can then no longer be identified by Source Date.
    """
    matches_dir = get_matches_dir(historical_root, date_str)
    match_ids = set()
    if matches_dir.is_dir():
        for source, payload in iter_match_payloads(matches_dir, date_str):
            match_id = (payload.get("general") or {}).get("matchId")
            try:
                match_ids.add(int(match_id))
            except (TypeError, ValueError) as error:
                raise BronzeSourceError(
                    f"FotMob payload {source} has no integer general.matchId"
                ) from error
    if not match_ids:
        raise BronzeSourceMissingError(
            f"No stored FotMob payloads for Source Date {date_str} under {matches_dir}; "
            "its Bronze rows cannot be identified (ADR 0032)"
        )
    return tuple(sorted(match_ids))
