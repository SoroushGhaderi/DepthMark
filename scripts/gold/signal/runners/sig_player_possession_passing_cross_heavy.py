"""Run the sig_player_possession_passing_cross_heavy gold query."""

import argparse
import os
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(project_root))

from config.settings import settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_signals_db
from src.utils.logging_utils import get_logger

logger = get_logger()


SIGNAL_SQL_DIR = project_root / "clickhouse" / "gold" / "signal"
SQL_FILE = next(
    (path for path in SIGNAL_SQL_DIR.rglob(f"{Path(__file__).stem}.sql") if path.is_file()),
    SIGNAL_SQL_DIR / f"{Path(__file__).stem}.sql",
)
TARGET_TABLE = f"{gold_signals_db()}.sig_player_possession_passing_cross_heavy"


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the player-possession-passing-cross-heavy signal query"
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    parse_args(argv)

    if not SQL_FILE.exists():
        logger.error("SQL file not found: %s", SQL_FILE)
        return 1

    insert_query = SQL_FILE.read_text(encoding="utf-8").strip().rstrip(";")
    target_db = os.getenv("CLICKHOUSE_GOLD_TARGET_DB", gold_signals_db())
    insert_query = insert_query.replace("gold.", f"{target_db}.")
    target_table = TARGET_TABLE.replace(gold_signals_db(), target_db)

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
        client.execute(insert_query)
        logger.info("sig_player_possession_passing_cross_heavy insert completed")

        optimize_sql = f"OPTIMIZE TABLE {target_table} FINAL DEDUPLICATE"
        client.execute(optimize_sql)
        logger.info("Optimization completed for %s", TARGET_TABLE)

        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
