#!/usr/bin/env python3
"""Upload or download FotMob Bronze artifacts independently of scraping.

Examples:
    python3 scripts/bronze/sync_s3.py upload --date 20251208 --dry-run
    python3 scripts/bronze/sync_s3.py upload --month 202512
    python3 scripts/bronze/sync_s3.py download --start-date 20251201 --end-date 20251207
    python3 scripts/bronze/sync_s3.py download --all
"""

import argparse
import os
import sys
from pathlib import Path
from typing import List, Optional
from urllib.parse import urlparse

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import FotMobConfig
from scripts.utils import generate_date_range, generate_month_dates, validate_date_format
from src.services.bronze import BronzeS3Service, BronzeS3SyncError, BronzeS3SyncResult
from src.storage import S3Client, S3ConfigurationError
from src.storage.bronze.paths import get_fotmob_historical_path
from src.utils.logging_utils import configure_logging, get_logger

logger = get_logger(__name__)

DEFAULT_S3_REGION = "ir-tbz-sh1"


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


def parse_arguments(argv: Optional[List[str]] = None) -> argparse.Namespace:
    """Parse and validate CLI arguments."""
    parser = create_argument_parser()
    args = parser.parse_args(argv)

    if args.start_date and not args.end_date:
        parser.error("--end-date is required with --start-date")
    if args.end_date and not args.start_date:
        parser.error("--end-date can only be used with --start-date")

    if args.date:
        _validate_date(parser, args.date)
    if args.month:
        is_valid, error = validate_date_format(args.month, "YYYYMM")
        if not is_valid:
            parser.error(error)
    if args.start_date:
        _validate_date(parser, args.start_date)
        _validate_date(parser, args.end_date)
        if args.end_date < args.start_date:
            parser.error("--end-date cannot be before --start-date")
    return args


def _validate_date(parser: argparse.ArgumentParser, date_str: str) -> None:
    is_valid, error = validate_date_format(date_str, "YYYYMMDD")
    if not is_valid:
        parser.error(error)


def load_environment() -> None:
    """Load project and parent environment files without overriding process values."""
    load_dotenv(PROJECT_ROOT / ".env", override=False)
    load_dotenv(PROJECT_ROOT.parent / ".env", override=False)


def create_s3_client() -> S3Client:
    """Build a strict S3 client from environment configuration."""
    endpoint = os.getenv("S3_ENDPOINT", "").strip()
    access_key = os.getenv("S3_ACCESS_KEY", "").strip()
    secret_key = os.getenv("S3_SECRET_KEY", "").strip()
    region = os.getenv("S3_REGION", DEFAULT_S3_REGION).strip() or DEFAULT_S3_REGION
    bucket_name = os.getenv("S3_BUCKET", "").strip() or _bucket_from_endpoint(endpoint)

    missing = [
        name
        for name, value in (
            ("S3_ENDPOINT", endpoint),
            ("S3_ACCESS_KEY", access_key),
            ("S3_SECRET_KEY", secret_key),
            ("S3_BUCKET", bucket_name),
        )
        if not value
    ]
    placeholder_values = {
        "your_s3_access_key_here",
        "your_s3_secret_key_here",
        "your_access_key_here",
        "your_secret_key_here",
    }
    if missing or access_key in placeholder_values or secret_key in placeholder_values:
        detail = f" Missing: {', '.join(missing)}." if missing else ""
        raise S3ConfigurationError(
            "Bronze S3 sync requires real endpoint, credentials, and a resolvable bucket." + detail
        )

    return S3Client(endpoint, access_key, secret_key, bucket_name, region)


def _bucket_from_endpoint(endpoint: str) -> str:
    host = urlparse(endpoint).netloc
    return host.split(".s3.", 1)[0] if ".s3." in host else ""


def resolve_dates(args: argparse.Namespace, service: BronzeS3Service) -> List[str]:
    """Resolve the explicit CLI scope into sorted date strings."""
    if args.date:
        return [args.date]
    if args.month:
        return generate_month_dates(args.month)
    if args.start_date:
        return generate_date_range(args.start_date, args.end_date)
    if args.action == "upload":
        return service.list_local_dates()
    return service.list_remote_dates()


def run(args: argparse.Namespace) -> int:
    """Run independent syncs and return a process exit code."""
    load_environment()
    client = create_s3_client()
    bronze_path = get_fotmob_historical_path(FotMobConfig().storage.bronze_path)
    service = BronzeS3Service(bronze_path=bronze_path, s3_client=client)
    dates = resolve_dates(args, service)
    if not dates:
        logger.error("No dates found for requested scope", action=args.action)
        return 1

    results: List[BronzeS3SyncResult] = []
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
            logger.error(
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


def main(argv: Optional[List[str]] = None) -> int:
    """CLI entry point."""
    configure_logging()
    try:
        return run(parse_arguments(argv))
    except (BronzeS3SyncError, S3ConfigurationError, ValueError) as exc:
        logger.error("Bronze S3 sync failed", error=str(exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
