"""Check bronze-to-silver entity coverage in ClickHouse.

This script reports whether entities present in bronze are missing in silver,
using eligibility filters aligned with silver DML rules to avoid false positives.
"""

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

project_root = Path(__file__).resolve().parents[2]
scripts_dir = Path(__file__).resolve().parents[1]
for candidate in (str(project_root), str(scripts_dir)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

from config.settings import settings
from src.services.telegram import LayerAlertData, TelegramClient
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)


@dataclass(frozen=True)
class CheckDefinition:
    """Entity-level reconciliation definition."""

    name: str
    keys: List[str]
    bronze_dataset_sql: str
    silver_dataset_sql: str


@dataclass(frozen=True)
class CheckQueries:
    """Generated SQL for a reconciliation check."""

    name: str
    keys: List[str]
    bronze_count_sql: str
    silver_count_sql: str
    missing_count_sql: str
    sample_sql: str


def _result_rows(result: Any) -> List[List[Any]]:
    if hasattr(result, "result_rows") and result.result_rows:
        return result.result_rows
    if isinstance(result, list):
        return result
    return []


def _query_scalar(client: ClickHouseClient, sql: str) -> int:
    rows = _result_rows(client.execute(sql, log_query=False))
    if not rows:
        return 0
    return int(rows[0][0])


def _query_rows(client: ClickHouseClient, sql: str) -> List[List[Any]]:
    return _result_rows(client.execute(sql, log_query=False))


def _format_row(row: List[Any]) -> str:
    return ", ".join(str(value) for value in row)


def _distinct_dataset_sql(table: str, keys: List[str], where: str = "") -> str:
    where_clause = f"\nWHERE {where}" if where else ""
    keys_csv = ", ".join(keys)
    return f"SELECT DISTINCT {keys_csv}\nFROM {table} FINAL{where_clause}"


def _personnel_bronze_dataset_sql() -> str:
    return """
        SELECT DISTINCT match_id, team_side, role, person_id
        FROM (
            SELECT
                match_id,
                team_side,
                'starter' AS role,
                player_id AS person_id
            FROM bronze.starters FINAL
            WHERE match_id > 0
              AND player_id > 0
              AND length(trim(BOTH ' ' FROM team_side)) > 0

            UNION ALL

            SELECT
                match_id,
                team_side,
                'substitute' AS role,
                player_id AS person_id
            FROM bronze.substitutes FINAL
            WHERE match_id > 0
              AND player_id > 0
              AND length(trim(BOTH ' ' FROM team_side)) > 0

            UNION ALL

            SELECT
                match_id,
                team_side,
                'coach' AS role,
                coach_id AS person_id
            FROM bronze.coaches FINAL
            WHERE match_id > 0
              AND coach_id > 0
              AND length(trim(BOTH ' ' FROM team_side)) > 0
        )
    """


def _build_definitions() -> Dict[str, CheckDefinition]:
    return {
        "match": CheckDefinition(
            name="match",
            keys=["match_id"],
            bronze_dataset_sql=_distinct_dataset_sql("bronze.general", ["match_id"]),
            silver_dataset_sql=_distinct_dataset_sql("silver.match", ["match_id"]),
        ),
        "player": CheckDefinition(
            name="player",
            keys=["match_id", "player_id"],
            bronze_dataset_sql=_distinct_dataset_sql(
                "bronze.player",
                ["match_id", "player_id"],
                where="team_id IS NOT NULL",
            ),
            silver_dataset_sql=_distinct_dataset_sql(
                "silver.player_match_stat",
                ["match_id", "player_id"],
            ),
        ),
        "shot": CheckDefinition(
            name="shot",
            keys=["match_id", "shot_id"],
            bronze_dataset_sql=_distinct_dataset_sql("bronze.shotmap", ["match_id", "shot_id"]),
            silver_dataset_sql=_distinct_dataset_sql("silver.shot", ["match_id", "shot_id"]),
        ),
        "card": CheckDefinition(
            name="card",
            keys=["match_id", "event_id"],
            bronze_dataset_sql=_distinct_dataset_sql("bronze.cards", ["match_id", "event_id"]),
            silver_dataset_sql=_distinct_dataset_sql("silver.card", ["match_id", "event_id"]),
        ),
        "personnel": CheckDefinition(
            name="personnel",
            keys=["match_id", "team_side", "role", "person_id"],
            bronze_dataset_sql=_personnel_bronze_dataset_sql(),
            silver_dataset_sql=_distinct_dataset_sql(
                "silver.match_personnel",
                ["match_id", "team_side", "role", "person_id"],
            ),
        ),
    }


def _build_queries(defn: CheckDefinition, sample_limit: int) -> CheckQueries:
    keys_csv = ", ".join(defn.keys)
    first_key = defn.keys[0]
    order_by_csv = ", ".join(f"b.{key}" for key in defn.keys)
    select_keys_csv = ", ".join(f"b.{key}" for key in defn.keys)

    bronze_subquery = f"(\n{defn.bronze_dataset_sql}\n)"
    silver_subquery = f"(\n{defn.silver_dataset_sql}\n)"

    return CheckQueries(
        name=defn.name,
        keys=defn.keys,
        bronze_count_sql=f"SELECT count() FROM {bronze_subquery} AS b",
        silver_count_sql=f"SELECT count() FROM {silver_subquery} AS s",
        missing_count_sql=(
            "SELECT count()\n"
            f"FROM {bronze_subquery} AS b\n"
            f"LEFT JOIN {silver_subquery} AS s USING ({keys_csv})\n"
            f"WHERE s.{first_key} IS NULL"
        ),
        sample_sql=(
            f"SELECT {select_keys_csv}\n"
            f"FROM {bronze_subquery} AS b\n"
            f"LEFT JOIN {silver_subquery} AS s USING ({keys_csv})\n"
            f"WHERE s.{first_key} IS NULL\n"
            f"ORDER BY {order_by_csv}\n"
            f"LIMIT {sample_limit}"
        ),
    )


