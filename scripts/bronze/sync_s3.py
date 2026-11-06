"""Deprecated alias of scripts/fotmob/sync_fotmob_s3.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.sync_s3 import main

if __name__ == "__main__":
    raise SystemExit(run_deprecated_script(__file__, "scripts/fotmob/sync_fotmob_s3.py", main))
