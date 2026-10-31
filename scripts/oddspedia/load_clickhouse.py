"""Deprecated alias of scripts/oddspedia/load_oddspedia_bronze.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.commands.load_bronze import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/load_oddspedia_bronze.py",
            main,
        )
    )
