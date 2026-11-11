"""Unit tests for the shared Bronze S3 client configuration."""

import pytest

from src.integrations.s3 import (
    S3ConfigurationError,
    bucket_from_endpoint,
    create_s3_client,
    service_endpoint,
)


def test_virtual_hosted_endpoint_is_normalized_to_service_endpoint() -> None:
    endpoint = "https://scout-sport.s3.ir-tbz-sh1.arvanstorage.ir"

    assert bucket_from_endpoint(endpoint) == "scout-sport"
    assert service_endpoint(endpoint, "scout-sport") == "https://s3.ir-tbz-sh1.arvanstorage.ir"


def test_non_virtual_hosted_endpoint_is_not_changed() -> None:
    endpoint = "https://s3.ir-tbz-sh1.arvanstorage.ir"

    assert service_endpoint(endpoint, "scout-sport") == endpoint


def test_missing_credentials_name_every_missing_setting(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("S3_ENDPOINT", "S3_ACCESS_KEY", "S3_SECRET_KEY", "S3_BUCKET"):
        monkeypatch.setenv(name, "")

    with pytest.raises(S3ConfigurationError) as error:
        create_s3_client()

    message = str(error.value)
    for name in ("S3_ENDPOINT", "S3_ACCESS_KEY", "S3_SECRET_KEY", "S3_BUCKET"):
        assert name in message


def test_placeholder_credentials_are_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("S3_ENDPOINT", "https://scout-sport.s3.ir-tbz-sh1.arvanstorage.ir")
    monkeypatch.setenv("S3_ACCESS_KEY", "your_s3_access_key_here")
    monkeypatch.setenv("S3_SECRET_KEY", "your_s3_secret_key_here")
    monkeypatch.setenv("S3_BUCKET", "")

    with pytest.raises(S3ConfigurationError, match="Placeholder values"):
        create_s3_client()
