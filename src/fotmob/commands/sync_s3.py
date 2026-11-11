#!/usr/bin/env python3
"""Upload or download FotMob Bronze artifacts independently of scraping.

Examples:
    python3 scripts/fotmob/sync_fotmob_s3.py upload --date 20251208 --dry-run
    python3 scripts/fotmob/sync_fotmob_s3.py upload --month 202512
    python3 scripts/fotmob/sync_fotmob_s3.py download --start-date 20251201 --end-date 20251207
    python3 scripts/fotmob/sync_fotmob_s3.py download --all
"""

import argparse

from config.settings import get_settings
from src.common.logging import configure_logging, get_logger
from src.common.run_scope import RunScope, ScopeError
from src.fotmob.bronze import BronzeS3Service, BronzeS3SyncError, BronzeS3SyncResult
from src.fotmob.bronze.paths import get_fotmob_historical_path
from src.integrations.s3 import S3ConfigurationError, create_s3_client

logger = get_logger(__name__)


def create_argument_parser() -> argparse.ArgumentParser:
    """Create the standalone Bronze S3 command parser."""
    parser = argparse.ArgumentParser(
        description="Independently upload or download date-scoped FotMob Bronze artifacts"
    )
    subparsers = parser.add_subparsers(dest="action", required=True)

    upload_parser = subparsers.add_parser("upload", help="Upload local Bronze artifacts to S3")
    _add_scope_arguments(upload_parser)
    upload_parser.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="Upload even when the daily listing cannot prove date completeness",
    )
    _add_common_arguments(upload_parser)

    download_parser = subparsers.add_parser(
        "download", help="Download and restore Bronze artifacts from S3"
    )
    _add_scope_arguments(download_parser)
    _add_common_arguments(download_parser)
    return parser


def _add_scope_arguments(parser: argparse.ArgumentParser) -> None:
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", "--single-date", dest="date", help="One date (YYYYMMDD)")
    scope.add_argument("--month", help="One calendar month (YYYYMM)")
    scope.add_argument("--start-date", help="First date of an inclusive range (YYYYMMDD)")
    scope.add_argument(
        "--all",
        action="store_true",
        help="Process every discoverable local date for upload or remote date for download",
    )
    parser.add_argument("--end-date", help="Last date of an inclusive range (YYYYMMDD)")


def _add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--force", action="store_true", help="Replace an existing destination")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate configuration and report planned work without changing local or S3 data",
    )


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse and validate CLI arguments."""
    parser = create_argument_parser()
    args = parser.parse_args(argv)

    try:
        # No selector means every stored date, discovered locally or remotely.
        args.scope = RunScope.from_args(
            args, allow={"date", "range", "month"}, default=RunScope.full_history()
        )
    except ScopeError as error:
        parser.error(str(error))
    return args


def resolve_dates(args: argparse.Namespace, service: BronzeS3Service) -> list[str]:
    """Resolve the explicit CLI scope into sorted date strings."""
    if args.scope.kind != "full-history":
        return args.scope.dates()
    if args.action == "upload":
        return service.list_local_dates()
    return service.list_remote_dates()


def run(args: argparse.Namespace) -> int:
    """Run independent syncs and return a process exit code."""
    client = create_s3_client()
    bronze_path = get_fotmob_historical_path(get_settings().fotmob.storage.bronze_path)
    service = BronzeS3Service(bronze_path=bronze_path, s3_client=client)
    dates = resolve_dates(args, service)
    if not dates:
        logger.error("No dates found for requested scope", action=args.action)
        return 1

    results: list[BronzeS3SyncResult] = []
    failures = 0
    for date_str in dates:
        try:
            if args.action == "upload":
                result = service.upload_date(
                    date_str,
                    force=args.force,
                    allow_incomplete=args.allow_incomplete,
                    dry_run=args.dry_run,
                )
            else:
                result = service.download_date(date_str, force=args.force, dry_run=args.dry_run)
            results.append(result)
            logger.info(
                "Bronze S3 sync date complete",
                action=result.action,
                date=result.date,
                status=result.status,
                key=result.key,
                message=result.message,
            )
        except Exception as exc:
            failures += 1
            logger.exception(
                "Bronze S3 sync date failed",
                action=args.action,
                date=date_str,
                error=str(exc),
            )

    status_counts = {}
    for result in results:
        status_counts[result.status] = status_counts.get(result.status, 0) + 1
    logger.info(
        "Bronze S3 sync summary",
        action=args.action,
        requested=len(dates),
        succeeded=len(results),
        failed=failures,
        statuses=status_counts,
        dry_run=args.dry_run,
    )
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    configure_logging()
    try:
        return run(parse_arguments(argv))
    except (BronzeS3SyncError, S3ConfigurationError, ValueError) as exc:
        logger.error("Bronze S3 sync failed", error=str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
