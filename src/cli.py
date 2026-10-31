"""DepthMark CLI entrypoint.

``depthmark <command>`` imports the command's ``main(argv)`` from ``src/`` and
runs it in-process. The matching script under ``scripts/`` is a thin shim
around the same function, so both entry points behave identically.
"""

from __future__ import annotations

import argparse
import importlib
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from src.common.deprecation import warn_deprecated

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
CLICKHOUSE_SQL_DIR = PROJECT_ROOT / "clickhouse"


@dataclass(frozen=True)
class CommandSpec:
    """One package command: its ``module:function`` target and script shim."""

    target: str
    script: str
    replacement: str | None = None
    arguments: tuple[str, ...] = ()


CANONICAL_COMMANDS: dict[str, CommandSpec] = {
    "health-check": CommandSpec("src.operations.commands.health_check:main", "health_check.py"),
    "report-scraping": CommandSpec(
        "src.operations.commands.report_scraping:main", "report_scraping.py"
    ),
    "scrape-fotmob": CommandSpec("src.fotmob.commands.scrape:main", "bronze/scrape_fotmob.py"),
    "load-fotmob-bronze": CommandSpec(
        "src.fotmob.commands.load_bronze:main", "bronze/load_fotmob_bronze.py"
    ),
    "remove-fotmob-bronze": CommandSpec(
        "src.fotmob.commands.remove_bronze:main", "bronze/remove_fotmob_bronze.py"
    ),
    "load-fotmob-silver": CommandSpec(
        "src.fotmob.commands.load_silver:main", "silver/load_fotmob_silver.py"
    ),
    "load-fotmob-gold": CommandSpec(
        "src.fotmob.commands.load_gold:main", "gold/load_fotmob_gold.py"
    ),
    "run-fotmob-gold-jobs": CommandSpec(
        "src.fotmob.commands.run_gold_jobs:main", "gold/run_fotmob_gold_jobs.py"
    ),
    "build-fotmob-signal-activations": CommandSpec(
        "src.fotmob.commands.build_signal_activations:main",
        "gold/build_fotmob_signal_activations.py",
    ),
    "check-signal-catalogs": CommandSpec(
        "src.fotmob.commands.check_signal_catalogs:main", "quality/check_signal_catalogs.py"
    ),
    "run-fotmob-pipeline": CommandSpec(
        "src.fotmob.commands.run_pipeline:main", "orchestration/run_fotmob_pipeline.py"
    ),
    "setup-fotmob-warehouse": CommandSpec(
        "src.fotmob.commands.setup_warehouse:main", "orchestration/setup_fotmob_warehouse.py"
    ),
    "discover-oddspedia-events": CommandSpec(
        "src.oddspedia.scraping.entrypoints:discover_main",
        "oddspedia/discover_oddspedia_events.py",
    ),
    "prioritize-oddspedia-events": CommandSpec(
        "src.oddspedia.scraping.entrypoints:prioritize_main",
        "oddspedia/prioritize_oddspedia_events.py",
    ),
    "scrape-oddspedia-matches": CommandSpec(
        "src.oddspedia.scraping.entrypoints:scrape_main", "oddspedia/scrape_oddspedia_matches.py"
    ),
    "run-oddspedia-pipeline": CommandSpec(
        "src.oddspedia.scraping.entrypoints:run_main", "oddspedia/run_oddspedia_pipeline.py"
    ),
    "setup-oddspedia-warehouse": CommandSpec(
        "src.oddspedia.commands.setup_warehouse:main", "oddspedia/setup_oddspedia_warehouse.py"
    ),
    "load-oddspedia-bronze": CommandSpec(
        "src.oddspedia.commands.load_bronze:main", "oddspedia/load_oddspedia_bronze.py"
    ),
    "resolve-oddspedia-events": CommandSpec(
        "src.oddspedia.commands.resolve_events:main", "oddspedia/resolve_oddspedia_events.py"
    ),
}


def _alias(canonical_command: str) -> CommandSpec:
    """Build a compatibility command that targets a canonical command."""
    canonical = CANONICAL_COMMANDS[canonical_command]
    return CommandSpec(
        target=canonical.target,
        script=canonical.script,
        replacement=canonical_command,
        arguments=canonical.arguments,
    )


