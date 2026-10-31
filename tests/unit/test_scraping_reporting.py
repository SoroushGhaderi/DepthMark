"""Contract tests for unified, read-only scraping reports."""

import json
from datetime import date

from src.fotmob.scraping.reporting import build_run_report as build_fotmob_report
from src.operations import scraping_reporting
from src.operations.commands import report_scraping


def _common_report(source: str, status: str = "complete") -> dict:
    return {
        "schema_version": "v1",
        "source": source,
        "date": "20260301",
        "aspect": "historical",
        "overall_status": status,
        "summary": {
            "discovered": 3,
            "completed": 2,
            "failed": 0,
            "skipped": 1,
            "remaining": 0,
            "progress_pct": 100.0,
            "artifact_files": 2,
            "storage_size_mb": 1.5,
            "bronze_admission_ready": status == "complete",
        },
        "findings": [],
        "next_steps": ["run the dry-run Bronze loader"],
        "evidence": {"listing": "data/listing.json"},
    }


def test_fotmob_report_reconciles_listing_files_and_unavailable_matches(tmp_path) -> None:
    listing_dir = tmp_path / "historical" / "daily_listings" / "202603" / "20260301"
    matches_dir = tmp_path / "historical" / "matches" / "202603" / "20260301"
    listing_dir.mkdir(parents=True)
    matches_dir.mkdir(parents=True)
    (listing_dir / "matches.json").write_text(
        json.dumps(
            {
                "date": "20260301",
                "scraped_at": "2026-03-02T01:02:03",
                "match_ids": [101, 102, 103],
                "storage": {"unavailable_match_ids": [103]},
            }
        ),
        encoding="utf-8",
    )
    (matches_dir / "match_101.json").write_text("{}", encoding="utf-8")
    (matches_dir / "match_102.json.gz").write_bytes(b"payload")
    before = sorted(path.relative_to(tmp_path) for path in tmp_path.rglob("*"))

    report = build_fotmob_report(
        "20260301",
        bronze_root=tmp_path,
        current_date=date(2026, 3, 2),
    )

    assert report["source"] == "fotmob"
    assert report["overall_status"] == "complete"
    assert report["summary"] == {
        "discovered": 3,
        "completed": 3,
        "failed": 0,
        "skipped": 1,
        "remaining": 0,
        "progress_pct": 100.0,
        "artifact_files": 2,
        "storage_size_mb": 0.0,
        "bronze_admission_ready": True,
    }
    assert report["storage"]["missing_match_ids"] == []
    assert sorted(path.relative_to(tmp_path) for path in tmp_path.rglob("*")) == before


def test_unified_report_uses_both_explicit_source_adapters(monkeypatch) -> None:
    calls = []

    def fotmob(date_str: str) -> dict:
        calls.append(("fotmob", date_str))
        return _common_report("fotmob")

    def oddspedia(date_str: str) -> dict:
        calls.append(("oddspedia", date_str))
        return _common_report("oddspedia", "attention_required")

    monkeypatch.setattr(scraping_reporting, "build_fotmob_report", fotmob)
    monkeypatch.setattr(scraping_reporting, "build_oddspedia_report", oddspedia)

    report = scraping_reporting.build_scraping_report("all", ["20260301"])

    assert calls == [("fotmob", "20260301"), ("oddspedia", "20260301")]
    assert report["overall_status"] == "attention_required"
    assert report["totals"]["sources"] == 2
    assert report["totals"]["discovered"] == 6
    assert report["totals"]["completed"] == 4


def test_unified_report_isolates_one_source_artifact_error(monkeypatch) -> None:
    def broken_fotmob(_date: str) -> dict:
        raise ValueError("malformed listing")

    monkeypatch.setattr(scraping_reporting, "build_fotmob_report", broken_fotmob)
    monkeypatch.setattr(
        scraping_reporting,
        "build_oddspedia_report",
        lambda _date: _common_report("oddspedia"),
    )

    report = scraping_reporting.build_scraping_report("all", ["20260301"])

    assert report["overall_status"] == "error"
    assert [item["overall_status"] for item in report["reports"]] == ["error", "complete"]
    assert "malformed listing" in report["reports"][0]["error"]


def test_summary_and_markdown_render_the_same_cross_source_scope(monkeypatch) -> None:
    monkeypatch.setattr(
        scraping_reporting,
        "build_fotmob_report",
        lambda _date: _common_report("fotmob"),
    )
    monkeypatch.setattr(
        scraping_reporting,
        "build_oddspedia_report",
        lambda _date: _common_report("oddspedia"),
    )
    report = scraping_reporting.build_scraping_report("all", ["20260301"])

    summary = scraping_reporting.render_summary(report)
    markdown = scraping_reporting.render_markdown(report)

    for content in (summary, markdown):
        assert "FotMob" in content
        assert "Oddspedia" in content
        assert "20260301" in content
        assert "100.00%" in content


def test_month_scope_ends_at_current_date() -> None:
    assert scraping_reporting.resolve_report_dates(
        month="202608", current_date=date(2026, 8, 3)
    ) == ["20260801", "20260802", "20260803"]


def test_report_scope_accepts_an_inclusive_date_range() -> None:
    assert scraping_reporting.resolve_report_dates(
        start_date="20260301",
        end_date="20260303",
        current_date=date(2026, 8, 3),
    ) == ["20260301", "20260302", "20260303"]


def test_report_script_writes_requested_format_and_can_fail_on_attention(
    monkeypatch, tmp_path
) -> None:
    bundle = {
        "overall_status": "attention_required",
        "reports": [_common_report("fotmob", "attention_required")],
    }
    monkeypatch.setattr(report_scraping, "build_scraping_report", lambda *_args: bundle)
    output = tmp_path / "scraping-report.json"

    result = report_scraping.main(
        [
            "--source",
            "fotmob",
            "--date",
            "20260301",
            "--format",
            "json",
            "--output",
            str(output),
            "--fail-on-attention",
        ]
    )

    assert result == 1
    assert json.loads(output.read_text(encoding="utf-8"))["overall_status"] == (
        "attention_required"
    )
