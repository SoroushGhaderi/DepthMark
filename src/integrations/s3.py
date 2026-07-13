"""Low-level S3 client used by the standalone Bronze sync workflow."""

from pathlib import Path
from typing import Any, Dict, List, Optional

from src.common.logging import get_logger

logger = get_logger(__name__)


class S3ConfigurationError(RuntimeError):
    """Raised when the standalone S3 workflow is not fully configured."""


class S3Client:
    """Small S3-compatible object client with no Bronze workflow knowledge."""

    def __init__(
        self,
        endpoint: str,
        access_key: str,
        secret_key: str,
        bucket_name: str,
        region: str,
        client: Optional[Any] = None,
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

    def object_metadata(self, key: str) -> Dict[str, Any]:
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

    def list_keys(self, prefix: str) -> List[str]:
        """List all keys below a prefix, following pagination tokens."""
        keys: List[str] = []
        continuation_token: Optional[str] = None

        while True:
            request: Dict[str, Any] = {"Bucket": self.bucket_name, "Prefix": prefix}
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