def _build_all_queries(sample_limit: int) -> Dict[str, CheckQueries]:
    definitions = _build_definitions()
    return {
        check_name: _build_queries(defn, sample_limit=sample_limit)
        for check_name, defn in definitions.items()
    }


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check bronze->silver coverage for matches and match entities"
    )
    parser.add_argument(
        "--checks",
        default="all",
        help="Comma-separated checks: match,player,shot,card,personnel or all (default: all)",
    )
    parser.add_argument(
        "--sample-limit",
        type=int,
        default=100,
        help="Maximum number of missing-key samples to print per check (default: 100)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 if any missing entity is found",
    )
    return parser.parse_args(argv)


def _resolve_requested_checks(raw_value: str, available: List[str]) -> List[str]:
    if raw_value.strip().lower() == "all":
        return available

    requested = [item.strip().lower() for item in raw_value.split(",") if item.strip()]
    unknown = [item for item in requested if item not in available]
    if unknown:
        raise ValueError(f"Unknown checks: {unknown}. Allowed: {available} or all")
    return requested


def main(argv: Optional[List[str]] = None) -> int:
    start_time = time.perf_counter()
    args = parse_args(argv)

    if args.sample_limit <= 0:
        logger.error("sample-limit must be a positive integer", sample_limit=args.sample_limit)
        return 2

    specs = _build_all_queries(sample_limit=args.sample_limit)

    selected_checks: List[str] = []
    try:
        selected_checks = _resolve_requested_checks(args.checks, list(specs.keys()))
    except ValueError as error:
        logger.error(str(error))
        return 2

    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        return 1

    failures = 0
    check_summaries: List[Dict[str, Any]] = []
    exit_code = 0

    try:
        logger.info(
            "Running bronze->silver parity checks",
            checks=selected_checks,
            sample_limit=args.sample_limit,
            strict=args.strict,
        )

        for check_name in selected_checks:
            spec = specs[check_name]
            bronze_count = _query_scalar(client, spec.bronze_count_sql)
            silver_count = _query_scalar(client, spec.silver_count_sql)
            missing_count = _query_scalar(client, spec.missing_count_sql)
            matched_count = max(0, bronze_count - missing_count)
            coverage_pct = round((matched_count / bronze_count) * 100, 2) if bronze_count else 100.0
            extra_in_silver = max(0, silver_count - bronze_count)

            logger.info(
                "Record count summary",
                check=spec.name,
                bronze_eligible_count=bronze_count,
                silver_count=silver_count,
                missing_from_silver=missing_count,
                matched_count=matched_count,
                coverage_pct=coverage_pct,
                extra_in_silver=extra_in_silver,
            )
            check_summaries.append(
                {
                    "name": spec.name,
                    "bronze_count": bronze_count,
                    "silver_count": silver_count,
                    "missing_count": missing_count,
                    "matched_count": matched_count,
                    "coverage_pct": coverage_pct,
                    "extra_in_silver": extra_in_silver,
                }
            )

            if missing_count == 0:
                logger.info("[OK] No missing entities", check=spec.name)
                continue

            failures += 1
            logger.warning(
                "[FAIL] Missing entities found",
                check=spec.name,
                missing_count=missing_count,
                sample_fields=spec.keys,
            )

            sample_rows = _query_rows(client, spec.sample_sql)
            logger.warning(
                "Printed missing-key samples",
                check=spec.name,
                shown_samples=len(sample_rows),
                requested_limit=args.sample_limit,
            )
            for row in sample_rows:
                logger.warning(
                    "Missing key sample",
                    check=spec.name,
                    sample=_format_row(row),
                )

        if failures == 0:
            logger.info("Bronze->silver parity check passed")
            exit_code = 0
            return exit_code

        logger.warning(
            "Bronze->silver parity check completed with missing entities",
            failed_checks=failures,
            total_checks=len(selected_checks),
        )
        exit_code = 1 if args.strict else 0
        return exit_code
    finally:
        client.disconnect()
        total_checks = len(selected_checks)
        passed_checks = total_checks - failures
        total_missing = sum(item["missing_count"] for item in check_summaries)
        total_extra = sum(item["extra_in_silver"] for item in check_summaries)
        avg_coverage = (
            sum(item["coverage_pct"] for item in check_summaries) / len(check_summaries)
            if check_summaries
            else 0.0
        )
        min_coverage = min((item["coverage_pct"] for item in check_summaries), default=0.0)
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "layer_alert.html.j2",
            LayerAlertData(
                layer="quality",
                success=failures == 0,
                scope=f"checks={','.join(selected_checks)} | strict={args.strict}",
                duration_seconds=time.perf_counter() - start_time,
                details={
                    "Checks passed": f"{passed_checks}/{total_checks}",
                    "Total missing": str(total_missing),
                    "Total extras": str(total_extra),
                },
                insights={
                    "Avg coverage": f"{avg_coverage:.2f}%",
                    "Min coverage": f"{min_coverage:.2f}%",
                    "Strict mode": "enabled" if args.strict else "disabled",
                },
            ),
        )


if __name__ == "__main__":
    raise SystemExit(main())
