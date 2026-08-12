from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.reporting import _findings, _scrape_summary, _summarize_log


def test_summarize_log_classifies_scrape_and_status_runs(tmp_path):
    scrape_log = tmp_path / "scrape.log"
    scrape_log.write_text(
        "scraper_start\nmatch_retry\ncloudflare_wait_start\nscrape_json_complete\n",
        encoding="utf-8",
    )
    status_log = tmp_path / "status.log"
    status_log.write_text("manifest_status_shown\nrun_summary\n", encoding="utf-8")

    scrape = _summarize_log(scrape_log)
    status = _summarize_log(status_log)

    assert scrape["status"] == "success"
    assert scrape["retry_events"] == 1
    assert scrape["cloudflare_waits"] == 1
    assert status["status"] == "status_only"


def test_verified_no_events_is_complete_progress():
    manifest = ScrapeManifest(date="20260320", sport="football", total=0)
    manifest.discovery = {"status": "no_events"}

    summary = _scrape_summary(manifest, set())

    assert summary["full_date_scope_complete"] is True
    assert summary["progress_pct"] == 100.0


def test_findings_separate_priority_and_full_date_scope():
    report = {
        "generated_at": "2026-08-11T00:00:00+00:00",
        "date": "20260320",
        "sport": "football",
        "overall_status": "priority_scope_complete",
        "inventory": {
            "total": 459,
            "unique_ids": 459,
            "duplicate_ids": 0,
            "discovery_status": "accepted",
        },
        "priority": {
            "selected_count": 107,
            "selected_priority": "lower",
            "matched_count": 107,
            "unmatched_count": 352,
            "priority_counts": {"xG": 31, "ratings": 18, "lower": 58, "unmatched": 352},
            "confidence_counts": {"exact": 69, "high_similarity": 37, "alias": 1},
            "reference_window_verified": True,
        },
        "scrape": {
            "selected_completed": 107,
            "total": 459,
            "completed": 107,
            "progress_pct": 23.31,
            "failed": 0,
            "incomplete": 0,
            "skipped": 0,
            "remaining": 352,
            "selected_scope_complete": True,
            "full_date_scope_complete": False,
            "duration_seconds": 3619,
            "metrics": {
                "match_detail_extraction": {"success": 107, "total": 107},
                "performance": {"avg_page_load_ms": 3796.2},
                "cloudflare": {"challenges": 130, "timeouts": 0},
                "odds": {"success_rate_pct": 97.25},
            },
        },
        "payload_audit": {
            "accepted": 107,
            "expected": 459,
            "selected_accepted": 107,
            "selected_expected": 107,
            "selected_problem_count": 0,
            "accepted_data_present": 107,
            "accepted_terminal_no_data": 0,
            "problem_count": 0,
            "coverage_observation_payloads": 73,
            "observation_counts": {"missing optional market": 73},
            "missing": 352,
            "incomplete": 0,
            "invalid": 0,
            "extra": 0,
            "manifest_issues": [],
        },
        "payloads": {"odds_unavailable_count": 1, "odds_unavailable_ids": ["9887045"]},
        "operations": {"scrape_runs": [], "status_inspections": []},
        "warehouse": {
            "bronze_admission_ready": False,
            "reason": "full inventory is incomplete",
        },
        "evidence": {"manifest": "data/manifest.json"},
    }

    findings = "\n".join(_findings(report))

    assert "107/459" in findings
    assert "full-date scope is incomplete" in findings
    assert "Bronze admission is blocked" in findings
