"""Validated execution scopes shared by warehouse entry points."""

import argparse
from dataclasses import dataclass
from datetime import datetime
from typing import Literal, Optional

ScopeKind = Literal["date", "month", "full-history"]


@dataclass(frozen=True)
class WarehouseExecutionScope:
    """An explicit output scope for a warehouse load."""

    kind: ScopeKind
    value: Optional[str] = None

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

    @property
    def label(self) -> str:
        return self.value or "full-history"

    @property
    def partition_id(self) -> Optional[int]:
        if self.kind == "date":
            return int(self.value[:6])
        if self.kind == "month":
            return int(self.value)
        return None

    @property
    def iso_date(self) -> Optional[str]:
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


def add_warehouse_scope_arguments(
    parser: argparse.ArgumentParser,
    *,
    include_single_date: bool = True,
) -> None:
    """Add required, mutually exclusive warehouse scope selectors."""
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--date", help="Process one match date (YYYYMMDD)")
    if include_single_date:
        group.add_argument(
            "--single-date",
            help="Backward-compatible alias for --date (YYYYMMDD)",
        )
    group.add_argument("--month", help="Process one calendar month (YYYYMM)")
    group.add_argument(
        "--full-history",
        action="store_true",
        help="Explicitly process all available history",
    )


def execution_scope_from_args(args: argparse.Namespace) -> WarehouseExecutionScope:
    """Build and validate a scope from parsed CLI arguments."""
    date_value = getattr(args, "date", None) or getattr(args, "single_date", None)
    if date_value:
        return WarehouseExecutionScope.for_date(date_value)
    month_value = getattr(args, "month", None)
    if month_value:
        return WarehouseExecutionScope.for_month(month_value)
    if getattr(args, "full_history", False):
        return WarehouseExecutionScope.full_history()
    raise ValueError("One of --date, --month, or --full-history is required")
