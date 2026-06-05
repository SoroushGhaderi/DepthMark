"""Aggregate raw signal activations into match-level summary rows."""

import os
import re
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[3]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_db
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)
SUMMARY_ID_VERSION = "v1"
SAFE_IDENTIFIER_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")


def _validate_identifier(value: str, kind: str) -> str:
    if not SAFE_IDENTIFIER_RE.match(value):
        raise ValueError(f"Unsafe {kind}: '{value}'")
    return value


def build_match_level_activations(client: ClickHouseClient, database: str) -> None:
    safe_database = _validate_identifier(database, "database")
    client.execute(f"TRUNCATE TABLE {safe_database}.signal_activations_match")

    query = f"""
    INSERT INTO {safe_database}.signal_activations_match (
        match_activation_instance_id,
        match_id,
        match_date,
        activated_signal_instance_ids,
        activated_signal_ids,
        activated_signal_entities,
        activated_signal_tags,
        activated_signal_names,
        total_signal_rows,
        unique_signal_count
    )
    SELECT
        lower(hex(SHA256(concat('{SUMMARY_ID_VERSION}', '|', toString(match_id)))))
            AS match_activation_instance_id,
        toInt32(match_id) AS match_id,
        toDate(match_date) AS match_date,
        arraySort(groupUniqArray(signal_instance_id)) AS activated_signal_instance_ids,
        arraySort(groupUniqArray(signal_id)) AS activated_signal_ids,
        arraySort(groupUniqArray(signal_entity)) AS activated_signal_entities,
        arraySort(arrayDistinct(arrayFlatten(groupArray(signal_tags)))) AS activated_signal_tags,
        arraySort(groupUniqArray(signal_name)) AS activated_signal_names,
        toUInt32(count()) AS total_signal_rows,
        toUInt16(length(groupUniqArray(signal_id))) AS unique_signal_count
    FROM {safe_database}.signal_activations
    GROUP BY match_id, match_date
    """
    client.execute(query)
    client.execute(f"OPTIMIZE TABLE {safe_database}.signal_activations_match FINAL DEDUPLICATE")


def main() -> int:
    target_db = os.getenv("CLICKHOUSE_GOLD_TARGET_DB", gold_db())
    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        return 1

    try:
        build_match_level_activations(client, target_db)
        logger.info("Built match-level signal activations", target_table=f"{target_db}.signal_activations_match")
        return 0
    except Exception as exc:
        logger.error("Failed to build match-level signal activations", error=str(exc), exc_info=True)
        return 1
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
