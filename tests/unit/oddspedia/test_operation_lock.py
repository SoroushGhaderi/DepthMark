"""Oddspedia cross-process operation lock tests."""

import json

import pytest

from src.oddspedia.scraping.operation_lock import (
    OddspediaRunLockedError,
    oddspedia_date_lock,
)


def test_date_lock_rejects_an_overlapping_operation(tmp_path) -> None:
    with oddspedia_date_lock(
        "20260706", sport="football", operation="scrape", lock_root=tmp_path
    ) as lock_path:
        metadata = json.loads(lock_path.read_text(encoding="utf-8"))
        assert metadata["date"] == "20260706"
        assert metadata["operation"] == "scrape"

        with pytest.raises(OddspediaRunLockedError, match="already active"):
            with oddspedia_date_lock(
                "20260706", sport="football", operation="load", lock_root=tmp_path
            ):
                pass


def test_date_lock_is_reusable_after_release(tmp_path) -> None:
    with oddspedia_date_lock("20260706", sport="football", operation="scrape", lock_root=tmp_path):
        pass

    with oddspedia_date_lock("20260706", sport="football", operation="load", lock_root=tmp_path):
        pass
