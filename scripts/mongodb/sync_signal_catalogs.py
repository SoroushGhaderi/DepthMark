"""Sync signal markdown catalogs into MongoDB signals collection."""

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, Tuple

import yaml
from dotenv import load_dotenv

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)

DEFAULT_CATALOG_DIR = project_root / "scripts" / "gold" / "signal" / "catalogs"
FRONTMATTER_DELIMITER = "\n---\n"


def load_environment() -> None:
    """Load env vars for local script execution."""
    env_files = [
        project_root / ".env",
        project_root.parent / ".env",
    ]
    for env_file in env_files:
        if env_file.exists():
            load_dotenv(env_file, override=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync signal catalogs from markdown frontmatter into MongoDB."
    )
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        default=DEFAULT_CATALOG_DIR,
        help="Directory containing signal catalog markdown files.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and validate catalogs without writing to MongoDB.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging output.",
    )
    return parser.parse_args()


def split_frontmatter(content: str, source_path: Path) -> Tuple[Dict[str, Any], str]:
    """Split markdown into frontmatter dict and body text."""
    if not content.startswith("---\n"):
        raise ValueError(f"Missing YAML frontmatter start in {source_path}")

    parts = content.split(FRONTMATTER_DELIMITER, 1)
    if len(parts) != 2:
        raise ValueError(f"Missing YAML frontmatter end in {source_path}")

    yaml_block = parts[0][4:]  # remove leading "---\n"
    body = parts[1].strip()

    frontmatter = yaml.safe_load(yaml_block) or {}
    if not isinstance(frontmatter, dict):
        raise ValueError(f"Frontmatter is not an object in {source_path}")

    return frontmatter, body


def build_signal_document(frontmatter: Dict[str, Any], body: str, source_path: Path) -> Dict[str, Any]:
    """Build Mongo document using frontmatter as the source of signal metadata."""
    required = [
        "signal_id",
        "status",
        "entity",
        "family",
        "subfamily",
        "grain",
        "row_identity",
        "asset_paths",
    ]
    missing = [field for field in required if field not in frontmatter]
    if missing:
        raise ValueError(f"Missing required frontmatter fields {missing} in {source_path}")

    signal_id = str(frontmatter["signal_id"])
    expected_id = source_path.stem
    if signal_id != expected_id:
        raise ValueError(
            f"signal_id '{signal_id}' does not match file name '{expected_id}' in {source_path}"
        )

    row_identity = frontmatter.get("row_identity")
    if not isinstance(row_identity, list) or not all(isinstance(v, str) for v in row_identity):
        raise ValueError(f"row_identity must be a list of strings in {source_path}")

    asset_paths = frontmatter.get("asset_paths")
    if not isinstance(asset_paths, dict):
        raise ValueError(f"asset_paths must be an object in {source_path}")

    return {
        "signal_id": signal_id,
        "status": str(frontmatter["status"]),
        "entity": str(frontmatter["entity"]),
        "family": str(frontmatter["family"]),
        "subfamily": str(frontmatter["subfamily"]),
        "grain": str(frontmatter["grain"]),
        "headline": frontmatter.get("headline"),
        "trigger": frontmatter.get("trigger"),
        "row_identity": row_identity,
        "asset_paths": asset_paths,
        "frontmatter": frontmatter,
        "source_path": str(source_path.relative_to(project_root)),
        "markdown_body": body,
    }


def iter_signal_catalogs(catalog_dir: Path):
    """Yield signal markdown catalog files."""
    for file_path in sorted(catalog_dir.glob("*.md")):
        if file_path.name.lower() == "readme.md":
            continue
        yield file_path


def sync_signals(catalog_dir: Path, dry_run: bool = False) -> Tuple[int, int]:
    """Sync all signal catalogs to MongoDB; returns (processed, failed)."""
    processed = 0
    failed = 0

    mongo_client = None
    repository = None
    if not dry_run:
        from src.storage.mongodb import get_mongodb_client
        from src.storage.mongodb.repositories import SignalsRepository

        mongo_client = get_mongodb_client()
        if not mongo_client.connect():
            raise RuntimeError("Could not connect to MongoDB")
        repository = SignalsRepository(mongo_client.get_database())

    try:
        for file_path in iter_signal_catalogs(catalog_dir):
            try:
                content = file_path.read_text(encoding="utf-8")
                frontmatter, body = split_frontmatter(content, file_path)
                document = build_signal_document(frontmatter, body, file_path)

                if repository is not None:
                    repository.upsert_signal(document["signal_id"], document)

                processed += 1
                logger.info(
                    "Signal catalog synced",
                    signal_id=document["signal_id"],
                    source_path=document["source_path"],
                    dry_run=dry_run,
                )
            except Exception as exc:
                failed += 1
                logger.error("Signal catalog sync failed", file=str(file_path), error=str(exc))
    finally:
        if mongo_client is not None:
            mongo_client.disconnect()

    return processed, failed


def main() -> int:
    load_environment()
    args = parse_args()
    setup_logging(
        name="mongodb_sync_signal_catalogs",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    catalog_dir = args.catalog_dir.resolve()
    if not catalog_dir.exists():
        logger.error("Catalog directory does not exist", catalog_dir=str(catalog_dir))
        return 2

    processed, failed = sync_signals(catalog_dir, dry_run=args.dry_run)
    logger.info(
        "Signal catalog sync finished",
        catalog_dir=str(catalog_dir),
        processed=processed,
        failed=failed,
        dry_run=args.dry_run,
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
