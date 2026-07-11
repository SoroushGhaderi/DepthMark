"""DepthMark CLI entrypoint.

This command provides a stable package entrypoint and proxies to the existing
scripts-based workflows.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Dict


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"

SCRIPT_MAP: Dict[str, str] = {
    "scrape": "scrape_fotmob.py",
    "load": "load_clickhouse.py",
    "pipeline": "pipeline.py",
    "setup-clickhouse": "setup_clickhouse.py",
    "health-check": "health_check.py",
    "oddspedia-football": "oddspedia/football.py",
}


def _run_script(script_name: str, script_args: list[str]) -> int:
    """Execute a script from the scripts directory."""
    script_path = SCRIPTS_DIR / script_name
    cmd = [sys.executable, str(script_path), *script_args]
    return subprocess.run(cmd, cwd=PROJECT_ROOT, text=True).returncode


def main(argv: list[str] | None = None) -> int:
    """CLI main entrypoint."""
    parser = argparse.ArgumentParser(
        prog="depthmark",
        description="DepthMark command-line entrypoint",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=sorted(SCRIPT_MAP.keys()),
        help="Command to run",
    )
    parser.add_argument(
        "args",
        nargs=argparse.REMAINDER,
        help="Arguments passed through to the selected command",
    )

    parsed = parser.parse_args(argv)

    if not parsed.command:
        parser.print_help()
        return 2

    return _run_script(SCRIPT_MAP[parsed.command], parsed.args)


if __name__ == "__main__":
    raise SystemExit(main())
