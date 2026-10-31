"""Mirror validated signal catalogs into the MongoDB signals collection.

The collection becomes an exact mirror of the catalog (ADR 0033): changed
signals are replaced whole, unchanged signals are not written, and documents
whose signal no longer has a catalog are deleted. An invalid catalog writes
nothing. Deleting more than ``MAX_PRUNE_FRACTION`` of the stored documents
requires ``--allow-mass-prune``. ``--dry-run`` reads MongoDB and reports the
plan without writing.
"""

import argparse
import hashlib
import json
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from config.settings import get_settings
from src.common.logging import get_logger, setup_logging
from src.common.paths import PROJECT_ROOT
from src.fotmob.gold.signal_catalog import (
    SIGNAL_CATALOG_DIR,
    SignalCatalog,
    SignalCatalogError,
    SignalDefinition,
    load_signal_catalog,
)

project_root = PROJECT_ROOT

logger = get_logger(__name__)

MAX_PRUNE_FRACTION = 0.10


@dataclass
class SignalSyncPlan:
    """Which signal documents a sync inserts, updates, leaves, and deletes."""

    inserts: list[str] = field(default_factory=list)
    updates: list[str] = field(default_factory=list)
    unchanged: list[str] = field(default_factory=list)
    deletes: list[str] = field(default_factory=list)

    def prune_refusal(self, stored_count: int, allow_mass_prune: bool) -> str | None:
        """Return why pruning is refused, or ``None`` when it may proceed."""
        if not self.deletes or allow_mass_prune:
            return None
        if len(self.deletes) == stored_count:
            return "the sync would delete every stored signal document"
        if len(self.deletes) > stored_count * MAX_PRUNE_FRACTION:
            return (
                f"the sync would delete {len(self.deletes)} of {stored_count} stored "
                f"signal documents (more than {MAX_PRUNE_FRACTION:.0%})"
            )
        return None


def load_environment() -> None:
    """Load env vars for local script execution."""
    get_settings()


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Mirror validated signal catalogs into the MongoDB signals collection."
    )
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        default=SIGNAL_CATALOG_DIR,
        help="Directory containing signal catalog markdown files.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read MongoDB and report inserts, updates, and deletes without writing.",
    )
    parser.add_argument(
        "--allow-mass-prune",
        action="store_true",
        help=(
            "Allow deleting more than "
            f"{MAX_PRUNE_FRACTION:.0%} of stored signal documents in one sync."
        ),
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging output.",
    )
    return parser.parse_args(argv)


def relative_project_path(file_path: Path) -> str:
    """Return a project-relative path for stable Mongo documents."""
    return file_path.resolve().relative_to(project_root).as_posix()


def _text_asset(file_path: Path) -> dict[str, Any]:
    content = file_path.read_text(encoding="utf-8")
    content_bytes = content.encode("utf-8")
    return {
        "path": relative_project_path(file_path),
        "content": content,
        "sha256": hashlib.sha256(content_bytes).hexdigest(),
        "byte_count": len(content_bytes),
    }


def content_sha256(document: Mapping[str, Any]) -> str:
    """Hash a signal document's content, independent of key order."""
    canonical = json.dumps(document, sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def build_signal_document(definition: SignalDefinition) -> dict[str, Any]:
    """Build the MongoDB document for one validated signal."""
    frontmatter = definition.frontmatter_dict()
    document: dict[str, Any] = {
        "signal_id": definition.signal_id,
        "status": definition.status,
        "entity": definition.entity,
        "family": definition.family,
        "subfamily": definition.subfamily,
        "grain": definition.grain,
        "headline": definition.headline,
        "trigger": definition.trigger,
        "row_identity": list(definition.row_identity),
        "asset_paths": frontmatter["asset_paths"],
        "assets": {"table": definition.table, "sql": _text_asset(definition.sql_path)},
        "frontmatter": frontmatter,
        "source_path": relative_project_path(definition.source_path),
        "markdown_body": definition.body,
    }
    document["content_sha256"] = content_sha256(document)
    return document


def plan_signal_sync(
    documents: Sequence[Mapping[str, Any]],
    stored_states: Mapping[str, Mapping[str, Any]],
) -> SignalSyncPlan:
    """Compare catalog documents with stored document hashes."""
    plan = SignalSyncPlan()
    catalog_ids = set()
    for document in documents:
        signal_id = document["signal_id"]
        catalog_ids.add(signal_id)
        stored = stored_states.get(signal_id)
        if stored is None:
            plan.inserts.append(signal_id)
        elif stored.get("content_sha256") != document["content_sha256"]:
            plan.updates.append(signal_id)
        else:
            plan.unchanged.append(signal_id)
    plan.deletes.extend(sorted(set(stored_states) - catalog_ids))
    return plan


def _log_plan(plan: SignalSyncPlan, dry_run: bool) -> None:
    for action, signal_ids in (
        ("insert", plan.inserts),
        ("update", plan.updates),
        ("delete", plan.deletes),
    ):
        for signal_id in signal_ids:
            logger.info("Signal catalog sync action", action=action, signal_id=signal_id)
    logger.info(
        "Signal catalog sync plan",
        inserts=len(plan.inserts),
        updates=len(plan.updates),
        unchanged=len(plan.unchanged),
        deletes=len(plan.deletes),
        dry_run=dry_run,
    )


def sync_signals(
    catalog: SignalCatalog,
    repository: Any,
    *,
    dry_run: bool = False,
    allow_mass_prune: bool = False,
) -> int:
    """Mirror the catalog into the repository; return a process exit code."""
    documents = [build_signal_document(definition) for definition in catalog]
    stored_states = repository.list_signal_states()
    plan = plan_signal_sync(documents, stored_states)
    _log_plan(plan, dry_run)

    refusal = plan.prune_refusal(len(stored_states), allow_mass_prune)
    if refusal is not None:
        logger.error(
            "Signal catalog sync refused; rerun with --allow-mass-prune if intended",
            reason=refusal,
        )
        return 1
    if dry_run:
        return 0

    changed = set(plan.inserts) | set(plan.updates)
    for document in documents:
        if document["signal_id"] in changed:
            stored = stored_states.get(document["signal_id"]) or {}
            repository.replace_signal(document, created_at=stored.get("created_at"))
    deleted_count = repository.delete_signals(plan.deletes)
    logger.info(
        "Signal catalog sync applied",
        written=len(changed),
        deleted=deleted_count,
    )
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    load_environment()
    args = parse_args(argv)
    setup_logging(
        name="mongodb_sync_signal_catalogs",
        log_dir="logs",
        log_level="DEBUG" if args.verbose else "INFO",
    )

    try:
        catalog = load_signal_catalog(args.catalog_dir)
    except SignalCatalogError as error:
        for violation in error.violations:
            logger.error("Signal catalog violation", violation=violation.describe())
        logger.error("Signal catalog is invalid; nothing synced", violations=len(error.violations))
        return 1

    from src.integrations.mongodb import get_mongodb_client
    from src.integrations.mongodb.repositories import SignalsRepository

    mongo_client = get_mongodb_client()
    if not mongo_client.connect():
        logger.error("Could not connect to MongoDB; nothing synced")
        return 1
    try:
        repository = SignalsRepository(mongo_client.get_database())
        return sync_signals(
            catalog,
            repository,
            dry_run=args.dry_run,
            allow_mass_prune=args.allow_mass_prune,
        )
    finally:
        mongo_client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
