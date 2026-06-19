"""Tests for canonical FotMob Bronze paths and legacy migration."""

from pathlib import Path

import pytest

from src.storage.bronze.paths import (
    get_fotmob_historical_path,
    get_fotmob_live_path,
    migrate_legacy_fotmob_storage,
)


def test_aspect_paths_are_derived_from_common_root(tmp_path: Path) -> None:
    assert get_fotmob_historical_path(tmp_path) == tmp_path / "historical"
    assert get_fotmob_live_path(tmp_path) == tmp_path / "live"


def test_migration_moves_legacy_directories_and_creates_live_structure(tmp_path: Path) -> None:
    (tmp_path / "matches" / "20260101").mkdir(parents=True)
    (tmp_path / "matches" / "20260101" / "match_1.json").write_text("{}")
    (tmp_path / "daily_listings" / "20260101").mkdir(parents=True)
    (tmp_path / "daily_listings" / "20260101" / "matches.json").write_text("{}")

    operations = migrate_legacy_fotmob_storage(tmp_path, dry_run=False)

    assert operations
    assert (tmp_path / "historical" / "matches" / "20260101" / "match_1.json").exists()
    assert (tmp_path / "historical" / "daily_listings" / "20260101" / "matches.json").exists()
    assert (tmp_path / "live" / "matches").is_dir()
    assert (tmp_path / "live" / "daily_listings").is_dir()
    assert not (tmp_path / "matches").exists()
    assert not (tmp_path / "daily_listings").exists()


def test_dry_run_does_not_mutate_storage(tmp_path: Path) -> None:
    (tmp_path / "matches").mkdir()
    (tmp_path / "daily_listings").mkdir()

    operations = migrate_legacy_fotmob_storage(tmp_path, dry_run=True)

    assert operations
    assert (tmp_path / "matches").exists()
    assert not (tmp_path / "historical").exists()
    assert not (tmp_path / "live").exists()


def test_migration_rejects_populated_destination_before_moving(tmp_path: Path) -> None:
    (tmp_path / "matches").mkdir()
    destination = tmp_path / "historical" / "matches"
    destination.mkdir(parents=True)
    (destination / "existing.json").write_text("{}")

    with pytest.raises(FileExistsError, match="already contains data"):
        migrate_legacy_fotmob_storage(tmp_path, dry_run=False)

    assert (tmp_path / "matches").exists()
