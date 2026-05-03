"""Initialize MongoDB indexes for Orbit content catalog."""

import argparse
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from src.storage.mongodb import ensure_content_catalog_indexes, get_mongodb_client
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create required indexes in MongoDB for Orbit content catalog.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    setup_logging(
        name="mongodb_init_indexes",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    mongo_client = get_mongodb_client()
    if not mongo_client.connect():
        logger.error("Could not connect to MongoDB. Index initialization aborted.")
        return 2

    try:
        database = mongo_client.get_database()
        created = ensure_content_catalog_indexes(database)
        logger.info("MongoDB indexes ensured", database=database.name, collections=list(created.keys()))
        for collection_name, index_names in created.items():
            logger.info(
                "Collection indexes",
                collection=collection_name,
                indexes=index_names,
            )
    finally:
        mongo_client.disconnect()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

