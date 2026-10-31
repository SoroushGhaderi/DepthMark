"""Deprecated alias of scripts/orchestration/setup_fotmob_warehouse.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.setup_warehouse import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/orchestration/setup_fotmob_warehouse.py",
            main,
        )
    )
