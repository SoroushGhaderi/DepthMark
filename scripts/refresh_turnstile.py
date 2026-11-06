"""Deprecated alias of scripts/fotmob/refresh_fotmob_turnstile.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.refresh_turnstile import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(__file__, "scripts/fotmob/refresh_fotmob_turnstile.py", main)
    )
