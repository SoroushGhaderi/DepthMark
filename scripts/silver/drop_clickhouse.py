"""Deprecated alias of scripts/fotmob/drop_fotmob_silver.py."""

from src.common.deprecation import run_deprecated_script
from src.warehouse.commands.drop_tables import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__, "scripts/fotmob/drop_fotmob_silver.py", main, layer="silver"
        )
    )
