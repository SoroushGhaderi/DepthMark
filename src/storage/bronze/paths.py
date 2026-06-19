"""Canonical filesystem paths for FotMob Bronze storage aspects."""

from pathlib import Path
from typing import List, Union

PathLike = Union[str, Path]


def get_fotmob_historical_path(bronze_root: PathLike) -> Path:
    """Return the canonical Historical Bronze path beneath ``bronze_root``."""
    return Path(bronze_root) / "historical"


def get_fotmob_live_path(bronze_root: PathLike) -> Path:
    """Return the canonical Live Bronze path beneath ``bronze_root``."""
    return Path(bronze_root) / "live"


def migrate_legacy_fotmob_storage(bronze_root: PathLike, dry_run: bool = True) -> List[str]:
    """Move legacy FotMob directories into Historical storage without merging.

    Both moves are validated before any filesystem mutation. Existing populated
    destinations are accepted only when their corresponding legacy source is
    already absent.
    """
    root = Path(bronze_root)
    historical_path = get_fotmob_historical_path(root)
    live_path = get_fotmob_live_path(root)
    operations = []

    for directory_name in ("matches", "daily_listings"):
        source = root / directory_name
        destination = historical_path / directory_name
        if source.exists() and destination.exists() and any(destination.iterdir()):
            raise FileExistsError(
                f"Cannot migrate {source}: destination {destination} already contains data"
            )
        if source.exists():
            operations.append(f"move {source} -> {destination}")
        elif not destination.exists():
            operations.append(f"create {destination}")

    for directory_name in ("matches", "daily_listings"):
        live_directory = live_path / directory_name
        if not live_directory.exists():
            operations.append(f"create {live_directory}")

    if dry_run:
        return operations

    historical_path.mkdir(parents=True, exist_ok=True)
    for directory_name in ("matches", "daily_listings"):
        source = root / directory_name
        destination = historical_path / directory_name
        if source.exists():
            if destination.exists():
                destination.rmdir()
            source.rename(destination)
        else:
            destination.mkdir(parents=True, exist_ok=True)

    for directory_name in ("matches", "daily_listings"):
        (live_path / directory_name).mkdir(parents=True, exist_ok=True)

    return operations
