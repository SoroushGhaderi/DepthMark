"""Deprecated alias of scripts/orchestration/run_fotmob_pipeline.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.run_pipeline import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/orchestration/run_fotmob_pipeline.py",
            main,
        )
    )
