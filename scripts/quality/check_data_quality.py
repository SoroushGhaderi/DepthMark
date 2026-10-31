"""Run unified, read-only warehouse data-quality checks."""

import argparse
import sys
from collections.abc import Sequence
from contextlib import ExitStack
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
scripts_dir = Path(__file__).resolve().parents[1]
for candidate in (str(project_root), str(scripts_dir)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

from src.common.logging import get_logger
from src.fotmob.gold.signal_catalog import SignalCatalogError
from src.warehouse.identities import WarehouseConnectionError, warehouse_session
from src.warehouse.quality import (
    DataQualityService,
    DataQualitySummary,
    build_identity_contracts,
    reconciliation_check_names,
)
from src.warehouse.scope import WarehouseExecutionScope

logger = get_logger(__name__)
LAYERS = ("bronze", "silver", "gold")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Check duplicate row identities across Bronze, Silver, and Gold, and reconcile "
            "Bronze to Silver only"
        )
    )
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--date", help="Check one match date (YYYYMMDD)")
    scope.add_argument("--month", help="Check one calendar month (YYYYMM)")
    scope.add_argument(
        "--full-history", action="store_true", help="Check all available warehouse history"
    )
    parser.add_argument(
        "--layers",
        default="all",
        help="Comma-separated duplicate-check layers: bronze,silver,gold or all (default: all)",
    )
    parser.add_argument(
        "--reconciliation-checks",
        default="auto",
        help=(
            "Comma-separated Bronze-to-Silver checks, all, none, or auto (default: auto; "
            "all when Bronze and Silver layers are selected)"
        ),
    )
    parser.add_argument(
        "--sample-limit",
        type=int,
        default=100,
        help="Maximum duplicate or mismatch samples per check (default: 100)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 1 when logical duplicates or Bronze-to-Silver mismatches are found",
    )
    return parser.parse_args(argv)


def _scope_from_args(args: argparse.Namespace) -> WarehouseExecutionScope:
    if args.date:
        return WarehouseExecutionScope.for_date(args.date)
    if args.month:
        return WarehouseExecutionScope.for_month(args.month)
    return WarehouseExecutionScope.full_history()


def _resolve_csv(raw_value: str, available: Sequence[str], label: str) -> list[str]:
    normalized = raw_value.strip().lower()
    if normalized == "all":
        return list(available)
    if normalized == "none":
        return []
    values = [value.strip().lower() for value in raw_value.split(",") if value.strip()]
    unknown = [value for value in values if value not in available]
    if unknown:
        raise ValueError(f"Unknown {label}: {unknown}. Allowed: {list(available)}, all, or none")
    return values


def _log_summary(summary: DataQualitySummary, scope: WarehouseExecutionScope) -> None:
    for result in summary.duplicate_results:
        log = logger.warning if result.duplicate_identities else logger.info
        log(
            "Logical duplicate identity check",
            table=result.table,
            scope=scope.label,
            identity_columns=list(result.identity_columns),
            duplicate_identities=result.duplicate_identities,
            duplicate_rows=result.duplicate_rows,
        )
        for sample in result.samples:
            logger.warning(
                "Logical duplicate identity sample", table=result.table, sample=list(sample)
            )
        physical_log = logger.warning if result.physical_duplicate_identities else logger.info
        physical_log(
            "Physical row-version diagnostic",
            table=result.table,
            scope=scope.label,
            identity_columns=list(result.identity_columns),
            identities_with_multiple_versions=result.physical_duplicate_identities,
            physical_extra_versions=result.physical_extra_versions,
            strict_failure=False,
        )
        for sample in result.physical_samples:
            logger.warning("Physical row-version sample", table=result.table, sample=list(sample))
    for skipped in summary.skipped_tables:
        logger.warning("Table not validated", table=skipped.table, reason=skipped.reason)
    for result in summary.reconciliation_results:
        log = logger.warning if result.failed else logger.info
        log(
            "Bronze-to-Silver reconciliation",
            check=result.name,
            scope=scope.label,
            bronze_count=result.bronze_count,
            silver_count=result.silver_count,
            missing_from_silver=result.missing_from_silver,
            unexpected_in_silver=result.unexpected_in_silver,
        )
        for sample in result.missing_samples:
            logger.warning("Missing from Silver sample", check=result.name, sample=list(sample))
        for sample in result.unexpected_samples:
            logger.warning("Unexpected in Silver sample", check=result.name, sample=list(sample))
    for partition in summary.unpublished_partitions:
        logger.warning(
            "Unpublished warehouse partition",
            batch=partition.batch,
            partition=partition.partition_label,
            status=partition.status,
            run_id=partition.run_id,
            scope=partition.scope_label,
            committed_tables=len(partition.committed_tables),
        )


def strict_exit_code(summary: DataQualitySummary, strict: bool) -> int:
    """Return the documented outcome code for a completed quality run."""
    return 1 if strict and summary.has_failures else 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.sample_limit <= 0:
        logger.error("sample-limit must be a positive integer", sample_limit=args.sample_limit)
        return 2
    try:
        scope = _scope_from_args(args)
        layers = _resolve_csv(args.layers, LAYERS, "layers")
        raw_checks = args.reconciliation_checks
        if raw_checks.strip().lower() == "auto":
            checks = reconciliation_check_names() if {"bronze", "silver"} <= set(layers) else []
        else:
            checks = _resolve_csv(raw_checks, reconciliation_check_names(), "reconciliation checks")
    except ValueError as error:
        logger.error(str(error))
        return 2

    try:
        identities = build_identity_contracts(project_root)
    except SignalCatalogError as error:
        for violation in error.violations:
            logger.error("Signal catalog violation", violation=violation.describe())
        logger.error(
            "Signal catalog is invalid; quality checks not run",
            violations=len(error.violations),
        )
        return 1

    with ExitStack() as stack:
        try:
            client = stack.enter_context(warehouse_session())
        except WarehouseConnectionError as error:
            logger.error(str(error))
            return 1
        try:
            logger.info(
                "Running unified warehouse data quality",
                scope=scope.label,
                layers=layers,
                reconciliation_checks=checks,
                strict=args.strict,
            )
            summary = DataQualityService(client, project_root, identities=identities).run(
                scope=scope,
                layers=layers,
                reconciliation_checks=checks,
                sample_limit=args.sample_limit,
            )
            _log_summary(summary, scope)
            exit_code = strict_exit_code(summary, args.strict)
            logger.info(
                "Unified warehouse data quality completed",
                logical_duplicate_failures=summary.duplicate_failure_count,
                reconciliation_failures=summary.reconciliation_failure_count,
                unpublished_partitions=len(summary.unpublished_partitions),
                unvalidated_tables=len(summary.skipped_tables),
                exit_code=exit_code,
            )
            return exit_code
        except Exception as error:
            logger.exception("Unified warehouse data quality failed", error=str(error))
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
