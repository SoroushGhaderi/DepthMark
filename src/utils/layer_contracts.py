"""Lightweight data contracts and quality assertions for medallion layers."""

import re
from typing import Any, Dict, List, Optional

import pandas as pd

from ..storage.clickhouse_client import ClickHouseClient
from .logging_utils import get_logger

logger = get_logger(__name__)


class LayerContractError(RuntimeError):
    """Raised when a layer contract assertion fails."""


BRONZE_REQUIRED_KEYS: Dict[str, List[str]] = {
    "match_reference": ["match_id"],
    "general": ["match_id"],
    "timeline": ["match_id"],
    "venue": ["match_id"],
    "player": ["match_id", "player_id"],
    "shotmap": ["match_id", "shot_id"],
    "goal": ["match_id", "event_id"],
    "cards": ["match_id", "event_id"],
    "red_card": ["match_id", "event_id"],
    "period": ["match_id", "period"],
    "momentum": ["match_id", "minute"],
    "starters": ["match_id", "player_id"],
    "substitutes": ["match_id", "player_id"],
    "coaches": ["match_id", "coach_id"],
    "team_form": ["match_id", "team_id", "form_position"],
}

SILVER_TABLE_KEYS: Dict[str, List[str]] = {
    "match": ["match_id"],
    "period_stat": ["match_id", "period"],
    "player_match_stat": ["match_id", "player_id"],
    "momentum": ["match_id", "minute"],
    "shot": ["match_id", "shot_id"],
    "card": ["match_id", "event_id"],
    "match_personnel": ["match_id", "team_side", "role", "person_id"],
    "team_form": ["match_id", "team_id", "form_position"],
}

_SAFE_IDENTIFIER = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
_NUMERIC_KEY_COLUMNS = {
    "match_id",
    "player_id",
    "shot_id",
    "event_id",
    "minute",
    "person_id",
    "team_id",
    "form_position",
}


def _safe_identifier(identifier: str) -> str:
    """Validate SQL identifier for contract queries."""
    if not _SAFE_IDENTIFIER.match(identifier):
        raise LayerContractError(f"Unsafe identifier in contract query: {identifier}")
    return identifier


def _extract_first_scalar(result: Any, default: int = 0) -> int:
    """Extract first scalar from clickhouse result-like object."""
    if hasattr(result, "result_rows") and result.result_rows:
        return int(result.result_rows[0][0])
    if isinstance(result, (list, tuple)) and result:
        first_row = result[0]
        if isinstance(first_row, (list, tuple)):
            return int(first_row[0])
        return int(first_row)
    return default


def _query_scalar(client: ClickHouseClient, query: str, default: int = 0) -> int:
    """Run query and return first scalar."""
    return _extract_first_scalar(client.execute(query, log_query=False), default=default)


def _table_exists(client: ClickHouseClient, database: str, table: str) -> bool:
    """Return True when table exists."""
    db = _safe_identifier(database)
    tbl = _safe_identifier(table)
    query = "SELECT count() FROM system.tables " f"WHERE database = '{db}' AND name = '{tbl}'"
    return _query_scalar(client, query) > 0


def assert_bronze_dataframe_contract(
    table_name: str,
    dataframe: pd.DataFrame,
    log=logger,
) -> None:
    """Validate lightweight bronze contract against an in-memory dataframe."""
    required_keys = BRONZE_REQUIRED_KEYS.get(table_name)
    if not required_keys or dataframe.empty:
        return

    missing_columns = [col for col in required_keys if col not in dataframe.columns]
    if missing_columns:
        raise LayerContractError(
            f"Bronze contract failed for {table_name}: missing key columns {missing_columns}"
        )

    null_counts = {
        col: int(dataframe[col].isna().sum())
        for col in required_keys
        if dataframe[col].isna().any()
    }
    if null_counts:
        raise LayerContractError(
            f"Bronze contract failed for {table_name}: nulls in key columns {null_counts}"
        )

    duplicate_count = int(dataframe.duplicated(subset=required_keys).sum())
    if duplicate_count > 0:
        log.warning(
            "Bronze dataframe contains duplicate key rows prior to ClickHouse dedup",
            table_name=table_name,
            duplicate_rows=duplicate_count,
            key_columns=required_keys,
        )


