"""Deprecated alias of scripts/oddspedia/resolve_oddspedia_events.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.commands.resolve_events import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/resolve_oddspedia_events.py",
            main,
        )
    )
