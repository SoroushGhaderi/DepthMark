"""Run system health checks for ClickHouse, storage, and disk space."""

import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from config.settings import get_settings
from src.common.logging import get_logger, setup_logging
from src.common.paths import PROJECT_ROOT
from src.operations.health import health_check

project_root = PROJECT_ROOT

logger = get_logger(__name__)


def parse_arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
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
        help="ClickHouse host (default: CLICKHOUSE_HOST setting)",
    )
    parser.add_argument(
        "--clickhouse-port",
        type=int,
        default=None,
        help="ClickHouse HTTP port (default: CLICKHOUSE_PORT setting)",
    )
    parser.add_argument(
        "--clickhouse-username",
        type=str,
        default=None,
        help="ClickHouse username (default: CLICKHOUSE_USER setting)",
    )
    parser.add_argument(
        "--clickhouse-password",
        type=str,
        default=None,
        help="ClickHouse password (default: CLICKHOUSE_PASSWORD setting)",
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
    return parser.parse_args(argv)


def _log_component(component_name: str, component_result: dict[str, Any]) -> None:
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


def print_health_results(results: dict[str, Any], json_output: bool = False) -> int:
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


def main(argv: Sequence[str] | None = None) -> int:
    """Run the health checks and exit non-zero when any fails."""
    args = parse_arguments(argv)
    setup_logging(
        name="health_check",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    # Flags win; anything not given comes from the CLICKHOUSE_* settings.
    settings = get_settings()
    clickhouse_host = args.clickhouse_host or settings.clickhouse_host
    clickhouse_port = args.clickhouse_port or settings.clickhouse_port
    clickhouse_username = args.clickhouse_username or settings.clickhouse_user
    clickhouse_password = (
        settings.clickhouse_password
        if args.clickhouse_password is None
        else args.clickhouse_password
    )

    storage_paths = list(args.storage or ["data"])
    fotmob_bronze_path = Path("data/fotmob")
    if fotmob_bronze_path.exists() and str(fotmob_bronze_path) not in storage_paths:
        storage_paths.append(str(fotmob_bronze_path))

    if args.storage_only:
        clickhouse_host = None

    results = health_check(
        clickhouse_host=None if args.no_clickhouse else clickhouse_host,
        clickhouse_port=clickhouse_port,
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
