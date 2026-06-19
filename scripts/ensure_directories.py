"""Ensure required directories exist.

This script creates the required local directory structure for the DepthMark project.
It's optional since the pipeline scripts create directories automatically,
but can be useful for pre-initialization or troubleshooting.

Usage:
    python scripts/ensure_directories.py
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.utils.logging_utils import get_logger, initialize_logging

logger = get_logger(__name__)


def ensure_directories() -> None:
    """Create required directories if they don't exist."""

    # Get project root (parent of scripts directory)
    project_root = Path(__file__).parent.parent

    # Required directories
    directories = [
        project_root / "data",
        project_root / "data" / "fotmob",
        project_root / "data" / "fotmob" / "historical" / "daily_listings",
        project_root / "data" / "fotmob" / "historical" / "matches",
        project_root / "data" / "fotmob" / "live" / "daily_listings",
        project_root / "data" / "fotmob" / "live" / "matches",
        project_root / "logs",
    ]

    logger.info("Creating required directories...")
    logger.info("Project root: %s", project_root)

    created = []
    existed = []

    for directory in directories:
        if directory.exists():
            existed.append(directory)
            logger.info("  [OK] %s (already exists)", directory.relative_to(project_root))
        else:
            directory.mkdir(parents=True, exist_ok=True)
            created.append(directory)
            logger.info("  + %s (created)", directory.relative_to(project_root))

    logger.info("=" * 60)
    logger.info("Summary:")
    logger.info("  Created: %s directories", len(created))
    logger.info("  Existed: %s directories", len(existed))
    logger.info("  Total:   %s directories", len(directories))
    logger.info("=" * 60)

    if created:
        logger.info("[OK] Directory structure initialized successfully!")
    else:
        logger.info("[OK] All directories already exist.")


def main() -> int:
    """Main execution function."""
    try:
        initialize_logging(log_level="INFO", force=True)
        ensure_directories()
        return 0
    except Exception as e:
        logger.error("Error creating directories: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
