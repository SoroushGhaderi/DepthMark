"""Tests for mirroring signal catalogs into MongoDB."""

from datetime import UTC, datetime

import pytest

from src.fotmob.commands import sync_signal_catalogs as sync
from src.fotmob.gold.signal_catalog import (
    CatalogViolation,
    SignalCatalog,
    SignalCatalogError,
    load_signal_catalog,
)

CREATED_AT = datetime(2026, 1, 1, tzinfo=UTC)


class FakeSignalsRepository:
    def __init__(self, documents=None):
        self.documents = {document["signal_id"]: dict(document) for document in documents or []}
        self.replaced = []
        self.deleted = []

    def list_signal_states(self):
        return {
            signal_id: {
                "signal_id": signal_id,
                "content_sha256": document.get("content_sha256"),
                "created_at": document.get("created_at"),
            }
            for signal_id, document in self.documents.items()
        }

    def replace_signal(self, document, *, created_at=None):
        self.replaced.append((document["signal_id"], created_at))
        self.documents[document["signal_id"]] = {**document, "created_at": created_at}

    def delete_signals(self, signal_ids):
        signal_ids = list(signal_ids)
        self.deleted.extend(signal_ids)
        for signal_id in signal_ids:
            self.documents.pop(signal_id, None)
        return len(signal_ids)


@pytest.fixture(scope="module")
def catalog():
    return load_signal_catalog()


@pytest.fixture(scope="module")
def documents(catalog):
    return [sync.build_signal_document(definition) for definition in catalog]


def _subset(catalog, count):
    return SignalCatalog(definitions=catalog.definitions[:count], catalog_dir=catalog.catalog_dir)


def test_document_mirrors_the_validated_definition(catalog) -> None:
    definition = catalog.get("sig_match_shooting_goals_goal_fest")

    document = sync.build_signal_document(definition)

    assert document["entity"] == "match"
    assert document["grain"] == "match_team"
    assert document["row_identity"] == ["match_id", "triggered_side"]
    assert document["asset_paths"] == {
        "table": "gold_signals.sig_match_shooting_goals_goal_fest",
        "sql": "clickhouse/gold/dml/signals/match/sig_match_shooting_goals_goal_fest.sql",
    }
    assert set(document["assets"]) == {"table", "sql"}
    assert document["assets"]["sql"]["path"] == document["asset_paths"]["sql"]
    assert document["source_path"].endswith("/sig_match_shooting_goals_goal_fest.md")
    assert document["content_sha256"] == sync.content_sha256(
        {key: value for key, value in document.items() if key != "content_sha256"}
    )


def test_first_sync_inserts_every_signal(catalog, documents) -> None:
    repository = FakeSignalsRepository()

    assert sync.sync_signals(catalog, repository) == 0
    assert len(repository.replaced) == len(catalog)
    assert repository.deleted == []


def test_unchanged_signals_are_not_written(catalog, documents) -> None:
    repository = FakeSignalsRepository(documents)

    assert sync.sync_signals(catalog, repository) == 0
    assert repository.replaced == []


def test_changed_signal_is_replaced_keeping_created_at(catalog, documents) -> None:
    stale = dict(documents[0], content_sha256="stale", created_at=CREATED_AT)
    repository = FakeSignalsRepository([stale, *documents[1:]])

    assert sync.sync_signals(catalog, repository) == 0
    assert repository.replaced == [(documents[0]["signal_id"], CREATED_AT)]


def test_signal_without_catalog_is_deleted(catalog, documents) -> None:
    orphan = {"signal_id": "sig_match_shooting_goals_retired", "content_sha256": "x"}
    repository = FakeSignalsRepository([*documents, orphan])

    assert sync.sync_signals(catalog, repository) == 0
    assert repository.deleted == ["sig_match_shooting_goals_retired"]


def test_dry_run_reports_without_writing(catalog, documents) -> None:
    orphan = {"signal_id": "sig_match_shooting_goals_retired", "content_sha256": "x"}
    repository = FakeSignalsRepository([*documents[1:], orphan])

    assert sync.sync_signals(catalog, repository, dry_run=True) == 0
    assert repository.replaced == []
    assert repository.deleted == []


def test_mass_prune_is_refused_without_flag(catalog, documents) -> None:
    repository = FakeSignalsRepository(documents)
    small_catalog = _subset(catalog, 10)

    assert sync.sync_signals(small_catalog, repository) == 1
    assert repository.replaced == []
    assert repository.deleted == []

    assert sync.sync_signals(small_catalog, repository, allow_mass_prune=True) == 0
    assert len(repository.deleted) == len(documents) - 10


def test_small_prune_is_allowed(catalog, documents) -> None:
    repository = FakeSignalsRepository(documents)

    assert sync.sync_signals(_subset(catalog, len(catalog) - 1), repository) == 0
    assert repository.deleted == [documents[-1]["signal_id"]]


def test_prune_refusal_covers_deleting_everything() -> None:
    plan = sync.SignalSyncPlan(deletes=["a"])

    assert "every stored" in plan.prune_refusal(stored_count=1, allow_mass_prune=False)
    assert plan.prune_refusal(stored_count=1, allow_mass_prune=True) is None


def test_invalid_catalog_syncs_nothing(monkeypatch) -> None:
    def invalid_catalog(_catalog_dir):
        raise SignalCatalogError([CatalogViolation("catalogs/sig_x.md", "broken")])

    monkeypatch.setattr(sync, "load_signal_catalog", invalid_catalog)
    monkeypatch.setattr(sync, "setup_logging", lambda **_kwargs: None)

    assert sync.main(["--dry-run"]) == 1


def test_every_document_matches_the_published_signals_schema(documents) -> None:
    import json
    from pathlib import Path

    jsonschema = pytest.importorskip("jsonschema")
    schema = json.loads(Path("schemas/mongodb/signals.schema.json").read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema)
    timestamp = CREATED_AT.isoformat()

    for document in documents:
        stored = {**document, "created_at": timestamp, "updated_at": timestamp}
        errors = [error.message for error in validator.iter_errors(stored)]
        assert errors == [], document["signal_id"]
