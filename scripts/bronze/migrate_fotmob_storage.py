#!/usr/bin/env python3
"""Migrate legacy FotMob Bronze directories into Historical/Live aspects."""

import argparse
import sys
from pathlib import Path
from typing import Optional, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import FotMobConfig
from src.storage.bronze.paths import migrate_legacy_fotmob_storage
from src.utils.logging_utils import configure_logging, get_logger

logger = get_logger(__name__)


def create_argument_parser() -> argparse.ArgumentParser:
    """Create the migration command parser."""
    parser = argparse.ArgumentParser(
        description="Move legacy FotMob Bronze directories into historical storage"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply the migration; without this flag the command is a dry-run",
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Plan or apply the collision-safe filesystem migration."""
    args = create_argument_parser().parse_args(argv)
    configure_logging()
    bronze_root = FotMobConfig().storage.bronze_path
    try:
        operations = migrate_legacy_fotmob_storage(bronze_root, dry_run=not args.apply)
    except FileExistsError as error:
        logger.error("FotMob Bronze migration blocked: %s", error)
        return 1

    mode = "APPLY" if args.apply else "DRY-RUN"
    if not operations:
        logger.info("[%s] FotMob Bronze storage already uses the canonical structure", mode)
        return 0

    for operation in operations:
        logger.info("[%s] %s", mode, operation)
    if not args.apply:
        logger.info("Re-run with --apply to perform these changes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