def assert_bronze_layer_contracts(
    client: ClickHouseClient,
    inserted_rows_by_table: Dict[str, int],
    baseline_invalid_rows_by_table: Optional[Dict[str, int]] = None,
    database: str = "bronze",
    log=logger,
) -> None:
    """Run lightweight post-load bronze assertions on tables touched in this run."""
    db = _safe_identifier(database)

    for table_name, inserted_rows in inserted_rows_by_table.items():
        if inserted_rows <= 0:
            continue

        table = _safe_identifier(table_name)
        keys = BRONZE_REQUIRED_KEYS.get(table, [])
        if not keys:
            continue

        if not _table_exists(client, db, table):
            raise LayerContractError(f"Bronze contract failed: missing table {db}.{table}")

        null_predicates = [f"isNull({col})" for col in keys]
        numeric_key_predicates = [f"{col} <= 0" for col in keys if col in _NUMERIC_KEY_COLUMNS]
        bad_rows_query = (
            f"SELECT count() FROM {db}.{table} "
            f"WHERE {' OR '.join(null_predicates + numeric_key_predicates)}"
        )
        invalid_key_rows = _query_scalar(client, bad_rows_query)
        baseline_invalid_rows = 0
        if baseline_invalid_rows_by_table:
            baseline_invalid_rows = int(baseline_invalid_rows_by_table.get(table, 0))

        new_invalid_rows = max(0, invalid_key_rows - baseline_invalid_rows)
        if new_invalid_rows > 0:
            raise LayerContractError(
                f"Bronze contract failed for {db}.{table}: "
                f"{new_invalid_rows} new invalid key rows "
                f"(total_invalid={invalid_key_rows}, baseline_invalid={baseline_invalid_rows})"
            )


def get_bronze_invalid_key_rows(
    client: ClickHouseClient,
    table_names: List[str],
    database: str = "bronze",
) -> Dict[str, int]:
    """Return current invalid key row counts for bronze tables."""
    db = _safe_identifier(database)
    counts: Dict[str, int] = {}

    for table_name in table_names:
        table = _safe_identifier(table_name)
        keys = BRONZE_REQUIRED_KEYS.get(table, [])
        if not keys:
            continue
        if not _table_exists(client, db, table):
            continue

        null_predicates = [f"isNull({col})" for col in keys]
        numeric_key_predicates = [f"{col} <= 0" for col in keys if col in _NUMERIC_KEY_COLUMNS]
        bad_rows_query = (
            f"SELECT count() FROM {db}.{table} "
            f"WHERE {' OR '.join(null_predicates + numeric_key_predicates)}"
        )
        counts[table] = _query_scalar(client, bad_rows_query)

    return counts


def assert_silver_layer_contracts(
    client: ClickHouseClient,
    database: str = "silver",
    log=logger,
) -> None:
    """Run lightweight post-load silver assertions."""
    db = _safe_identifier(database)

    for table_name, keys in SILVER_TABLE_KEYS.items():
        table = _safe_identifier(table_name)
        if not _table_exists(client, db, table):
            raise LayerContractError(f"Silver contract failed: missing table {db}.{table}")

        rows = _query_scalar(client, f"SELECT count() FROM {db}.{table}")
        if rows == 0:
            log.warning("Silver table is empty after load", table=f"{db}.{table}")
            continue

        invalid_conditions = [f"isNull({col})" for col in keys]
        invalid_conditions.extend(f"{col} <= 0" for col in keys if col in _NUMERIC_KEY_COLUMNS)
        invalid_key_rows = _query_scalar(
            client,
            f"SELECT count() FROM {db}.{table} WHERE {' OR '.join(invalid_conditions)}",
        )
        if invalid_key_rows > 0:
            raise LayerContractError(
                f"Silver contract failed for {db}.{table}: {invalid_key_rows} invalid key rows"
            )

        tuple_expr = ", ".join(keys)
        uniqueness_query = f"SELECT count(), uniqExact(tuple({tuple_expr})) FROM {db}.{table}"
        result = client.execute(uniqueness_query, log_query=False)
        row_count = int(result.result_rows[0][0]) if result.result_rows else 0
        unique_count = int(result.result_rows[0][1]) if result.result_rows else 0
        if row_count > unique_count:
            log.warning(
                "Silver table has duplicate key rows (expected for replacing engines until final dedup)",
                table=f"{db}.{table}",
                duplicate_rows=row_count - unique_count,
                key_columns=keys,
            )


def _list_gold_analytics_tables(
    client: ClickHouseClient,
    database: str,
    table_prefix: str,
) -> List[str]:
    """Return gold analytics tables in one namespace matching a table prefix."""
    db = _safe_identifier(database)
    prefix = table_prefix.replace("'", "")
    if not prefix:
        raise LayerContractError("Gold contract query requires a non-empty table prefix")
    query = (
        "SELECT name FROM system.tables "
        f"WHERE database = '{db}' "
        f"AND startsWith(name, '{prefix}') "
        "ORDER BY name"
    )
    result = client.execute(query, log_query=False)
    if hasattr(result, "result_rows") and result.result_rows:
        return [str(row[0]) for row in result.result_rows if row]
    return []


