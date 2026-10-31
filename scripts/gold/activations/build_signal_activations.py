"""Deprecated alias of scripts/gold/build_fotmob_signal_activations.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.build_signal_activations import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/gold/build_fotmob_signal_activations.py",
            main,
        )
    )
