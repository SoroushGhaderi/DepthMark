import pytest

from src.oddspedia.scraping.manifest import ManifestCorruptError, ScrapeManifest, load_manifest


def test_manifest_round_trips_priority_run_summary():
    manifest = ScrapeManifest(date="20260301")
    manifest.record_priority_run(
        {
            "artifact_path": "data/oddspedia/historical/link_priorities/202603/20260301/prioritized_match_links.json",
            "selected_priority": "lower",
            "selected_count": 7,
        }
    )

    restored = ScrapeManifest.from_dict(manifest.to_dict())

    assert restored.priority_run["selected_priority"] == "lower"
    assert restored.priority_run["selected_count"] == 7


def test_corrupt_manifest_is_fail_closed(monkeypatch, tmp_path):
    path = tmp_path / "manifest.json"
    path.write_text("[]", encoding="utf-8")
    monkeypatch.setattr(
        "src.oddspedia.scraping.manifest.get_manifest_path", lambda *_args, **_kwargs: str(path)
    )

    with pytest.raises(ManifestCorruptError):
        load_manifest("20260301")