def _assert_gold_analytics_tables(
    client: ClickHouseClient,
    database: str,
    table_prefix: str,
    log=logger,
) -> None:
    """Run post-load assertions for one Gold analytics namespace."""
    db = _safe_identifier(database)
    analytics_tables = _list_gold_analytics_tables(
        client,
        database=db,
        table_prefix=table_prefix,
    )
    if not analytics_tables:
        raise LayerContractError(
            f"Gold contract failed: no {table_prefix}* tables found in {db}"
        )

    for table_name in analytics_tables:
        table = _safe_identifier(table_name)
        rows = _query_scalar(client, f"SELECT count() FROM {db}.{table}")
        if rows == 0:
            continue

        invalid_match_ids = _query_scalar(
            client, f"SELECT count() FROM {db}.{table} WHERE isNull(match_id) OR match_id <= 0"
        )
        if invalid_match_ids > 0:
            raise LayerContractError(
                f"Gold contract failed for {db}.{table}: {invalid_match_ids} invalid match_id rows"
            )

        columns = set(_list_table_columns(client, database=db, table=table))
        if "home_score" in columns and "away_score" in columns:
            negative_scores = _query_scalar(
                client,
                f"SELECT count() FROM {db}.{table} " "WHERE (home_score < 0) OR (away_score < 0)",
            )
            if negative_scores > 0:
                log.warning(
                    "Gold table contains negative score values",
                    table=f"{db}.{table}",
                    rows=negative_scores,
                )


def _list_table_columns(client: ClickHouseClient, database: str, table: str) -> List[str]:
    """Return table column names from system.columns."""
    db = _safe_identifier(database)
    tbl = _safe_identifier(table)
    query = "SELECT name FROM system.columns " f"WHERE database = '{db}' AND table = '{tbl}'"
    result = client.execute(query, log_query=False)
    if hasattr(result, "result_rows") and result.result_rows:
        return [str(row[0]) for row in result.result_rows if row]
    return []


def assert_gold_layer_contracts(
    client: ClickHouseClient,
    scenario_database: str = "gold_scenarios",
    signal_database: str = "gold_signals",
    check_scenarios: bool = True,
    check_signals: bool = True,
    log=logger,
) -> None:
    """Run lightweight post-load assertions for Gold scenario and signal outputs."""
    if check_scenarios:
        _assert_gold_analytics_tables(
            client,
            database=scenario_database,
            table_prefix="scenario_",
            log=log,
        )
    if check_signals:
        _assert_gold_analytics_tables(
            client,
            database=signal_database,
            table_prefix="sig_",
            log=log,
        )


def assert_gold_activation_contracts(
    client: ClickHouseClient,
    database: str = "gold",
    log=logger,
) -> None:
    """Run lightweight post-load assertions for the Gold activation serving table."""
    db = _safe_identifier(database)
    table = "signal_activations"
    if not _table_exists(client, db, table):
        raise LayerContractError(f"Gold activation contract failed: missing table {db}.{table}")

    rows = _query_scalar(client, f"SELECT count() FROM {db}.{table}")
    if rows == 0:
        log.warning("Gold activation serving table is empty after load", table=f"{db}.{table}")
        return

    required_columns = {
        "signal_instance_id",
        "signal_id",
        "signal_id_version",
        "match_id",
        "match_date",
        "match_activation_instance_id",
        "activated_signal_instance_ids",
        "total_signal_rows",
        "unique_signal_count",
        "source_table",
        "source_row_json",
    }
    columns = set(_list_table_columns(client, database=db, table=table))
    missing_columns = sorted(required_columns - columns)
    if missing_columns:
        raise LayerContractError(
            f"Gold activation contract failed for {db}.{table}: "
            f"missing columns {missing_columns}"
        )

    invalid_rows = _query_scalar(
        client,
        f"SELECT count() FROM {db}.{table} "
        "WHERE signal_instance_id = '' "
        "OR signal_id = '' "
        "OR signal_id_version = '' "
        "OR isNull(match_id) "
        "OR match_id <= 0 "
        "OR source_table = '' "
        "OR source_row_json = ''",
    )
    if invalid_rows > 0:
        raise LayerContractError(
            f"Gold activation contract failed for {db}.{table}: "
            f"{invalid_rows} invalid activation rows"
        )

    uniqueness_query = f"SELECT count(), uniqExact(signal_instance_id) FROM {db}.{table}"
    result = client.execute(uniqueness_query, log_query=False)
    row_count = int(result.result_rows[0][0]) if result.result_rows else 0
    unique_count = int(result.result_rows[0][1]) if result.result_rows else 0
    if row_count > unique_count:
        raise LayerContractError(
            f"Gold activation contract failed for {db}.{table}: "
            f"{row_count - unique_count} duplicate signal_instance_id rows"
        )
