"""Shared pytest fixtures."""

import pytest

from config.settings import reset_settings


@pytest.fixture(autouse=True)
def fresh_settings():
    """Rebuild settings around each test so environment changes take effect."""
    reset_settings()
    yield
    reset_settings()
