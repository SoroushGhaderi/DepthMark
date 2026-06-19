"""Regression tests for post-scrape local Bronze compression."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from src.core import OrchestratorError
from src.orchestrator import FotMobOrchestrator


def build_orchestrator(compression_status: str = "success") -> FotMobOrchestrator:
    """Build an orchestrator with all network and filesystem boundaries mocked."""
    orchestrator = FotMobOrchestrator.__new__(FotMobOrchestrator)
    orchestrator.config = SimpleNamespace(enable_parallel=False)
    orchestrator.logger = MagicMock()
    orchestrator.bronze_only = True
    orchestrator.telegram_client = MagicMock()
    orchestrator.bronze_storage = MagicMock()
    orchestrator.bronze_storage.health_check.return_value = {
        "overall_status": "HEALTHY",
        "checks": [],
    }
    orchestrator.bronze_storage.get_completion_percentage.return_value = 100.0
    orchestrator.bronze_storage.is_match_complete.return_value = False
    orchestrator.bronze_storage.compress_date_files.return_value = {
        "status": compression_status,
        "compressed": 1 if compression_status == "success" else 0,
        "archive_file": "data/fotmob/historical/matches/20251208/20251208_matches.tar",
        "error": "disk full" if compression_status == "error" else "",
    }
    orchestrator._fetch_match_ids = MagicMock(return_value=[101])
    orchestrator._scrape_matches_parallel = MagicMock()
    orchestrator._scrape_matches_sequential = MagicMock()
    return orchestrator


def test_complete_cached_date_is_compressed() -> None:
    orchestrator = build_orchestrator()

    metrics = orchestrator.scrape_date("20251208")

    assert metrics.skipped_matches == 1
    orchestrator.bronze_storage.compress_date_files.assert_called_once_with("20251208", force=False)


def test_force_rescrape_rebuilds_archive() -> None:
    orchestrator = build_orchestrator()

    def record_success(match_ids, metrics, date_str, scraped_match_ids):
        del date_str, scraped_match_ids
        for match_id in match_ids:
            metrics.record_success(match_id)

    orchestrator._scrape_matches_sequential.side_effect = record_success

    metrics = orchestrator.scrape_date("20251208", force_rescrape=True)

    assert metrics.successful_matches == 1
    orchestrator._scrape_matches_sequential.assert_called_once()
    orchestrator.bronze_storage.compress_date_files.assert_called_once_with("20251208", force=True)


def test_compression_failure_fails_the_date() -> None:
    orchestrator = build_orchestrator(compression_status="error")

    with pytest.raises(OrchestratorError, match="Bronze compression failed"):
        orchestrator.scrape_date("20251208")


def test_partial_date_is_not_compressed() -> None:
    orchestrator = build_orchestrator()
    orchestrator.bronze_storage.get_completion_percentage.return_value = 0.0

    def record_failure(match_ids, metrics, date_str, scraped_match_ids):
        del date_str, scraped_match_ids
        for match_id in match_ids:
            metrics.record_failure(match_id, "request failed")

    orchestrator._scrape_matches_sequential.side_effect = record_failure

    orchestrator.scrape_date("20251208")

    orchestrator.bronze_storage.compress_date_files.assert_not_called()
