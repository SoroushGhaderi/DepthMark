"""Table-driven contract tests for RunScope, the one CLI date-scope parser."""

import argparse
from datetime import date

import pytest

from src.common.run_scope import (
    RunScope,
    ScopeError,
    add_scope_arguments,
    resolve_date_scope,
)
from src.warehouse.scope import WarehouseExecutionScope

TODAY = date(2026, 8, 12)


def _args(**values) -> argparse.Namespace:
    defaults = {
        "date": None,
        "start_date": None,
        "end_date": None,
        "month": None,
        "full_history": False,
    }
    defaults.update(values)
    return argparse.Namespace(**defaults)


@pytest.mark.parametrize(
    ("values", "kind", "label", "dates"),
    [
        ({"date": "20260301"}, "date", "20260301", ["20260301"]),
        ({"single_date": "20260301"}, "date", "20260301", ["20260301"]),
        (
            {"start_date": "20260228", "end_date": "20260302"},
            "range",
            "20260228-20260302",
            ["20260228", "20260301", "20260302"],
        ),
        ({"month": "202602"}, "month", "202602", [f"202602{day:02d}" for day in range(1, 29)]),
        ({"full_history": True}, "full-history", "full-history", []),
    ],
)
def test_selectors_build_and_expand_one_scope(values, kind, label, dates) -> None:
    scope = RunScope.from_args(_args(**values))

    assert (scope.kind, scope.label, scope.dates()) == (kind, label, dates)


@pytest.mark.parametrize(
    ("values", "message"),
    [
        ({}, "is required"),
        ({"date": "20260301", "month": "202603"}, "choose only one"),
        ({"date": "2026-03-01"}, "Invalid date '2026-03-01'; expected YYYYMMDD"),
        ({"date": "20260230"}, "expected YYYYMMDD"),
        ({"month": "202613"}, "Invalid month '202613'; expected YYYYMM"),
        ({"start_date": "20260301"}, "--end-date is required with --start-date"),
        ({"end_date": "20260301"}, "--end-date can only be used with --start-date"),
        ({"start_date": "20260303", "end_date": "20260301"}, "cannot be before"),
    ],
)
def test_invalid_selectors_fail_with_one_message(values, message) -> None:
    with pytest.raises(ScopeError, match=message):
        RunScope.from_args(_args(**values))


def test_commands_reject_selectors_they_do_not_allow() -> None:
    with pytest.raises(ScopeError, match="--start-date/--end-date is not supported here"):
        RunScope.from_args(
            _args(start_date="20260301", end_date="20260302"), allow={"date", "month"}
        )


def test_default_applies_only_without_a_selector() -> None:
    default = RunScope.full_history()

    assert RunScope.from_args(_args(), default=default) is default
    assert RunScope.from_args(_args(date="20260301"), default=default).kind == "date"


@pytest.mark.parametrize(
    ("scope", "expected"),
    [
        (RunScope.for_month("202608"), ["20260810", "20260811", "20260812"]),
        (RunScope.for_month("202607"), [f"202607{day:02d}" for day in range(1, 32)]),
    ],
)
def test_through_clips_only_the_month_containing_it(scope, expected) -> None:
    assert scope.dates(through=TODAY)[-len(expected) :] == expected


@pytest.mark.parametrize(
    ("scope", "message"),
    [
        (RunScope.for_date("20260813"), "future dates"),
        (RunScope.for_range("20260810", "20260813"), "future dates"),
        (RunScope.for_month("202609"), "future months"),
    ],
)
def test_through_rejects_future_dates(scope, message) -> None:
    with pytest.raises(ScopeError, match=message):
        scope.dates(through=TODAY)


@pytest.mark.parametrize(
    ("scope", "kind", "value"),
    [
        (RunScope.for_date("20251208"), "date", "20251208"),
        (RunScope.for_month("202512"), "month", "202512"),
        (RunScope.full_history(), "full-history", None),
    ],
)
def test_warehouse_scope_maps_partition_scopes(scope, kind, value) -> None:
    warehouse = WarehouseExecutionScope.from_run_scope(scope)

    assert (warehouse.kind, warehouse.value) == (kind, value)


def test_warehouse_scope_rejects_ranges() -> None:
    with pytest.raises(ValueError, match="not a range"):
        WarehouseExecutionScope.from_run_scope(RunScope.for_range("20251201", "20251202"))


def test_added_arguments_match_the_allowed_kinds() -> None:
    parser = argparse.ArgumentParser()
    add_scope_arguments(parser, allow={"date", "month"}, single_date_alias=True)

    assert RunScope.from_args(parser.parse_args(["--single-date", "20251208"])).label == "20251208"
    with pytest.raises(SystemExit):
        parser.parse_args(["--full-history"])
    with pytest.raises(SystemExit):
        parser.parse_args(["--date", "20251208", "--month", "202512"])


def test_resolve_date_scope_defaults_to_today_and_clips_the_current_month() -> None:
    assert resolve_date_scope(current_date=TODAY) == ["20260812"]
    assert resolve_date_scope(month="202608", current_date=date(2026, 8, 3)) == [
        "20260801",
        "20260802",
        "20260803",
    ]


def test_resolve_date_scope_can_require_a_selector() -> None:
    with pytest.raises(ScopeError, match="is required"):
        resolve_date_scope(current_date=TODAY, default_to_today=False)
