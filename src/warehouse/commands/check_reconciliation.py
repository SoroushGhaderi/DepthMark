"""Backward-compatible entry point for the unified warehouse quality workflow."""

import argparse

from src.common.paths import PROJECT_ROOT
from src.warehouse.commands.check_data_quality import main as unified_main
from src.warehouse.quality import reconciliation_check_names

project_root = PROJECT_ROOT


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compatibility alias: check Bronze and Silver duplicates and reconcile Bronze to Silver"
        )
    )
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--date", help="Check one match date (YYYYMMDD)")
    scope.add_argument("--month", help="Check one calendar month (YYYYMM)")
    scope.add_argument("--full-history", action="store_true", help="Check all history")
    parser.add_argument(
        "--checks",
        default="all",
        help=(
            "Comma-separated checks: match,period,player,momentum,shot,card,personnel,"
            "team_form or all"
        ),
    )
    parser.add_argument("--sample-limit", type=int, default=100)
    parser.add_argument("--strict", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    scope_args: list[str] = []
    if args.date:
        scope_args = ["--date", args.date]
    elif args.month:
        scope_args = ["--month", args.month]
    else:
        scope_args = ["--full-history"]
    forwarded = [
        *scope_args,
        "--layers",
        "bronze,silver",
        "--reconciliation-checks",
        args.checks,
        "--sample-limit",
        str(args.sample_limit),
    ]
    if args.strict:
        forwarded.append("--strict")
    return unified_main(forwarded)


__all__ = ["main", "parse_args", "reconciliation_check_names"]


if __name__ == "__main__":
    raise SystemExit(main())
