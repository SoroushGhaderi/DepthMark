"""CLI contract tests for Live and Historical FotMob scraping."""

from argparse import Namespace
from datetime import date
from unittest.mock import Mock

import pytest

from scripts.bronze.scrape_fotmob import create_date_info, parse_arguments, process_single_date

TODAY = date(2026, 6, 19)


def test_today_resolves_machine_local_date() -> None:
    args = parse_arguments(["--today"], current_date=TODAY)

    date_info = create_date_info(args, current_date=TODAY)

    assert date_info.dates == ["20260619"]
    assert date_info.mode_text == "Live (--today)"


def test_yesterday_resolves_completed_historical_date() -> None:
    args = parse_arguments(["--yesterday"], current_date=TODAY)

    assert create_date_info(args, current_date=TODAY).dates == ["20260618"]


def test_current_month_excludes_today_and_future_dates() -> None:
    args = parse_arguments(["--month", "202606"], current_date=TODAY)

    dates = create_date_info(args, current_date=TODAY).dates

    assert dates[0] == "20260601"
    assert dates[-1] == "20260618"
    assert len(dates) == 18


def test_current_month_is_successful_empty_scope_on_first_day() -> None:
    first_day = date(2026, 6, 1)
    args = parse_arguments(["--month", "202606"], current_date=first_day)

    assert create_date_info(args, current_date=first_day).dates == []


@pytest.mark.parametrize(
    "argv",
    [
        ["20260619"],
        ["20260618", "20260619"],
        ["20260618", "--days", "2"],
        ["--month", "202607"],
        ["--today", "--force"],
    ],
)
def test_invalid_live_or_future_historical_scopes_fail(argv: list[str]) -> None:
    with pytest.raises(SystemExit):
        parse_arguments(argv, current_date=TODAY)


def test_today_forces_refresh_and_disables_compression() -> None:
    orchestrator = Mock()
    orchestrator.scrape_date.return_value = object()
    args = Namespace(today=True, force=False)

    result = process_single_date("20260619", orchestrator, args, Mock(), 1, 1)

    assert result is orchestrator.scrape_date.return_value
    orchestrator.scrape_date.assert_called_once_with(
        date_str="20260619",
        force_rescrape=True,
        force_refetch_listing=True,
        compress_completed=False,
    )
