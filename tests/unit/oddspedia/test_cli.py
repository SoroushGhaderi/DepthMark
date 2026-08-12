import json
from argparse import Namespace
from datetime import date
from unittest.mock import Mock

from src.oddspedia.scraping import cli
from src.oddspedia.scraping.audit import DateAudit
from src.oddspedia.scraping.link_prioritization import (
    PRIORITY_SCHEMA_VERSION,
    PriorityArtifact,
    source_inventory_checksum,
)
from src.oddspedia.scraping.manifest import ScrapeManifest


def _date_args(**overrides):
    values = {
        "date": None,
        "month": None,
        "start_date": None,
        "end_date": None,
    }
    values.update(overrides)
    return Namespace(**values)


def test_date_range_scope_is_inclusive_and_ordered():
    assert cli._resolve_dates(
        _date_args(start_date="20260302", end_date="20260304"),
        current_date=date(2026, 8, 12),
    ) == ["20260302", "20260303", "20260304"]


def test_current_month_scope_stops_at_machine_local_current_date():
    assert cli._resolve_dates(
        _date_args(month="202608"),
        current_date=date(2026, 8, 3),
    ) == ["20260801", "20260802", "20260803"]


def test_scrape_generates_missing_priority_artifact(monkeypatch, tmp_path):
    date_str = "20260314"
    source_links = [
        {
            "id": "odd-1",
            "home": "Arsenal",
            "away": "Chelsea",
            "date": "2026-03-14 16:00:00+00",
            "url": "/football/arsenal-chelsea",
        }
    ]
    links_file = tmp_path / "match_links.json"
    links_file.write_text(json.dumps(source_links), encoding="utf-8")
    artifact_path = tmp_path / "prioritized_match_links.json"
    resolver = cli._priority_resolver()
    artifact = PriorityArtifact(
        payload={
            "schema_version": PRIORITY_SCHEMA_VERSION,
            "prioritized_date": date_str,
            "source_inventory": {"sha256": source_inventory_checksum(source_links)},
            "matcher": {"rule_version": resolver.rule_version},
            "links": [
                {
                    "oddspedia_id": "odd-1",
                    "resolution": {
                        "status": "matched",
                        "priority": "lower",
                        "confidence": "exact",
                        "rules": {"home": "exact", "away": "exact"},
                    },
                }
            ],
        }
    )
    loaded_artifacts = iter((None, artifact))
    prioritize = Mock()

    monkeypatch.setattr(cli, "get_match_links_file", lambda date, sport="football": str(links_file))
    monkeypatch.setattr(
        cli,
        "get_prioritized_match_links_file",
        lambda date, sport="football": str(artifact_path),
    )
    monkeypatch.setattr(
        cli,
        "load_priority_artifact",
        lambda date, sport="football": next(loaded_artifacts),
    )
    monkeypatch.setattr(cli, "prioritize_date", prioritize)
    monkeypatch.setattr(cli, "load_manifest", lambda date, sport="football": None)
    monkeypatch.setattr(
        cli,
        "create_manifest",
        lambda date, total, sport="football": ScrapeManifest(date=date, sport=sport, total=total),
    )
    monkeypatch.setattr(cli, "save_manifest", lambda manifest: None)

    selected = cli._selected_priority_matches(date_str, "lower")

    assert selected == source_links
    prioritize.assert_called_once_with(date_str, priority="lower", sport="football")


def test_selection_reuses_date_audit_without_reloading_payloads(monkeypatch, tmp_path):
    manifest = ScrapeManifest(date="20260706", sport="football", total=1)
    audit_result = DateAudit(date="20260706", sport="football", expected=1, existing=1)

    def unexpected_payload_read(*args, **kwargs):
        raise AssertionError("payload should be reused from the date audit")

    monkeypatch.setattr(cli, "audit_match_json", unexpected_payload_read)
    monkeypatch.setattr(cli, "read_match_payload", unexpected_payload_read)
    monkeypatch.setattr(cli, "audit_match_payload", unexpected_payload_read)

    selected, skipped, reconciled = cli._select_matches_to_scrape(
        [{"id": "42", "status": "FT"}],
        str(tmp_path),
        manifest,
        "20260706",
        audit_result=audit_result,
    )

    assert selected == []
    assert skipped == 1
    assert reconciled == 1


def test_empty_inventory_is_reusable_only_with_accepted_no_events_evidence(monkeypatch, tmp_path):
    links_file = tmp_path / "match_links.json"
    links_file.write_text("[]", encoding="utf-8")
    manifest = ScrapeManifest(date="20260314", sport="football", total=0)
    manifest.discovery = {
        "status": "no_events",
        "match_count": 0,
        "empty_confirmed": True,
        "inventory_checksum": source_inventory_checksum([]),
    }
    monkeypatch.setattr(cli, "load_manifest", lambda date, sport="football": manifest)

    assert cli._existing_inventory_matches_target(str(links_file), "20260314")


def test_empty_inventory_without_accepted_evidence_requires_discovery_refresh(
    monkeypatch, tmp_path
):
    links_file = tmp_path / "match_links.json"
    links_file.write_text("[]", encoding="utf-8")
    manifest = ScrapeManifest(date="20260314", sport="football", total=0)
    monkeypatch.setattr(cli, "load_manifest", lambda date, sport="football": manifest)

    assert not cli._existing_inventory_matches_target(str(links_file), "20260314")


def test_legacy_accepted_inventory_requires_checksum_refresh(monkeypatch, tmp_path):
    links = [{"id": "42", "date": "2026-03-14", "home": "Home", "away": "Away"}]
    links_file = tmp_path / "match_links.json"
    links_file.write_text(json.dumps(links), encoding="utf-8")
    manifest = ScrapeManifest(date="20260314", sport="football", total=1)
    manifest.discovery = {
        "status": "accepted",
        "match_count": 1,
        # Legacy manifests did not persist this checksum.
    }
    monkeypatch.setattr(cli, "get_match_links_file", lambda date, sport="football": str(links_file))
    monkeypatch.setattr(cli, "load_manifest", lambda date, sport="football": manifest)

    assert cli._needs_discovery_retry("20260314", "football")


def test_prioritize_dry_run_does_not_create_date_lock(monkeypatch):
    prioritize = Mock()
    lock = Mock(side_effect=AssertionError("dry-run must not acquire a filesystem lock"))
    monkeypatch.setattr(cli, "prioritize_date", prioritize)
    monkeypatch.setattr(cli, "oddspedia_date_lock", lock)

    cli.main(
        [
            "prioritize",
            "--date",
            "20260314",
            "--dry-run",
            "--silver-reference-window-ready",
        ]
    )

    prioritize.assert_called_once_with("20260314", priority="lower", dry_run=True, sport="football")
    lock.assert_not_called()


def test_legacy_status_routes_to_read_only_report_before_log_setup(monkeypatch, capsys):
    from src.operations import scraping_reporting

    bundle = {"overall_status": "complete", "reports": []}
    monkeypatch.setattr(
        scraping_reporting,
        "build_scraping_report",
        lambda source, dates: bundle,
    )
    monkeypatch.setattr(scraping_reporting, "render_summary", lambda report: "read only\n")
    monkeypatch.setattr(
        cli,
        "configure_logging",
        Mock(side_effect=AssertionError("status must not configure persisted logging")),
    )
    monkeypatch.setattr(
        cli,
        "get_run_logs_dir",
        Mock(side_effect=AssertionError("status must not resolve a run-log directory")),
    )

    cli.main(["status", "--date", "20260314"])

    assert capsys.readouterr().out == "read only\n"
