"""Helpers for resolving Gold ClickHouse databases by job family."""

from config.settings import get_settings


def gold_db() -> str:
    return get_settings().clickhouse_db_gold


def gold_scenarios_db() -> str:
    return get_settings().clickhouse_db_gold_scenarios


def gold_signals_db() -> str:
    return get_settings().clickhouse_db_gold_signals
