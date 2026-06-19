"""Tests for canonical FotMob Bronze aspect paths."""

from pathlib import Path

from src.storage.bronze.paths import get_fotmob_historical_path, get_fotmob_live_path


def test_aspect_paths_are_derived_from_common_root(tmp_path: Path) -> None:
    assert get_fotmob_historical_path(tmp_path) == tmp_path / "historical"
    assert get_fotmob_live_path(tmp_path) == tmp_path / "live"
