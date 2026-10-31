"""Run scopes: the one parser and expander for CLI date selectors.

Every command that accepts ``--date``, ``--start-date``/``--end-date``,
``--month`` or ``--full-history`` builds a :class:`RunScope` with
:meth:`RunScope.from_args` and expands it with :meth:`RunScope.dates`, so
validation, error messages, and edge cases (a current month stopping at today,
impossible days, reversed ranges) are the same everywhere. A command declares
the selectors it accepts with ``allow``; anything else is rejected.
"""

from __future__ import annotations

import argparse
from collections.abc import Collection
from dataclasses import dataclass
from datetime import date, datetime
from typing import Literal

from src.common.dates import (
    DATE_FORMAT_COMPACT,
    inclusive_date_ids,
    month_date_ids,
    normalize_compact_date,
    normalize_compact_month,
)

ScopeKind = Literal["date", "range", "month", "full-history"]
ALL_SCOPE_KINDS: frozenset[ScopeKind] = frozenset({"date", "range", "month", "full-history"})
SELECTOR_FLAGS: dict[ScopeKind, str] = {
    "date": "--date",
    "range": "--start-date/--end-date",
    "month": "--month",
    "full-history": "--full-history",
}


class ScopeError(ValueError):
    """Raised when CLI date selectors do not form one valid scope."""


@dataclass(frozen=True)
class RunScope:
    """One validated date, inclusive range, month, or full history."""

    kind: ScopeKind
    start: str | None = None
    end: str | None = None

    @classmethod
    def for_date(cls, value: str) -> RunScope:
        return cls("date", _date(value), _date(value))

    @classmethod
    def for_range(cls, start: str, end: str) -> RunScope:
        start_id, end_id = _date(start), _date(end)
        if end_id < start_id:
            raise ScopeError("--end-date cannot be before --start-date")
        return cls("range", start_id, end_id)

    @classmethod
    def for_month(cls, value: str) -> RunScope:
        try:
            month_id = normalize_compact_month(value)
        except ValueError as error:
            raise ScopeError(f"Invalid month '{value}'; expected YYYYMM") from error
        return cls("month", month_id, month_id)

    @classmethod
    def full_history(cls) -> RunScope:
        return cls("full-history")

    @classmethod
    def from_args(
        cls,
        args: argparse.Namespace,
        *,
        allow: Collection[ScopeKind] = ALL_SCOPE_KINDS,
        default: RunScope | None = None,
    ) -> RunScope:
        """Build the scope selected by parsed CLI arguments.

        Reads ``date`` (or the legacy ``single_date``), ``start_date``,
        ``end_date``, ``month`` and ``full_history`` when the parser defines
        them. ``default`` is returned when no selector is given; without it a
        selector is required.
        """
        date_value = getattr(args, "date", None) or getattr(args, "single_date", None)
        start = getattr(args, "start_date", None)
        end = getattr(args, "end_date", None)
        month = getattr(args, "month", None)
        full_history = bool(getattr(args, "full_history", False))

        if end and not start:
            raise ScopeError("--end-date can only be used with --start-date")
        if start and not end:
            raise ScopeError("--end-date is required with --start-date")
        chosen: list[ScopeKind] = [
            kind
            for kind, given in (
                ("date", date_value),
                ("range", start),
                ("month", month),
                ("full-history", full_history),
            )
            if given
        ]
        if len(chosen) > 1:
            raise ScopeError(f"choose only one of {_flags(allow)}")
        if not chosen:
            if default is not None:
                return default
            raise ScopeError(f"one of {_flags(allow)} is required")
        kind = chosen[0]
        if kind not in allow:
            raise ScopeError(f"{SELECTOR_FLAGS[kind]} is not supported here; use {_flags(allow)}")
        if kind == "date":
            return cls.for_date(date_value)
        if kind == "range":
            return cls.for_range(start, end)
        if kind == "month":
            return cls.for_month(month)
        return cls.full_history()

    @property
    def month(self) -> str | None:
        return self.start if self.kind == "month" else None

    @property
    def label(self) -> str:
        if self.kind == "full-history":
            return "full-history"
        if self.kind == "range":
            return f"{self.start}-{self.end}"
        return self.start or ""

    def dates(self, *, through: date | None = None) -> list[str]:
        """Return the scope's YYYYMMDD dates in order.

        ``through`` clips a month that contains it at that day and rejects
        dates after it, so a current-month run never selects future days. Full
        history has no explicit dates; callers discover them from storage.
        """
        if self.kind == "full-history":
            return []
        if self.kind == "month":
            if through and _month_start(self.start) > through:
                raise ScopeError(f"future months cannot be selected: {self.start}")
            return month_date_ids(self.start, through_date=through)
        dates = [self.start] if self.kind == "date" else inclusive_date_ids(self.start, self.end)
        if through and datetime.strptime(dates[-1], DATE_FORMAT_COMPACT).date() > through:
            raise ScopeError(f"future dates cannot be selected: {dates[-1]}")
        return dates


def resolve_date_scope(
    date_value: str | None = None,
    month: str | None = None,
    current_date: date | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    default_to_today: bool = True,
) -> list[str]:
    """Resolve one date, month, or inclusive range without admitting future dates.

    A current-month selector stops at ``current_date``; with no selector the
    scope is today unless ``default_to_today`` is False.
    """
    today = current_date or date.today()
    args = argparse.Namespace(
        date=date_value, month=month, start_date=start_date, end_date=end_date
    )
    default = RunScope.for_date(today.strftime(DATE_FORMAT_COMPACT)) if default_to_today else None
    scope = RunScope.from_args(args, allow={"date", "range", "month"}, default=default)
    return scope.dates(through=today)


def add_scope_arguments(
    parser: argparse.ArgumentParser,
    *,
    allow: Collection[ScopeKind] = ALL_SCOPE_KINDS,
    required: bool = True,
    single_date_alias: bool = False,
    noun: str = "date",
) -> None:
    """Add mutually exclusive selectors for the scope kinds a command accepts."""
    group = parser.add_mutually_exclusive_group(required=required)
    if "date" in allow:
        group.add_argument("--date", help=f"One {noun} (YYYYMMDD)")
        if single_date_alias:
            group.add_argument("--single-date", help="Backward-compatible alias for --date")
    if "range" in allow:
        group.add_argument("--start-date", help=f"First {noun} of an inclusive range (YYYYMMDD)")
    if "month" in allow:
        group.add_argument("--month", help=f"Every {noun} of a month (YYYYMM)")
    if "full-history" in allow:
        group.add_argument("--full-history", action="store_true", help=f"Every {noun}")
    if "range" in allow:
        parser.add_argument("--end-date", help=f"Last {noun} of the range (YYYYMMDD)")


def _date(value: str) -> str:
    try:
        return normalize_compact_date(value)
    except ValueError as error:
        raise ScopeError(f"Invalid date '{value}'; expected YYYYMMDD") from error


def _month_start(month_id: str) -> date:
    return datetime.strptime(month_id, "%Y%m").date()


def _flags(allow: Collection[ScopeKind]) -> str:
    return ", ".join(SELECTOR_FLAGS[kind] for kind in SELECTOR_FLAGS if kind in allow)
