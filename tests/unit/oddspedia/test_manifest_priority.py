from src.oddspedia.scraping.manifest import ScrapeManifest


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
