"""Sync scenario markdown catalog into MongoDB scenarios collection."""

import argparse
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, Tuple

from dotenv import load_dotenv

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)

DEFAULT_CATALOG_FILE = project_root / "scripts" / "gold" / "scenario" / "scenarios_catalog.md"
SCENARIO_HEADING_RE = re.compile(r"^## .*Scenario: (?P<title>.*?) \(`(?P<scenario_id>scenario_[a-z0-9_]+)`\)\s*$")
NEXT_HEADING_RE = re.compile(r"^## ")


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
        description="Sync scenario catalog markdown into MongoDB.",
    )
    parser.add_argument(
        "--catalog-file",
        type=Path,
        default=DEFAULT_CATALOG_FILE,
        help="Scenario catalog markdown file.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and validate the catalog without writing to MongoDB.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging output.",
    )
    return parser.parse_args()


def relative_project_path(file_path: Path) -> str:
    """Return a project-relative path for stable Mongo documents."""
    return str(file_path.resolve().relative_to(project_root))


def extract_asset(label: str, body: str) -> str | None:
    """Extract a backticked technical asset path from a scenario body."""
    match = re.search(rf"- \*\*{re.escape(label)}:\*\* `([^`]+)`", body)
    return match.group(1) if match else None


def iter_scenario_sections(catalog_file: Path) -> Iterable[Tuple[str, str, str]]:
    """Yield scenario_id, title, and body for each documented scenario."""
    lines = catalog_file.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        heading_match = SCENARIO_HEADING_RE.match(lines[index])
        if not heading_match:
            index += 1
            continue

        title = heading_match.group("title").strip()
        scenario_id = heading_match.group("scenario_id")
        start = index + 1
        index = start
        while index < len(lines) and not NEXT_HEADING_RE.match(lines[index]):
            index += 1
        body = "\n".join(lines[start:index]).strip()
        yield scenario_id, title, body


def build_scenario_document(
    scenario_id: str,
    title: str,
    body: str,
    catalog_file: Path,
) -> Dict[str, Any]:
    """Build a MongoDB scenario document from one catalog section."""
    sql_path = extract_asset("SQL Transformation", body)
    runner_path = extract_asset("Python Runner", body)
    target_table = extract_asset("Target Table", body)

    asset_paths = {
        "sql": sql_path,
        "runner": runner_path,
        "target_table": target_table,
    }
    missing = [key for key, value in asset_paths.items() if not value]
    if missing:
        raise ValueError(f"{scenario_id} missing assets: {missing}")

    return {
        "scenario_id": scenario_id,
        "status": "active",
        "title": title,
        "asset_paths": asset_paths,
        "source_path": relative_project_path(catalog_file),
        "markdown_body": body,
        "tags": ["gold", "scenario"],
    }


def sync_scenarios(catalog_file: Path, dry_run: bool = False) -> Tuple[int, int]:
    """Sync scenarios to MongoDB; returns (processed, failed)."""
    processed = 0
    failed = 0

    mongo_client = None
    repository = None
    if not dry_run:
        from src.storage.mongodb import get_mongodb_client
        from src.storage.mongodb.repositories import ScenariosRepository

        mongo_client = get_mongodb_client()
        if not mongo_client.connect():
            raise RuntimeError("Could not connect to MongoDB")
        repository = ScenariosRepository(mongo_client.get_database())

    try:
        for scenario_id, title, body in iter_scenario_sections(catalog_file):
            try:
                document = build_scenario_document(scenario_id, title, body, catalog_file)
                if repository is not None:
                    repository.upsert_scenario(scenario_id, document)
                processed += 1
                logger.info(
                    "Scenario catalog synced",
                    scenario_id=scenario_id,
                    source_path=document["source_path"],
                    dry_run=dry_run,
                )
            except Exception as exc:
                failed += 1
                logger.error("Scenario catalog sync failed", scenario_id=scenario_id, error=str(exc))
    finally:
        if mongo_client is not None:
            mongo_client.disconnect()

    return processed, failed


def main() -> int:
    load_environment()
    args = parse_args()
    setup_logging(
        name="mongodb_sync_scenario_catalogs",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    catalog_file = args.catalog_file.resolve()
    if not catalog_file.is_file():
        logger.error("Scenario catalog file does not exist", catalog_file=str(catalog_file))
        return 2

    processed, failed = sync_scenarios(catalog_file, dry_run=args.dry_run)
    logger.info(
        "Scenario catalog sync finished",
        catalog_file=str(catalog_file),
        processed=processed,
        failed=failed,
        dry_run=args.dry_run,
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
