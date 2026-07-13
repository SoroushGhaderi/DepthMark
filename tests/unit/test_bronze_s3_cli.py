"""Unit tests for standalone Bronze S3 CLI configuration."""

from scripts.bronze.sync_s3 import _bucket_from_endpoint, _service_endpoint


def test_virtual_hosted_endpoint_is_normalized_to_service_endpoint() -> None:
    endpoint = "https://scout-sport.s3.ir-tbz-sh1.arvanstorage.ir"

    assert _bucket_from_endpoint(endpoint) == "scout-sport"
    assert _service_endpoint(endpoint, "scout-sport") == "https://s3.ir-tbz-sh1.arvanstorage.ir"


def test_non_virtual_hosted_endpoint_is_not_changed() -> None:
    endpoint = "https://s3.ir-tbz-sh1.arvanstorage.ir"

    assert _service_endpoint(endpoint, "scout-sport") == endpoint
