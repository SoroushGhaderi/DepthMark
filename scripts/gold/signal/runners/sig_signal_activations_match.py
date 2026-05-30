"""Aggregate per-row signal activations into match-level signal activations."""

import os
import re
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[4]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_db
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)
SIGNAL_ID_VERSION = "v1"
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
        signal_match_instance_id,
        signal_id,
        signal_id_version,
        match_id,
        match_date,
        source_table,
        activation_count
    )
    SELECT
        lower(hex(SHA256(concat('{SIGNAL_ID_VERSION}', '|', signal_id, '|', toString(match_id)))))
            AS signal_match_instance_id,
        signal_id,
        signal_id_version,
        toInt32(match_id) AS match_id,
        toDate(match_date) AS match_date,
        source_table,
        toUInt32(count()) AS activation_count
    FROM {safe_database}.signal_activations
    GROUP BY signal_id, signal_id_version, match_id, match_date, source_table
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
