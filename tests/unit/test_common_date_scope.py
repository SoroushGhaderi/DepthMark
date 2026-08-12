"""Contract tests for shared operational date-scope resolution."""

from datetime import date

import pytest

from src.common.dates import resolve_date_scope


def test_range_is_inclusive_and_ordered() -> None:
    assert resolve_date_scope(
        start_date="20260301",
        end_date="20260303",
        current_date=date(2026, 8, 12),
    ) == ["20260301", "20260302", "20260303"]


def test_current_month_is_clipped_through_today() -> None:
    assert resolve_date_scope(month="202608", current_date=date(2026, 8, 3)) == [
        "20260801",
        "20260802",
        "20260803",
    ]


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        ({"start_date": "20260303", "end_date": "20260301"}, "before"),
        ({"start_date": "20260301"}, "required"),
        ({"end_date": "20260301"}, "only be used"),
        ({"date_value": "20260813"}, "future"),
        ({"month": "202609"}, "future"),
    ],
)
def test_invalid_or_future_scopes_fail(arguments, message) -> None:
    with pytest.raises(ValueError, match=message):
        resolve_date_scope(current_date=date(2026, 8, 12), **arguments)


def test_required_scope_does_not_default_to_today() -> None:
    with pytest.raises(ValueError, match="required"):
        resolve_date_scope(current_date=date(2026, 8, 12), default_to_today=False)
