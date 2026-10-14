"""Tests for the FotMob signal activation builder's use of the signal catalog."""

import pytest

from scripts.gold import build_fotmob_signal_activations as builder
from src.fotmob.gold import service
from src.fotmob.gold.signal_catalog import (
    CatalogViolation,
    SignalCatalogError,
    load_signal_catalog,
    signal_instance_id_expression,
)

MATCH_SIGNAL = "sig_match_shooting_goals_goal_fest"
PLAYER_SIGNAL = "sig_player_shooting_goals_hat_trick_hero"


@pytest.fixture(scope="module")
def catalog():
    return load_signal_catalog()


def _columns(definition, *, with_instance_id=True):
    columns = {"match_id", "match_date", *definition.row_identity}
    if with_instance_id:
        columns.add("signal_instance_id")
    return columns


def test_activation_metadata_comes_from_the_catalog(catalog) -> None:
    definition = catalog.get(MATCH_SIGNAL)

    sql = builder._activation_insert_sql("gold_signals", definition, _columns(definition))

    assert "'match' AS signal_entity" in sql
    assert "'shooting' AS signal_family" in sql
    assert "'goals' AS signal_subfamily" in sql
    assert "'goal_fest' AS signal_name" in sql
    assert "['shooting', 'goals'] AS signal_tags" in sql
    assert "'v1' AS signal_id_version" in sql
    assert "sig.signal_instance_id AS signal_instance_id" in sql


def test_activation_hashes_identity_when_table_lacks_instance_id(catalog) -> None:
    definition = catalog.get(PLAYER_SIGNAL)

    sql = builder._activation_insert_sql(
        "gold_signals", definition, _columns(definition, with_instance_id=False)
    )

    assert f"{signal_instance_id_expression(definition, 'sig')} AS signal_instance_id" in sql


def test_activation_requires_identity_columns_in_the_source_table(catalog) -> None:
    definition = catalog.get(PLAYER_SIGNAL)

    with pytest.raises(ValueError, match="missing required row_identity columns"):
        builder._activation_insert_sql("gold_signals", definition, {"match_id", "match_date"})


def test_invalid_catalog_fails_before_connecting(monkeypatch) -> None:
    def invalid_catalog(_catalog_dir):
        raise SignalCatalogError([CatalogViolation("catalogs/sig_x.md", "broken")])

    def unexpected_client(_scope):
        raise AssertionError("activation builder must not connect with an invalid catalog")

    monkeypatch.setattr(builder, "load_signal_catalog", invalid_catalog)
    monkeypatch.setattr(builder, "client_for_scope", unexpected_client)

    assert builder.main(["--date", "20251208", "--dry-run"]) == 1


def test_gold_service_runs_the_canonical_activation_script() -> None:
    assert service.SIGNAL_ACTIVATION_SCRIPT.name == "build_fotmob_signal_activations.py"
    assert service.SIGNAL_ACTIVATION_SCRIPT.is_file()
