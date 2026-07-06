"""Backward-compatible entry point for the unified warehouse quality workflow."""

import argparse
import sys
from pathlib import Path
from typing import List, Optional

project_root = Path(__file__).resolve().parents[2]
scripts_dir = Path(__file__).resolve().parents[1]
for candidate in (str(project_root), str(scripts_dir)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

from scripts.quality.check_data_quality import main as unified_main
from src.services.data_quality import reconciliation_check_names


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compatibility alias: check Bronze and Silver duplicates and reconcile "
            "Bronze to Silver"
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


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    scope_args: List[str] = []
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
