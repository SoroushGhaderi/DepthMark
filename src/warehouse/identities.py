"""ClickHouse identities: the narrow application user and the maintenance user (ADR 0029).

The application identity (``CLICKHOUSE_USER``) reads, inserts, and replaces
partitions in warehouse databases, and creates, optimizes, and drops tables only
in the staging database. The maintenance identity
(``CLICKHOUSE_MAINTENANCE_USER``) runs setup, full-history table swaps, Table
Recreation, optimization, truncation, and drop scripts.
"""

from __future__ import annotations

import re
from typing import Any, Sequence

from config.settings import get_settings
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.databases import STAGING_DATABASE
from src.warehouse.scope import WarehouseExecutionScope

SAFE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
WAREHOUSE_DATABASES = (
    "bronze",
    "oddspedia_bronze",
    "silver",
    "gold",
    "gold_scenarios",
    "gold_signals",
)
# ALTER DELETE covers REPLACE PARTITION and DROP PARTITION; a plain ALTER grant
# would also allow dropping or modifying columns.
APPLICATION_WAREHOUSE_PRIVILEGES = ("SELECT", "INSERT", "ALTER DELETE")
APPLICATION_STAGING_PRIVILEGES = (
    "SELECT",
    "INSERT",
    "ALTER DELETE",
    "CREATE TABLE",
    "DROP TABLE",
    "OPTIMIZE",
    "TRUNCATE",
)


def _client(username: str, password: str, database: str) -> ClickHouseClient:
    settings = get_settings()
    return ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=username,
        password=password,
        database=database,
    )


def application_client(database: str = "default") -> ClickHouseClient:
    """Return an unconnected client for the application identity."""
    settings = get_settings()
    return _client(settings.clickhouse_user, settings.clickhouse_password, database)


def maintenance_client(database: str = "default") -> ClickHouseClient:
    """Return an unconnected client for the maintenance identity."""
    settings = get_settings()
    if not settings.clickhouse_maintenance_user:
        raise RuntimeError(
            "This command needs the ClickHouse maintenance identity; set "
            "CLICKHOUSE_MAINTENANCE_USER and CLICKHOUSE_MAINTENANCE_PASSWORD (ADR 0029)."
        )
    return _client(
        settings.clickhouse_maintenance_user,
        settings.clickhouse_maintenance_password,
        database,
    )


def client_for_scope(scope: WarehouseExecutionScope, database: str = "default") -> ClickHouseClient:
    """Full-history loads swap whole tables, which only the maintenance identity may do."""
    if scope.kind == "full-history":
        return maintenance_client(database)
    return application_client(database)


def application_grant_statements(
    username: str,
    warehouse_databases: Sequence[str] = WAREHOUSE_DATABASES,
) -> list[str]:
    """Return the GRANT statements that define the application identity."""
    statements = [
        f"GRANT {', '.join(APPLICATION_WAREHOUSE_PRIVILEGES)} ON {database}.* TO {username}"
        for database in warehouse_databases
    ]
    statements.append(
        f"GRANT {', '.join(APPLICATION_STAGING_PRIVILEGES)} ON {STAGING_DATABASE}.* TO {username}"
    )
    return statements


def application_revoke_statements(
    username: str,
    warehouse_databases: Sequence[str] = WAREHOUSE_DATABASES,
) -> list[str]:
    """Return statements that clear earlier, broader grants before re-granting."""
    return [
        f"REVOKE ALL ON *.* FROM {username}",
        *(f"REVOKE ALL ON {database}.* FROM {username}" for database in warehouse_databases),
        f"REVOKE ALL ON {STAGING_DATABASE}.* FROM {username}",
    ]


def quote_sql_string(value: str) -> str:
    """Quote a SQL string literal for ClickHouse user statements."""
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def provision_application_user(client: Any, username: str, password: str) -> None:
    """Create the application user if missing and reset it to the narrow grant set.

    ``client`` must be connected as an identity with access management. Raises on
    the first failed statement so setup never reports success with stale grants.
    The password is reset on every run, so ``.env`` stays the source of truth.
    """
    if not SAFE_IDENTIFIER_PATTERN.fullmatch(username):
        raise ValueError(f"Unsafe ClickHouse user name: {username}")
    password_literal = quote_sql_string(password)
    client.execute(f"CREATE USER IF NOT EXISTS {username} IDENTIFIED BY {password_literal}")
    client.execute(f"ALTER USER {username} IDENTIFIED BY {password_literal}")
    for statement in application_revoke_statements(username):
        client.execute(statement)
    for statement in application_grant_statements(username):
        client.execute(statement)
