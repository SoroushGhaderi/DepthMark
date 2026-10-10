from types import SimpleNamespace

import pytest

from scripts import clickhouse_setup_common
from src.warehouse import identities
from src.warehouse.identities import (
    WAREHOUSE_DATABASES,
    application_grant_statements,
    client_for_scope,
    provision_application_user,
)
from src.warehouse.scope import WarehouseExecutionScope
from src.warehouse.scoped_replace import ScopedReplacementBatch, ScopedSqlJob


class _RecordingClient:
    def __init__(self):
        self.queries = []

    def execute(self, query, parameters=None, *, log_query=True):
        self.queries.append(query)
        if query.startswith("SELECT count()"):
            return SimpleNamespace(result_rows=[(1,)])
        return SimpleNamespace(result_rows=[])


class _Logger:
    def info(self, *args, **kwargs):
        pass

    error = warning = info


def _settings(**overrides):
    values = dict(
        clickhouse_host="localhost",
        clickhouse_port=8123,
        clickhouse_user="depthmark_app",
        clickhouse_password="app-secret-value",
        clickhouse_maintenance_user="depthmark_admin",
        clickhouse_maintenance_password="admin-secret-value",
    )
    values.update(overrides)
    return SimpleNamespace(**values)


def test_application_grants_keep_destructive_rights_in_staging_only():
    grants = application_grant_statements("depthmark_app")

    warehouse_grants = [grant for grant in grants if "warehouse_stage" not in grant]
    assert len(warehouse_grants) == len(WAREHOUSE_DATABASES)
    for grant in warehouse_grants:
        assert grant.startswith("GRANT SELECT, INSERT, ALTER DELETE ON ")
        for privilege in ("DROP", "TRUNCATE", "OPTIMIZE", "CREATE", "ALTER,", "ALL"):
            assert privilege not in grant
    (staging_grant,) = [grant for grant in grants if "warehouse_stage" in grant]
    assert "DROP TABLE" in staging_grant and "CREATE TABLE" in staging_grant


def test_provisioning_revokes_before_granting():
    client = _RecordingClient()

    provision_application_user(client, "depthmark_app", "it's-secret")

    assert client.queries[0] == (
        "CREATE USER IF NOT EXISTS depthmark_app IDENTIFIED BY 'it\\'s-secret'"
    )
    assert client.queries[1] == "ALTER USER depthmark_app IDENTIFIED BY 'it\\'s-secret'"
    first_grant = next(i for i, q in enumerate(client.queries) if q.startswith("GRANT"))
    assert all(q.startswith("REVOKE") for q in client.queries[2:first_grant])


def test_provisioning_rejects_unsafe_user_names():
    with pytest.raises(ValueError):
        provision_application_user(_RecordingClient(), "app; DROP", "secret")


def test_full_history_loads_use_the_maintenance_identity(monkeypatch):
    monkeypatch.setattr(identities, "get_settings", lambda: _settings())

    assert client_for_scope(WarehouseExecutionScope.full_history()).username == "depthmark_admin"
    assert client_for_scope(WarehouseExecutionScope.for_month("202512")).username == "depthmark_app"


def test_maintenance_identity_must_be_configured(monkeypatch):
    monkeypatch.setattr(
        identities, "get_settings", lambda: _settings(clickhouse_maintenance_user=None)
    )

    with pytest.raises(RuntimeError, match="CLICKHOUSE_MAINTENANCE_USER"):
        client_for_scope(WarehouseExecutionScope.full_history())


def test_scoped_batches_stage_only_in_the_staging_database():
    client = _RecordingClient()
    job = ScopedSqlJob(
        "match", "silver.match", ("INSERT INTO silver.match SELECT 1",), "match_date"
    )

    ScopedReplacementBatch(
        client, WarehouseExecutionScope.for_date("20251208"), log=_Logger(), run_id="r"
    ).run([job])

    for query in client.queries:
        if query.startswith(("CREATE TABLE", "DROP TABLE", "OPTIMIZE TABLE")):
            assert query.split()[2].startswith("warehouse_stage."), query


@pytest.mark.parametrize(
    "overrides, message",
    [
        ({"clickhouse_maintenance_user": None}, "CLICKHOUSE_MAINTENANCE_USER"),
        ({"clickhouse_maintenance_user": "depthmark_app"}, "must differ"),
    ],
)
def test_setup_requires_a_distinct_maintenance_identity(monkeypatch, overrides, message):
    monkeypatch.setattr(clickhouse_setup_common, "get_settings", lambda: _settings(**overrides))
    monkeypatch.setattr(clickhouse_setup_common, "is_local_development_environment", lambda: True)

    with pytest.raises(RuntimeError, match=message):
        clickhouse_setup_common.connect_clickhouse()
