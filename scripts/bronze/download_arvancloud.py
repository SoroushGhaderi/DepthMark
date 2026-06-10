"""Download Bronze layer data from ArvanCloud S3-compatible storage.

The existing S3 backup convention stores daily Bronze archives as:
    bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz

This script restores those archives into the local project hierarchy:
    data/fotmob/matches/YYYYMMDD

It can also download non-archive objects under the configured prefix while
preserving their relative path under data/fotmob.

Usage:
    python scripts/bronze/download_arvancloud.py
    python scripts/bronze/download_arvancloud.py --prefix bronze/fotmob/202505/
    python scripts/bronze/download_arvancloud.py --dry-run
"""

from __future__ import annotations

from dotenv import load_dotenv

load_dotenv()

import argparse
import logging
import os
import re
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

try:
    import boto3
    from botocore.config import Config as BotoConfig
except ImportError as exc:  # pragma: no cover - exercised by runtime environment
    raise SystemExit(
        "boto3 is required. Install project dependencies with: pip install -r requirements.txt"
    ) from exc

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

logger = logging.getLogger(__name__)

DEFAULT_ENDPOINT = "https://s3.ir-tbz-sh1.arvanstorage.ir"
DEFAULT_BUCKET = "scout-sport"
DEFAULT_PREFIX = "depthmark-sport/bronze/fotmob/"
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "data" / "fotmob"
ARCHIVE_KEY_RE = re.compile(
    r"^(?:[^/]+/)?bronze/fotmob/(?P<year_month>\d{6})/(?P<date>\d{8})\.tar\.gz$"
)


@dataclass(frozen=True)
class DownloadStats:
    """Summary counters for an ArvanCloud download run."""

    scanned: int = 0
    downloaded: int = 0
    extracted: int = 0
    skipped: int = 0
    failed: int = 0

    def add(
        self,
        scanned: int = 0,
        downloaded: int = 0,
        extracted: int = 0,
        skipped: int = 0,
        failed: int = 0,
    ) -> "DownloadStats":
        return DownloadStats(
            scanned=self.scanned + scanned,
            downloaded=self.downloaded + downloaded,
            extracted=self.extracted + extracted,
            skipped=self.skipped + skipped,
            failed=self.failed + failed,
        )


def create_parser() -> argparse.ArgumentParser:
    """Create CLI parser."""
    parser = argparse.ArgumentParser(
        description="Download DepthMark Bronze data from ArvanCloud object storage."
    )
    parser.add_argument(
        "--endpoint",
        default=os.getenv("S3_ENDPOINT", DEFAULT_ENDPOINT),
        help="S3-compatible endpoint URL.",
    )
    parser.add_argument(
        "--bucket",
        default=os.getenv("S3_BUCKET", DEFAULT_BUCKET),
        help="Bucket name.",
    )
    parser.add_argument(
        "--access-key",
        default=os.getenv("S3_ACCESS_KEY"),
        help="Access key. Defaults to S3_ACCESS_KEY from .env.",
    )
    parser.add_argument(
        "--secret-key",
        default=os.getenv("S3_SECRET_KEY"),
        help="Secret key. Defaults to S3_SECRET_KEY from .env.",
    )
    parser.add_argument(
        "--prefix",
        nargs="?",
        const="",
        default=os.getenv("S3_BRONZE_PREFIX", DEFAULT_PREFIX),
        help="Object prefix to download.",
    )
    parser.add_argument(
        "--output-root",
        default=str(DEFAULT_OUTPUT_ROOT),
        help="Local Bronze scraper root. Defaults to data/fotmob.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing downloaded files and extracted date directories.",
    )
    parser.add_argument("--dry-run", action="store_true", help="List planned work only.")
    parser.add_argument("--limit", type=int, help="Maximum number of objects to process.")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging.")
    return parser


def validate_args(args: argparse.Namespace) -> None:
    """Validate required S3 credentials."""
    missing = [
        name
        for name, value in (
            ("S3_ACCESS_KEY", args.access_key),
            ("S3_SECRET_KEY", args.secret_key),
        )
        if not value
    ]
    if missing:
        raise SystemExit(
            "Missing required credentials: "
            + ", ".join(missing)
            + ". Put them in .env or pass --access-key/--secret-key."
        )

    if args.limit is not None and args.limit < 1:
        raise SystemExit("--limit must be at least 1")


def create_s3_client(args: argparse.Namespace):
    """Create an S3-compatible client for ArvanCloud."""
    return boto3.client(
        "s3",
        endpoint_url=args.endpoint,
        aws_access_key_id=args.access_key,
        aws_secret_access_key=args.secret_key,
        config=BotoConfig(signature_version="s3v4"),
        region_name="ir-tbz-sh1",
    )


