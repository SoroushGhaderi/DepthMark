"""Run system health checks for ClickHouse, storage, and disk space."""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.operations.health import health_check
from src.common.logging import get_logger, setup_logging

logger = get_logger(__name__)


def parse_arguments() -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="System Health Check",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/health_check.py
  python3 scripts/health_check.py --no-clickhouse
  python3 scripts/health_check.py --storage-only
  python3 scripts/health_check.py --storage data data/fotmob
  python3 scripts/health_check.py --json
        """,
    )
    parser.add_argument(
        "--clickhouse-host",
        type=str,
        default=None,
        help="ClickHouse host (default: CLICKHOUSE_HOST env var or 'localhost')",
    )
    parser.add_argument(
        "--clickhouse-port",
        type=int,
        default=8123,
        help="ClickHouse HTTP port (default: 8123)",
    )
    parser.add_argument(
        "--clickhouse-username",
        type=str,
        default="default",
        help="ClickHouse username (default: CLICKHOUSE_USER env var or 'default')",
    )
    parser.add_argument(
        "--clickhouse-password",
        type=str,
        default="",
        help="ClickHouse password (default: CLICKHOUSE_PASSWORD env var or empty)",
    )
    parser.add_argument(
        "--clickhouse-database",
        type=str,
        default="default",
        help="ClickHouse database to check (default: 'default')",
    )
    parser.add_argument("--no-clickhouse", action="store_true", help="Skip ClickHouse health check")
    parser.add_argument("--storage", nargs="+", default=None, help="Storage paths to check")
    parser.add_argument(
        "--storage-only",
        action="store_true",
        help="Skip ClickHouse and use only storage/disk checks",
    )
    parser.add_argument(
        "--disk-path",
        type=str,
        default=".",
        help="Directory path to check disk usage (default: current directory)",
    )
    parser.add_argument(
        "--disk-threshold",
        type=float,
        default=1.0,
        help="Free disk space threshold in GB (default: 1.0)",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")
    return parser.parse_args()


def _log_component(component_name: str, component_result: Dict[str, Any]) -> None:
    """Log one health-check component."""
    logger.info("%s", component_name.upper().replace("_", " "))
    logger.info("%s", "-" * 80)

    if "status" in component_result:
        status = component_result.get("status", "unknown")
        symbol = {
            "healthy": "OK",
            "warning": "WARN",
            "error": "ERR",
            "critical": "ERR",
            "skipped": "SKIP",
        }.get(status, "?")
        logger.info("Status: %s %s", symbol, status.upper())
        message = component_result.get("message")
        if message:
            logger.info("Message: %s", message)
        for key, value in component_result.items():
            if key not in {"status", "message"}:
                logger.info("%s: %s", key, value)
        return

    for path_name, path_result in component_result.items():
        if not isinstance(path_result, dict):
            continue
        status = path_result.get("status", "unknown")
        symbol = {
            "healthy": "OK",
            "warning": "WARN",
            "error": "ERR",
            "critical": "ERR",
        }.get(status, "?")
        logger.info("%s: %s %s", path_name, symbol, status.upper())
        if "message" in path_result:
            logger.info("  %s", path_result["message"])


def print_health_results(results: Dict[str, Any], json_output: bool = False) -> int:
    """Log health check results and return a process exit code."""
    if json_output:
        logger.info("%s", json.dumps(results, indent=2))
    else:
        logger.info("%s", "=" * 80)
        logger.info("SYSTEM HEALTH CHECK")
        logger.info("%s", "=" * 80)
        logger.info("Timestamp: %s", results["timestamp"])
        logger.info("Overall Status: %s", results["overall_status"].upper())
        for component_name, component_result in results["components"].items():
            if isinstance(component_result, dict):
                _log_component(component_name, component_result)
        logger.info("%s", "=" * 80)

    if results["overall_status"] == "healthy":
        return 0
    if results["overall_status"] == "degraded":
        return 1
    return 2


def main() -> int:
    """Main entry point."""
    args = parse_arguments()
    setup_logging(
        name="health_check",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    clickhouse_host = args.clickhouse_host or os.getenv("CLICKHOUSE_HOST")
    if clickhouse_host == "localhost":
        clickhouse_host = os.getenv("CLICKHOUSE_HOST", "clickhouse")

    clickhouse_username = os.getenv("CLICKHOUSE_USER", args.clickhouse_username)
    clickhouse_password = os.getenv("CLICKHOUSE_PASSWORD", args.clickhouse_password)

    storage_paths = list(args.storage or ["data"])
    fotmob_bronze_path = Path("data/fotmob")
    if fotmob_bronze_path.exists() and str(fotmob_bronze_path) not in storage_paths:
        storage_paths.append(str(fotmob_bronze_path))

    if args.storage_only:
        clickhouse_host = None

    results = health_check(
        clickhouse_host=None if args.no_clickhouse else clickhouse_host,
        clickhouse_port=args.clickhouse_port,
        clickhouse_username=clickhouse_username,
        clickhouse_password=clickhouse_password,
        clickhouse_database=args.clickhouse_database,
        storage_paths=storage_paths,
        disk_path=args.disk_path,
        disk_threshold_gb=args.disk_threshold,
    )
    return print_health_results(results, json_output=args.json)


if __name__ == "__main__":
    raise SystemExit(main())
