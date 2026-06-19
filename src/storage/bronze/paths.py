"""Canonical filesystem paths for FotMob Bronze storage aspects."""

from pathlib import Path
from typing import Union

PathLike = Union[str, Path]


def get_fotmob_historical_path(bronze_root: PathLike) -> Path:
    """Return the canonical Historical Bronze path beneath ``bronze_root``."""
    return Path(bronze_root) / "historical"


def get_fotmob_live_path(bronze_root: PathLike) -> Path:
    """Return the canonical Live Bronze path beneath ``bronze_root``."""
    return Path(bronze_root) / "live"
