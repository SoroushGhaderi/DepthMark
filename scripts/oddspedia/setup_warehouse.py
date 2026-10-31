"""Deprecated alias of scripts/oddspedia/setup_oddspedia_warehouse.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.commands.setup_warehouse import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/setup_oddspedia_warehouse.py",
            main,
        )
    )
