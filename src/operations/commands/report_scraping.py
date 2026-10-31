#!/usr/bin/env python3
"""Generate one read-only scraping report for FotMob, Oddspedia, or both."""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Sequence
from pathlib import Path

from src.operations.scraping_reporting import (
    build_scraping_report,
    needs_attention,
    render_markdown,
    render_summary,
    resolve_report_dates,
)


def create_argument_parser(
    default_source: str = "all", default_format: str = "summary"
) -> argparse.ArgumentParser:
    """Create the stable unified reporting CLI."""
    parser = argparse.ArgumentParser(
        description="Report read-only FotMob and Oddspedia scraping status",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 scripts/report_scraping.py --date 20260301
  python3 scripts/report_scraping.py --source fotmob --month 202608
  python3 scripts/report_scraping.py --start-date 20260301 --end-date 20260307
  python3 scripts/report_scraping.py --source oddspedia --date 20260301 --format markdown
  python3 scripts/report_scraping.py --month 202608 --format json --output reports/august.json
  python3 scripts/report_scraping.py --date 20260301 --fail-on-attention
""",
    )
    parser.add_argument(
        "--source",
        choices=("all", "fotmob", "oddspedia"),
        default=default_source,
        help=f"Source scope (default: {default_source})",
    )
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--date", metavar="YYYYMMDD", help="One report date (default: today)")
    scope.add_argument("--month", metavar="YYYYMM", help="One month; current month ends today")
    scope.add_argument(
        "--start-date",
        metavar="YYYYMMDD",
        help="First date of an inclusive report range; requires --end-date",
    )
    parser.add_argument(
        "--end-date",
        metavar="YYYYMMDD",
        help="Last date of an inclusive report range; requires --start-date",
    )
    parser.add_argument(
        "--format",
        choices=("summary", "markdown", "json"),
        default=default_format,
        help=f"Output format (default: {default_format})",
    )
    parser.add_argument(
        "--sport",
        default="football",
        help="Compatibility option; DepthMark reporting currently supports football only",
    )
    parser.add_argument("--output", help="Optional output file; stdout is used by default")
    parser.add_argument(
        "--fail-on-attention",
        action="store_true",
        help="Exit 1 when the report is incomplete, needs attention, or contains an error",
    )
    return parser


def main(
    argv: Sequence[str] | None = None,
    *,
    default_source: str = "all",
    default_format: str = "summary",
) -> int:
    """Build and render a report without mutating scraper or warehouse state."""
    parser = create_argument_parser(default_source, default_format)
    args = parser.parse_args(argv)
    try:
        if args.sport.strip().lower() != "football":
            raise ValueError(f"DepthMark reporting only supports football: {args.sport}")
        dates = resolve_report_dates(
            date_value=args.date,
            month=args.month,
            start_date=args.start_date,
            end_date=args.end_date,
        )
        report = build_scraping_report(args.source, dates)
        if args.format == "json":
            content = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        elif args.format == "markdown":
            content = render_markdown(report)
        else:
            content = render_summary(report)

        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(content, encoding="utf-8")
            print(f"Wrote scraping report: {output_path}")
        else:
            print(content, end="")
        return 1 if args.fail_on_attention and needs_attention(report) else 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Unable to generate scraping report: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
