"""Tests for Gold signal job selection from the validated signal catalog."""

from dataclasses import replace

import pytest

from src.fotmob.commands import run_gold_jobs as run_fotmob_gold_jobs
from src.fotmob.gold import service as gold_service
from src.fotmob.gold.dml_runner import discover_gold_sql_jobs, resolve_gold_sql_job
from src.fotmob.gold.service import GoldService
from src.fotmob.gold.signal_catalog import (
    CatalogViolation,
    SignalCatalog,
    SignalCatalogError,
    load_signal_catalog,
)
from src.warehouse.scope import WarehouseExecutionScope

DEPRECATED_SIGNAL = "sig_match_shooting_goals_goal_fest"


@pytest.fixture(scope="module")
def catalog_with_deprecated_signal() -> SignalCatalog:
    catalog = load_signal_catalog()
    definitions = tuple(
        replace(definition, status="deprecated")
        if definition.signal_id == DEPRECATED_SIGNAL
        else definition
        for definition in catalog
    )
    return SignalCatalog(definitions=definitions, catalog_dir=catalog.catalog_dir)


def _invalid_catalog(*_args, **_kwargs):
    raise SignalCatalogError([CatalogViolation("catalogs/sig_x.md", "broken")])


def test_signal_jobs_are_the_active_catalog_signals(catalog_with_deprecated_signal) -> None:
    jobs = discover_gold_sql_jobs(
        "signal", target_db="gold_signals", signal_catalog=catalog_with_deprecated_signal
    )

    job_ids = [job.job_id for job in jobs]
    assert len(job_ids) == 343
    assert DEPRECATED_SIGNAL not in job_ids
    assert job_ids == sorted(job_ids)
    assert jobs[0].sql_file == catalog_with_deprecated_signal.get(job_ids[0]).sql_path


def test_signal_jobs_filter_by_entity_and_family(catalog_with_deprecated_signal) -> None:
    match_jobs = discover_gold_sql_jobs(
        "signal", entity="match", signal_catalog=catalog_with_deprecated_signal
    )
    family_jobs = discover_gold_sql_jobs(
        "signal", family="shooting_goals", signal_catalog=catalog_with_deprecated_signal
    )

    assert all(job.job_id.startswith("sig_match_") for job in match_jobs)
    assert len(match_jobs) == 92
    assert all("_shooting_goals_" in job.job_id for job in family_jobs)
    assert DEPRECATED_SIGNAL not in [job.job_id for job in family_jobs]


def test_selecting_a_deprecated_signal_is_an_error(catalog_with_deprecated_signal) -> None:
    with pytest.raises(ValueError, match="is deprecated and does not run in Gold"):
        resolve_gold_sql_job(
            "signal", DEPRECATED_SIGNAL, signal_catalog=catalog_with_deprecated_signal
        )


def test_selecting_an_uncatalogued_signal_is_an_error(catalog_with_deprecated_signal) -> None:
    with pytest.raises(ValueError, match="has no catalog"):
        resolve_gold_sql_job(
            "signal",
            "sig_match_shooting_goals_unknown",
            signal_catalog=catalog_with_deprecated_signal,
        )


def test_gold_load_fails_on_invalid_catalog_before_any_job(monkeypatch) -> None:
    monkeypatch.setattr(gold_service, "load_signal_catalog", _invalid_catalog)

    def unexpected_jobs(*_args, **_kwargs):
        raise AssertionError("Gold jobs must not run with an invalid catalog")

    monkeypatch.setattr(GoldService, "run_selected_jobs", unexpected_jobs)

    result = GoldService(client=None, metadata_db="gold").run(
        scope=WarehouseExecutionScope.for_date("20251208"), part="signals", dry_run=True
    )

    assert result.exit_code == 1


def test_gold_scenarios_do_not_need_the_signal_catalog(monkeypatch) -> None:
    monkeypatch.setattr(gold_service, "load_signal_catalog", _invalid_catalog)

    result = GoldService(client=None, metadata_db="gold").run(
        scope=WarehouseExecutionScope.for_date("20251208"), part="scenarios", dry_run=True
    )

    assert result.exit_code == 0


def test_job_runner_fails_on_invalid_catalog(monkeypatch) -> None:
    monkeypatch.setattr(run_fotmob_gold_jobs, "load_signal_catalog", _invalid_catalog)

    assert run_fotmob_gold_jobs.main(["--date", "20251208", "--kind", "signal", "--dry-run"]) == 1


def test_job_runner_rejects_a_deprecated_signal(
    monkeypatch, catalog_with_deprecated_signal
) -> None:
    monkeypatch.setattr(
        run_fotmob_gold_jobs, "load_signal_catalog", lambda: catalog_with_deprecated_signal
    )

    arguments = ["--date", "20251208", "--id", DEPRECATED_SIGNAL, "--dry-run"]
    assert run_fotmob_gold_jobs.main(arguments) == 2
