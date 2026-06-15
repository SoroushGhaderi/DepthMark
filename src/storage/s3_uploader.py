"""S3 Uploader for Bronze Layer Backup.

This module provides functionality to:
1. Create tar archives of bronze layer data
2. Upload to S3 (Arvan Cloud) with proper naming convention

Naming convention: {scraper}/YYYYMM/YYYYMMDD.tar.gz
Example: fotmob/202509/20250901.tar.gz
"""

import os
import tarfile
import tempfile
from pathlib import Path
from typing import List, Optional
from urllib.parse import urlparse

from ..utils.logging_utils import get_logger

try:
    import boto3
    from botocore.config import Config as BotoConfig

    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

logger = get_logger(__name__)


class S3Uploader:
    """S3 Uploader for bronze layer data."""

    def __init__(self, endpoint: str, access_key: str, secret_key: str, bucket_name: str):
        """Initialize S3 uploader."""
        self.logger = logger
        self.endpoint = endpoint
        self.access_key = access_key
        self.secret_key = secret_key
        self.bucket_name = bucket_name

        if not BOTO3_AVAILABLE:
            self.logger.warning("boto3 not installed, S3 upload will be disabled")
            self.s3_client = None
            return

        self.s3_client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=BotoConfig(signature_version="s3v4"),
            region_name="ir-tbz-sh1",
        )
        self.logger.info(f"S3 uploader initialized for bucket: {bucket_name}")

    def list_existing_dates(self, scraper_name: str, year_month: str) -> List[str]:
        """List dates already uploaded for a given month."""
        if not self.s3_client:
            return []

        try:
            prefix = f"bronze/{scraper_name}/{year_month}/"
            response = self.s3_client.list_objects_v2(Bucket=self.bucket_name, Prefix=prefix)
            if response.get("Contents"):
                return [
                    obj["Key"].split("/")[-1].replace(".tar.gz", "") for obj in response["Contents"]
                ]
        except Exception as e:
            # Arvan Cloud returns NoSuchKey (instead of an empty response) when no
            # objects exist under the prefix yet. Treat it as "nothing uploaded".
            try:
                from botocore.exceptions import ClientError

                if isinstance(e, ClientError) and e.response["Error"]["Code"] == "NoSuchKey":
                    return []
            except Exception:
                pass
            self.logger.warning(f"Failed to list existing objects: {e}")

        return []

    def object_exists(self, s3_key: str) -> bool:
        """Return True if the object already exists in the bucket."""
        if not self.s3_client:
            return False
        try:
            self.s3_client.head_object(Bucket=self.bucket_name, Key=s3_key)
            return True
        except Exception as e:
            try:
                from botocore.exceptions import ClientError

                if isinstance(e, ClientError) and e.response["Error"]["Code"] in (
                    "404",
                    "NoSuchKey",
                ):
                    return False
            except Exception:
                pass
            self.logger.warning(f"Could not check object existence for {s3_key}: {e}")
            return False

    def get_object_size(self, s3_key: str) -> Optional[int]:
        """Return the size of the object in bytes, or None if not found."""
        if not self.s3_client:
            return None
        try:
            response = self.s3_client.head_object(Bucket=self.bucket_name, Key=s3_key)
            return response.get("ContentLength", 0)
        except Exception as e:
            try:
                from botocore.exceptions import ClientError

                if isinstance(e, ClientError) and e.response["Error"]["Code"] in (
                    "404",
                    "NoSuchKey",
                ):
                    return None
            except Exception:
                pass
            self.logger.warning(f"Could not get object size for {s3_key}: {e}")
            return None

    def create_tar_and_upload(self, source_dir: str, date_str: str, scraper_name: str) -> bool:
        """Create tar archive and upload to S3 in one operation.

        Args:
            source_dir: Source directory containing bronze data
            date_str: Date string (YYYYMMDD)
            scraper_name: Name of scraper (fotmob)

        Returns:
            True if successful, False otherwise
        """
        if not self.s3_client:
            self.logger.error("S3 client not initialized")
            return False

        try:
            year_month = date_str[:6]
            tar_filename = f"{date_str}.tar.gz"
            s3_key = f"bronze/{scraper_name}/{year_month}/{date_str}.tar.gz"

            source_path = Path(source_dir)
            if not source_path.exists():
                self.logger.warning(f"Source directory does not exist: {source_dir}")
                return False

            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                tar_path = temp_path / tar_filename

                self.logger.info(f"Creating tar archive: {tar_filename}")

                with tarfile.open(tar_path, "w:gz") as tar:
                    tar.add(source_path, arcname=date_str)

                self.logger.info("Tar archive created, uploading to S3...")

                self.s3_client.upload_file(
                    str(tar_path),
                    self.bucket_name,
                    s3_key,
                    ExtraArgs={"ContentType": "application/gzip"},
                )
                self.logger.info(f"Uploaded to S3: {s3_key}")
                return True

        except Exception as e:
            self.logger.error(f"Failed to create and upload tar archive: {e}")
            return False

    def upload_bronze_backup(self, bronze_dir: str, date_str: str, scraper_name: str) -> bool:
        """Create and upload bronze layer backup for a specific date.

        Saves as: bronze/{scraper}/YYYYMM/YYYYMMDD.tar.gz

        Args:
            bronze_dir: Bronze layer directory path (e.g., data/fotmob/matches/20250901)
            date_str: Date string (YYYYMMDD)
            scraper_name: Name of scraper (fotmob)

        Returns:
            True if successful, False otherwise
        """
        year_month = date_str[:6]
        s3_key = f"bronze/{scraper_name}/{year_month}/{date_str}.tar.gz"

        if self.object_exists(s3_key):
            self.logger.info(f"S3 backup already exists, skipping: {s3_key}")
            return True

        self.logger.info(f"Starting bronze backup upload for {scraper_name} on {date_str}")
        return self.create_tar_and_upload(bronze_dir, date_str, scraper_name)


def resolve_s3_bucket_name(endpoint: str) -> Optional[str]:
    """Resolve the S3 bucket name from env or virtual-hosted endpoint URL."""
    bucket_name = os.getenv("S3_BUCKET")
    if bucket_name:
        return bucket_name

    host = urlparse(endpoint).netloc
    if ".s3." in host:
        return host.split(".s3.", 1)[0]

    return None


def get_s3_uploader() -> Optional[S3Uploader]:
    """Get S3 uploader instance from environment variables."""
    endpoint = os.getenv("S3_ENDPOINT")
    access_key = os.getenv("S3_ACCESS_KEY")
    secret_key = os.getenv("S3_SECRET_KEY")

    if not all([endpoint, access_key, secret_key]):
        logger.warning("S3 not fully configured, skipping upload")
        return None

    if access_key == "your_access_key_here":
        logger.warning("S3 credentials not configured, skipping upload")
        return None

    bucket_name = resolve_s3_bucket_name(endpoint)
    if not bucket_name:
        logger.warning(
            "S3 bucket could not be resolved; set S3_BUCKET or use a virtual-hosted "
            "endpoint URL (e.g. https://my-bucket.s3.region.provider.com)"
        )
        return None

    return S3Uploader(
        endpoint=endpoint,
        access_key=access_key,
        secret_key=secret_key,
        bucket_name=bucket_name,
    )
