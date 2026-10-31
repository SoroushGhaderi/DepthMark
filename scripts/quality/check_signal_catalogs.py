"""Validate signal catalogs against their SQL and DDL, and keep the index current.

Read-only by default: exits 0 when every catalog is valid and the index is
current, 1 when any catalog breaks a rule or the index is stale. With
``--write-index``, a valid catalog regenerates the index table instead of
failing on it. Needs no ClickHouse, MongoDB, or ``.env``.
"""

import argparse
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from src.common.logging import get_logger
from src.fotmob.gold.signal_catalog import (
    INDEX_FILE_NAME,
    SIGNAL_CATALOG_DIR,
    SignalCatalogError,
    load_signal_catalog,
    replace_signal_index,
)

logger = get_logger(__name__)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate signal catalogs and check or regenerate their index."
    )
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        default=SIGNAL_CATALOG_DIR,
        help="Directory containing signal catalog markdown files.",
    )
    parser.add_argument(
        "--write-index",
        action="store_true",
        help=f"Regenerate the index table in {INDEX_FILE_NAME} instead of failing when stale.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        catalog = load_signal_catalog(args.catalog_dir)
    except SignalCatalogError as error:
        for violation in error.violations:
            logger.error("[ERROR] Signal catalog violation: %s", violation.describe())
        logger.error("[ERROR] Signal catalog is invalid: %s violation(s)", len(error.violations))
        return 1

    index_path = catalog.catalog_dir / INDEX_FILE_NAME
    current_index = index_path.read_text(encoding="utf-8")
    try:
        expected_index = replace_signal_index(current_index, catalog)
    except ValueError as error:
        logger.error("[ERROR] Signal catalog index %s: %s", index_path, error)
        return 1

    if expected_index != current_index:
        if not args.write_index:
            logger.error(
                "[ERROR] Signal catalog index is stale: %s; rerun with --write-index", index_path
            )
            return 1
        index_path.write_text(expected_index, encoding="utf-8")
        logger.info("[OK] Signal catalog index regenerated: %s", index_path)

    logger.info(
        "[OK] Signal catalog is valid: %s signal(s), %s active",
        len(catalog),
        len(catalog.active()),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
