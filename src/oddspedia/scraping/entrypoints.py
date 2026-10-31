"""Stable adapters for the phase-specific Oddspedia script entry points."""

import sys
from collections.abc import Sequence

from src.oddspedia.scraping.cli import main


def run_event_command(command: str, argv: Sequence[str] | None = None) -> None:
    """Run one Oddspedia event-intake command through the shared CLI.

    Args:
        command: Internal compatibility command to execute.
        argv: Optional arguments following the command name.
    """
    command_args = list(sys.argv[1:]) if argv is None else list(argv)
    main(command_args, default_sport="football", fixed_command=command)
