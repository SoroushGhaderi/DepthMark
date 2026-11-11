"""Low-level S3 client shared by the source-owned Bronze S3 workflows."""

from pathlib import Path
from typing import Any
from urllib.parse import urlparse, urlunparse

from config.settings import get_settings
from src.common.logging import get_logger

logger = get_logger(__name__)

DEFAULT_S3_REGION = "ir-tbz-sh1"
PLACEHOLDER_CREDENTIALS = frozenset(
    {
        "your_s3_access_key_here",
        "your_s3_secret_key_here",
        "your_access_key_here",
        "your_secret_key_here",
    }
)


class S3ConfigurationError(RuntimeError):
    """Raised when an S3 workflow is not fully configured."""


class S3Client:
    """Small S3-compatible object client with no Bronze workflow knowledge."""

    def __init__(
        self,
        endpoint: str,
        access_key: str,
        secret_key: str,
        bucket_name: str,
        region: str,
        client: Any | None = None,
    ) -> None:
        self.bucket_name = bucket_name
        if client is not None:
            self._client = client
            return

        try:
            import boto3
            from botocore.config import Config as BotoConfig
        except ImportError as exc:
            raise S3ConfigurationError(
                "boto3 is required for Bronze S3 sync; install project dependencies"
            ) from exc

        self._client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=BotoConfig(signature_version="s3v4", s3={"addressing_style": "virtual"}),
            region_name=region,
        )

    def object_exists(self, key: str) -> bool:
        """Return whether an object exists, preserving unexpected S3 errors."""
        try:
            self._client.head_object(Bucket=self.bucket_name, Key=key)
            return True
        except Exception as exc:
            if self._is_not_found(exc):
                return False
            raise

    def object_metadata(self, key: str) -> dict[str, Any]:
        """Return object headers and user metadata."""
        return self._client.head_object(Bucket=self.bucket_name, Key=key)

    def upload_file(self, local_path: Path, key: str, sha256: str) -> None:
        """Upload an archive with content type and checksum metadata."""
        self._client.upload_file(
            str(local_path),
            self.bucket_name,
            key,
            ExtraArgs={
                "ContentType": "application/gzip",
                "Metadata": {"sha256": sha256},
            },
        )

    def download_file(self, key: str, local_path: Path) -> None:
        """Download one object to a local path."""
        self._client.download_file(self.bucket_name, key, str(local_path))

    def list_keys(self, prefix: str) -> list[str]:
        """List all keys below a prefix, following pagination tokens."""
        keys: list[str] = []
        continuation_token: str | None = None

        while True:
            request: dict[str, Any] = {"Bucket": self.bucket_name, "Prefix": prefix}
            if continuation_token:
                request["ContinuationToken"] = continuation_token
            try:
                response = self._client.list_objects_v2(**request)
            except Exception as exc:
                if self._is_not_found(exc):
                    return keys
                raise
            keys.extend(obj["Key"] for obj in response.get("Contents", []))
            if not response.get("IsTruncated"):
                break
            continuation_token = response.get("NextContinuationToken")
            if not continuation_token:
                break

        return keys

    @staticmethod
    def _is_not_found(exc: Exception) -> bool:
        response = getattr(exc, "response", {})
        code = str(response.get("Error", {}).get("Code", ""))
        return code in {"404", "NoSuchKey", "NotFound"}


def create_s3_client() -> S3Client:
    """Build a strict S3 client from the ``S3_*`` settings.

    Raises:
        S3ConfigurationError: When the endpoint, credentials, or bucket are
            missing or still hold the ``.env.example`` placeholders.
    """
    settings = get_settings()
    endpoint = (settings.s3_endpoint or "").strip()
    access_key = (settings.s3_access_key or "").strip()
    secret_key = (settings.s3_secret_key or "").strip()
    region = (settings.s3_region or "").strip() or DEFAULT_S3_REGION
    bucket_name = (settings.s3_bucket or "").strip() or bucket_from_endpoint(endpoint)

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
    placeholders = [
        name
        for name, value in (("S3_ACCESS_KEY", access_key), ("S3_SECRET_KEY", secret_key))
        if value in PLACEHOLDER_CREDENTIALS
    ]
    if missing or placeholders:
        detail = f" Missing: {', '.join(missing)}." if missing else ""
        if placeholders:
            detail += f" Placeholder values: {', '.join(placeholders)}."
        raise S3ConfigurationError(
            "Bronze S3 transfer requires a real endpoint, credentials, and a resolvable bucket."
            + detail
        )

    return S3Client(
        service_endpoint(endpoint, bucket_name), access_key, secret_key, bucket_name, region
    )


def bucket_from_endpoint(endpoint: str) -> str:
    """Infer the bucket name from a virtual-hosted S3 endpoint."""
    host = urlparse(endpoint).netloc
    return host.split(".s3.", 1)[0] if ".s3." in host else ""


def service_endpoint(endpoint: str, bucket_name: str) -> str:
    """Convert a virtual-hosted bucket endpoint into its S3 service endpoint.

    ``boto3`` uses path-style requests for custom endpoints by default. Leaving a
    bucket name in a virtual-hosted endpoint therefore produces requests such as
    ``https://bucket.s3.example/bucket/...``. Use the provider endpoint instead
    and pass the bucket separately to keep the request target unambiguous.
    """
    parsed = urlparse(endpoint)
    hostname = parsed.hostname or ""
    virtual_host_prefix = f"{bucket_name}.s3."
    if not hostname.startswith(virtual_host_prefix):
        return endpoint

    service_host = hostname[len(bucket_name) + 1 :]
    if parsed.port:
        service_host = f"{service_host}:{parsed.port}"
    return urlunparse(parsed._replace(netloc=service_host))