def _oddspedia_report_alias(output_format: str) -> CommandSpec:
    """Build an old Oddspedia reporting command on the unified interface."""
    report = CANONICAL_COMMANDS["report-scraping"]
    return CommandSpec(
        target=report.target,
        script=report.script,
        replacement="report-scraping",
        arguments=("--source", "oddspedia", "--format", output_format),
    )


COMPATIBILITY_COMMANDS: dict[str, CommandSpec] = {
    "scrape": _alias("scrape-fotmob"),
    "load": _alias("load-fotmob-bronze"),
    "pipeline": _alias("run-fotmob-pipeline"),
    "setup-clickhouse": _alias("setup-fotmob-warehouse"),
    "oddspedia-discover-events": _alias("discover-oddspedia-events"),
    "oddspedia-prioritize-events": _alias("prioritize-oddspedia-events"),
    "oddspedia-scrape-matches": _alias("scrape-oddspedia-matches"),
    "oddspedia-run-pipeline": _alias("run-oddspedia-pipeline"),
    "status-oddspedia": _oddspedia_report_alias("summary"),
    "report-oddspedia": _oddspedia_report_alias("markdown"),
    "oddspedia-status": _oddspedia_report_alias("summary"),
    "oddspedia-report": _oddspedia_report_alias("markdown"),
    "oddspedia-setup-warehouse": _alias("setup-oddspedia-warehouse"),
    "oddspedia-load-bronze": _alias("load-oddspedia-bronze"),
    "oddspedia-resolve-events": _alias("resolve-oddspedia-events"),
    # Older umbrella and ClickHouse-named commands keep their argument behavior.
    "oddspedia-events": CommandSpec(
        "src.oddspedia.scraping.entrypoints:football_main",
        "oddspedia/events.py",
        "a phase-specific Oddspedia command",
    ),
    "oddspedia-football": CommandSpec(
        "src.oddspedia.scraping.entrypoints:football_main",
        "oddspedia/football.py",
        "run-oddspedia-pipeline",
    ),
    "oddspedia-setup-clickhouse": CommandSpec(
        "src.oddspedia.commands.setup_warehouse:main",
        "oddspedia/setup_clickhouse.py",
        "setup-oddspedia-warehouse",
    ),
    "oddspedia-load-clickhouse": CommandSpec(
        "src.oddspedia.commands.load_bronze:main",
        "oddspedia/load_clickhouse.py",
        "load-oddspedia-bronze",
    ),
    "oddspedia-resolve-matches": CommandSpec(
        "src.oddspedia.commands.resolve_events:main",
        "oddspedia/resolve_matches.py",
        "resolve-oddspedia-events",
    ),
}

COMMANDS: dict[str, CommandSpec] = {**CANONICAL_COMMANDS, **COMPATIBILITY_COMMANDS}


def resolve_target(target: str) -> Callable[[list[str]], int | None]:
    """Import and return the ``module:function`` a command runs."""
    module_name, function_name = target.split(":")
    return getattr(importlib.import_module(module_name), function_name)


def run_command(spec: CommandSpec, command_args: list[str]) -> int:
    """Run one command's ``main`` in-process and return its exit code."""
    if not CLICKHOUSE_SQL_DIR.is_dir():
        print(
            f"DepthMark commands run from a source checkout, but {PROJECT_ROOT} has no "
            "clickhouse/ directory. Install with `pip install -e .` from the "
            "repository root.",
            file=sys.stderr,
        )
        return 2
    result = resolve_target(spec.target)([*spec.arguments, *command_args])
    return 0 if result is None else int(result)


def main(argv: list[str] | None = None) -> int:
    """CLI main entrypoint."""
    parser = argparse.ArgumentParser(
        prog="depthmark",
        description="DepthMark command-line entrypoint",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=sorted(COMMANDS.keys()),
        help="Command to run",
    )
    parser.add_argument(
        "args",
        nargs=argparse.REMAINDER,
        help="Arguments passed through to the selected command",
    )

    parsed = parser.parse_args(argv)

    if not parsed.command:
        parser.print_help()
        return 2

    command = COMMANDS[parsed.command]
    if command.replacement:
        replacement = (
            f"'depthmark {command.replacement}'"
            if command.replacement in CANONICAL_COMMANDS
            else command.replacement
        )
        warn_deprecated(f"'depthmark {parsed.command}'", replacement)

    return run_command(command, parsed.args)


if __name__ == "__main__":
    raise SystemExit(main())
