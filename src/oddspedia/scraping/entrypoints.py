"""Stable adapters for the phase-specific Oddspedia script entry points.

The shared intake CLI exits non-zero itself on failure, so a normal return
means the phase succeeded.
"""

import sys
from collections.abc import Sequence

from src.oddspedia.scraping.cli import main


def run_event_command(command: str, argv: Sequence[str] | None = None) -> int:
    """Run one Oddspedia event-intake command through the shared CLI.

    Args:
        command: Internal compatibility command to execute.
        argv: Optional arguments following the command name.
    """
    command_args = list(sys.argv[1:]) if argv is None else list(argv)
    main(command_args, default_sport="football", fixed_command=command)
    return 0


def discover_main(argv: Sequence[str] | None = None) -> int:
    """Discover Oddspedia event links for a date or month."""
    return run_event_command("discover", argv)


def prioritize_main(argv: Sequence[str] | None = None) -> int:
    """Prioritize discovered Oddspedia events against the Silver reference."""
    return run_event_command("prioritize", argv)


def scrape_main(argv: Sequence[str] | None = None) -> int:
    """Scrape prioritized Oddspedia match pages."""
    return run_event_command("scrape", argv)


def run_main(argv: Sequence[str] | None = None) -> int:
    """Run discovery, prioritization, and scraping in order."""
    return run_event_command("run", argv)


def football_main(argv: Sequence[str] | None = None) -> int:
    """Run the legacy umbrella intake command (all phases, chosen by flags)."""
    main(argv, default_sport="football")
    return 0
