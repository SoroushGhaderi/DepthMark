"""Validated execution scopes shared by warehouse entry points."""

import argparse
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from src.common.run_scope import RunScope, add_scope_arguments

ScopeKind = Literal["date", "month", "full-history"]


@dataclass(frozen=True)
class WarehouseExecutionScope:
    """An explicit output scope for a warehouse load."""

    kind: ScopeKind
    value: str | None = None

    @classmethod
    def for_date(cls, value: str) -> "WarehouseExecutionScope":
        _validate_compact_date(value, "%Y%m%d", "YYYYMMDD")
        return cls(kind="date", value=value)

    @classmethod
    def for_month(cls, value: str) -> "WarehouseExecutionScope":
        _validate_compact_date(value, "%Y%m", "YYYYMM")
        return cls(kind="month", value=value)

    @classmethod
    def full_history(cls) -> "WarehouseExecutionScope":
        return cls(kind="full-history")

    @classmethod
    def from_run_scope(cls, scope: RunScope) -> "WarehouseExecutionScope":
        """Warehouse loads replace whole partitions, so ranges are not a warehouse scope."""
        if scope.kind == "date":
            return cls.for_date(scope.start)
        if scope.kind == "month":
            return cls.for_month(scope.start)
        if scope.kind == "full-history":
            return cls.full_history()
        raise ValueError("Warehouse loads take --date, --month, or --full-history, not a range")

    @property
    def label(self) -> str:
        return self.value or "full-history"

    @property
    def partition_id(self) -> int | None:
        if self.kind == "date":
            return int(self.value[:6])
        if self.kind == "month":
            return int(self.value)
        return None

    @property
    def iso_date(self) -> str | None:
        if self.kind != "date":
            return None
        return datetime.strptime(self.value, "%Y%m%d").date().isoformat()

    @property
    def output_range(self) -> str:
        if self.kind == "date":
            return self.iso_date or ""
        if self.kind == "month":
            start = datetime.strptime(self.value, "%Y%m").date()
            if start.month == 12:
                next_month = start.replace(year=start.year + 1, month=1)
            else:
                next_month = start.replace(month=start.month + 1)
            return f"[{start.isoformat()}, {next_month.isoformat()})"
        return "all available history"


def _validate_compact_date(value: str, date_format: str, display_format: str) -> None:
    try:
        parsed = datetime.strptime(value, date_format)
    except (TypeError, ValueError) as error:
        raise ValueError(f"Invalid scope value '{value}'; expected {display_format}") from error
    if parsed.strftime(date_format) != value:
        raise ValueError(f"Invalid scope value '{value}'; expected {display_format}")


WAREHOUSE_SCOPE_KINDS = frozenset({"date", "month", "full-history"})


def add_warehouse_scope_arguments(
    parser: argparse.ArgumentParser,
    *,
    include_single_date: bool = True,
) -> None:
    """Add required, mutually exclusive warehouse scope selectors."""
    add_scope_arguments(
        parser,
        allow=WAREHOUSE_SCOPE_KINDS,
        single_date_alias=include_single_date,
        noun="match date",
    )


def execution_scope_from_args(args: argparse.Namespace) -> WarehouseExecutionScope:
    """Build and validate a warehouse scope from parsed CLI arguments."""
    return WarehouseExecutionScope.from_run_scope(
        RunScope.from_args(args, allow=WAREHOUSE_SCOPE_KINDS)
    )