def iter_object_keys(s3_client, bucket: str, prefix: str, limit: Optional[int]) -> Iterable[str]:
    """Yield object keys under a prefix."""
    paginator = s3_client.get_paginator("list_objects_v2")
    count = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue
            yield key
            count += 1
            if limit and count >= limit:
                return


def safe_extract_tar(tar_path: Path, destination: Path) -> int:
    """Extract tar archive while blocking path traversal."""
    destination = destination.resolve()
    extracted = 0
    with tarfile.open(tar_path, "r:gz") as tar:
        for member in tar.getmembers():
            target = (destination / member.name).resolve()
            if not str(target).startswith(str(destination)):
                raise ValueError(f"Unsafe tar member path: {member.name}")
        tar.extractall(destination)
        extracted = len(tar.getmembers())
    return extracted


def restore_archive(s3_client, bucket: str, key: str, output_root: Path, force: bool, dry_run: bool) -> str:
    """Download and extract a daily Bronze tar archive."""
    match = ARCHIVE_KEY_RE.match(key)
    if not match:
        raise ValueError(f"Archive key does not match expected convention: {key}")

    date_str = match.group("date")
    target_dir = output_root / "matches" / date_str
    if target_dir.exists() and not force:
        logger.info("Skipping existing archive target: %s", target_dir)
        return "skipped"

    logger.info("Restoring archive %s -> %s", key, target_dir)
    if dry_run:
        return "extracted"

    output_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp_dir:
        archive_path = Path(temp_dir) / Path(key).name
        s3_client.download_file(bucket, key, str(archive_path))
        safe_extract_tar(archive_path, output_root / "matches")
    return "extracted"


def destination_for_key(key: str, prefix: str, output_root: Path) -> Path:
    """Map a non-archive S3 key to the local Bronze hierarchy."""
    normalized_prefix = prefix.rstrip("/") + "/"
    if key.startswith("depthmark-sport/bronze/fotmob/"):
        relative = key.removeprefix("depthmark-sport/bronze/fotmob/")
    elif key.startswith("bronze/fotmob/"):
        relative = key.removeprefix("bronze/fotmob/")
    elif key.startswith(normalized_prefix):
        relative = key.removeprefix(normalized_prefix)
    else:
        relative = key
    return output_root / relative


def download_object(
    s3_client,
    bucket: str,
    key: str,
    prefix: str,
    output_root: Path,
    force: bool,
    dry_run: bool,
) -> str:
    """Download a single non-archive object."""
    destination = destination_for_key(key, prefix, output_root)
    if destination.exists() and not force:
        logger.info("Skipping existing file: %s", destination)
        return "skipped"

    logger.info("Downloading %s -> %s", key, destination)
    if dry_run:
        return "downloaded"

    destination.parent.mkdir(parents=True, exist_ok=True)
    s3_client.download_file(bucket, key, str(destination))
    return "downloaded"


def process_key(
    s3_client,
    bucket: str,
    key: str,
    prefix: str,
    output_root: Path,
    force: bool,
    dry_run: bool,
) -> str:
    """Process one S3 object key."""
    if ARCHIVE_KEY_RE.match(key):
        return restore_archive(s3_client, bucket, key, output_root, force, dry_run)
    return download_object(s3_client, bucket, key, prefix, output_root, force, dry_run)


def run(args: argparse.Namespace) -> int:
    """Run the download workflow."""
    validate_args(args)
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        force=True,
    )

    output_root = Path(args.output_root).resolve()
    s3_client = create_s3_client(args)
    stats = DownloadStats()

    logger.info("Downloading ArvanCloud Bronze data")
    logger.info("Endpoint: %s", args.endpoint)
    logger.info("Bucket:   %s", args.bucket)
    logger.info("Prefix:   %s", args.prefix)
    logger.info("Output:   %s", output_root)

    for key in iter_object_keys(s3_client, args.bucket, args.prefix, args.limit):
        stats = stats.add(scanned=1)
        try:
            result = process_key(
                s3_client=s3_client,
                bucket=args.bucket,
                key=key,
                prefix=args.prefix,
                output_root=output_root,
                force=args.force,
                dry_run=args.dry_run,
            )
            if result == "extracted":
                stats = stats.add(extracted=1)
            elif result == "downloaded":
                stats = stats.add(downloaded=1)
            elif result == "skipped":
                stats = stats.add(skipped=1)
        except Exception as exc:
            stats = stats.add(failed=1)
            logger.error("Failed to process %s: %s", key, exc, exc_info=args.debug)

    logger.info(
        "Done. scanned=%s downloaded=%s extracted=%s skipped=%s failed=%s",
        stats.scanned,
        stats.downloaded,
        stats.extracted,
        stats.skipped,
        stats.failed,
    )
    return 1 if stats.failed else 0


def main() -> int:
    """CLI entry point."""
    args = create_parser().parse_args()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
