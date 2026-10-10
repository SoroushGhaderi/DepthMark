"""Helpers for resolving Gold ClickHouse databases by job family."""

from config.settings import get_settings

# Every staging table lives here so the application identity needs DROP, OPTIMIZE,
# and TRUNCATE only in this database, never on warehouse tables (ADR 0029).
STAGING_DATABASE = "warehouse_stage"


def gold_db() -> str:
    return get_settings().clickhouse_db_gold


def gold_scenarios_db() -> str:
    return get_settings().clickhouse_db_gold_scenarios


def gold_signals_db() -> str:
    return get_settings().clickhouse_db_gold_signals
