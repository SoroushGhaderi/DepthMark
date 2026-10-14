"""DepthMark CLI entrypoint.

This command provides a stable package entrypoint and proxies to the existing
scripts-based workflows.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Tuple

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
CLICKHOUSE_SQL_DIR = PROJECT_ROOT / "clickhouse"


@dataclass(frozen=True)
class CommandSpec:
    """One package command and its script target."""

    script: str
    replacement: Optional[str] = None
    arguments: Tuple[str, ...] = ()


CANONICAL_COMMANDS: Dict[str, CommandSpec] = {
    "health-check": CommandSpec("health_check.py"),
    "report-scraping": CommandSpec("report_scraping.py"),
    "scrape-fotmob": CommandSpec("bronze/scrape_fotmob.py"),
    "load-fotmob-bronze": CommandSpec("bronze/load_fotmob_bronze.py"),
    "remove-fotmob-bronze": CommandSpec("bronze/remove_fotmob_bronze.py"),
    "load-fotmob-silver": CommandSpec("silver/load_fotmob_silver.py"),
    "load-fotmob-gold": CommandSpec("gold/load_fotmob_gold.py"),
    "build-fotmob-signal-activations": CommandSpec("gold/build_fotmob_signal_activations.py"),
    "run-fotmob-pipeline": CommandSpec("orchestration/run_fotmob_pipeline.py"),
    "setup-fotmob-warehouse": CommandSpec("orchestration/setup_fotmob_warehouse.py"),
    "discover-oddspedia-events": CommandSpec("oddspedia/discover_oddspedia_events.py"),
    "prioritize-oddspedia-events": CommandSpec("oddspedia/prioritize_oddspedia_events.py"),
    "scrape-oddspedia-matches": CommandSpec("oddspedia/scrape_oddspedia_matches.py"),
    "run-oddspedia-pipeline": CommandSpec("oddspedia/run_oddspedia_pipeline.py"),
    "setup-oddspedia-warehouse": CommandSpec("oddspedia/setup_oddspedia_warehouse.py"),
    "load-oddspedia-bronze": CommandSpec("oddspedia/load_oddspedia_bronze.py"),
    "resolve-oddspedia-events": CommandSpec("oddspedia/resolve_oddspedia_events.py"),
}


def _alias(canonical_command: str) -> CommandSpec:
    """Build a compatibility command that targets a canonical command."""
    return CommandSpec(
        script=CANONICAL_COMMANDS[canonical_command].script,
        replacement=canonical_command,
        arguments=CANONICAL_COMMANDS[canonical_command].arguments,
    )


def _oddspedia_report_alias(output_format: str) -> CommandSpec:
    """Build an old Oddspedia reporting command on the unified interface."""
    return CommandSpec(
        script=CANONICAL_COMMANDS["report-scraping"].script,
        replacement="report-scraping",
        arguments=("--source", "oddspedia", "--format", output_format),
    )


COMPATIBILITY_COMMANDS: Dict[str, CommandSpec] = {
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
    "oddspedia-events": CommandSpec("oddspedia/events.py", "a phase-specific Oddspedia command"),
    "oddspedia-football": CommandSpec("oddspedia/football.py", "run-oddspedia-pipeline"),
    "oddspedia-setup-clickhouse": CommandSpec(
        "oddspedia/setup_clickhouse.py", "setup-oddspedia-warehouse"
    ),
    "oddspedia-load-clickhouse": CommandSpec(
        "oddspedia/load_clickhouse.py", "load-oddspedia-bronze"
    ),
    "oddspedia-resolve-matches": CommandSpec(
        "oddspedia/resolve_matches.py", "resolve-oddspedia-events"
    ),
}

COMMANDS: Dict[str, CommandSpec] = {**CANONICAL_COMMANDS, **COMPATIBILITY_COMMANDS}

# Kept as a compatibility view for callers that imported the old registry.
SCRIPT_MAP: Dict[str, str] = {command: spec.script for command, spec in COMMANDS.items()}


def _run_script(script_name: str, script_args: list[str]) -> int:
    """Execute a script from the scripts directory."""
    if not SCRIPTS_DIR.is_dir() or not CLICKHOUSE_SQL_DIR.is_dir():
        print(
            f"DepthMark commands run from a source checkout, but {PROJECT_ROOT} has no "
            "scripts/ or clickhouse/ directory. Install with `pip install -e .` from the "
            "repository root.",
            file=sys.stderr,
        )
        return 2
    script_path = SCRIPTS_DIR / script_name
    if not script_path.is_file():
        print(
            f"DepthMark command registry target does not exist: {script_path}",
            file=sys.stderr,
        )
        return 2
    cmd = [sys.executable, str(script_path), *script_args]
    return subprocess.run(cmd, cwd=PROJECT_ROOT, text=True).returncode


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
        print(
            f"Warning: 'depthmark {parsed.command}' is deprecated; " f"use {replacement} instead.",
            file=sys.stderr,
        )

    return _run_script(command.script, [*command.arguments, *parsed.args])


if __name__ == "__main__":
    raise SystemExit(main())
