"""Create the FotMob gold layer in ClickHouse."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from clickhouse_setup_common import connect_clickhouse, execute_sql_file, get_layer_sql_files, resolve_clickhouse_root
from src.utils.gold_databases import gold_scenarios_db, gold_signals_db
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)


def _parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create Gold ClickHouse schema/tables")
    parser.add_argument(
        "--part",
        choices=("all", "scenarios", "signals"),
        default="all",
        help="Which gold DDL to execute: scenarios, signals, or all (default: all)",
    )
    return parser.parse_args(argv)


def _gold_sql_filter(part: str):
    def _is_grouped_signal_create_table(name: str) -> bool:
        # New signal DDL naming: create_table_{entity}_{family}_{subfamily}.sql
        return name.startswith("create_table_")

    def _matches(sql_path: Path) -> bool:
        name = sql_path.name.lower()
        if "create_database" in name:
            return True
        if part == "scenarios":
            return ("create" in name and "scenario" in name) and not _is_grouped_signal_create_table(name)
        if part == "signals":
            return ("create" in name and "signal" in name) or _is_grouped_signal_create_table(name)
        return True

    return _matches


def main(argv=None) -> int:
    args = _parse_args(argv)
    sql_filter = _gold_sql_filter(args.part)
    clickhouse_root = resolve_clickhouse_root()
    sql_files = [sql_file for sql_file in get_layer_sql_files("gold", clickhouse_root=clickhouse_root) if sql_filter(sql_file)]
    if not sql_files:
        logger.warning("No SQL files selected for gold setup")
        return 0

    client = connect_clickhouse()
    try:
        for sql_file in sql_files:
            content = sql_file.read_text(encoding="utf-8")
            if args.part == "scenarios":
                rewritten = content.replace("gold.", f"{gold_scenarios_db()}.")
            elif args.part == "signals":
                rewritten = content.replace("gold.", f"{gold_signals_db()}.")
            else:
                rewritten = content
                if "scenario" in sql_file.name.lower():
                    rewritten = content.replace("gold.", f"{gold_scenarios_db()}.")
                if "signal" in sql_file.name.lower() or sql_file.name.lower().startswith("create_table_"):
                    rewritten = content.replace("gold.", f"{gold_signals_db()}.")

            tmp_sql = sql_file.with_suffix(".tmp.sql")
            tmp_sql.write_text(rewritten, encoding="utf-8")
            try:
                if not execute_sql_file(client, tmp_sql):
                    return 1
            finally:
                if tmp_sql.exists():
                    tmp_sql.unlink()
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    sys.exit(main())
