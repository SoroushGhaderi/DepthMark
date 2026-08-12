"""Contract tests for date ranges on Oddspedia warehouse scripts."""

from argparse import Namespace

from scripts.oddspedia import load_bronze, resolve_events


def _args(**values):
    defaults = {"date": None, "month": None, "start_date": None, "end_date": None}
    defaults.update(values)
    return Namespace(**defaults)


def test_bronze_loader_date_range_is_inclusive():
    assert load_bronze._dates(_args(start_date="20260301", end_date="20260303")) == [
        "20260301",
        "20260302",
        "20260303",
    ]


def test_resolver_date_range_is_inclusive():
    assert resolve_events._dates(_args(start_date="20260301", end_date="20260303")) == [
        "20260301",
        "20260302",
        "20260303",
    ]
