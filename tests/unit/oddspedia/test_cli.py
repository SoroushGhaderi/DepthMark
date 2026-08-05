import json
from unittest.mock import Mock

from src.oddspedia.scraping import cli
from src.oddspedia.scraping.audit import DateAudit
from src.oddspedia.scraping.manifest import ScrapeManifest
from src.oddspedia.scraping.link_prioritization import (
    PRIORITY_SCHEMA_VERSION,
    PriorityArtifact,
    source_inventory_checksum,
)
from src.oddspedia.scraping.manifest import ScrapeManifest


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
