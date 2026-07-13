"""Shared SQL execution helpers for ClickHouse-backed medallion layers."""

import time
from dataclasses import dataclass
from pathlib import Path

from src.common.logging import get_logger
from src.integrations.clickhouse.client import ClickHouseClient

logger = get_logger(__name__)


@dataclass
class SQLExecutionSummary:
    """Summary for execution of a SQL script or statement bundle."""

    layer_name: str
    source_name: str
    total_statements: int
    successful_statements: int
    failed_statements: int
    duration_ms: float

    def as_log_fields(self) -> dict[str, object]:
        """Return compact structured fields for consistent logging."""
        return {
            "layer_name": self.layer_name,
            "source_name": self.source_name,
            "total_statements": self.total_statements,
            "successful_statements": self.successful_statements,
            "failed_statements": self.failed_statements,
            "duration_ms": self.duration_ms,
        }


def execute_sql_statements(
    client: ClickHouseClient,
    statements: list[str],
    layer_name: str,
    source_name: str,
    *,
    log_each_query: bool = False,
) -> SQLExecutionSummary:
    """Execute SQL statements and emit a final structured execution summary."""
    started_at = time.perf_counter()
    successful_statements = 0

    for statement in statements:
        client.execute(statement, log_query=log_each_query)
        successful_statements += 1

    summary = SQLExecutionSummary(
        layer_name=layer_name,
        source_name=source_name,
        total_statements=len(statements),
        successful_statements=successful_statements,
        failed_statements=len(statements) - successful_statements,
        duration_ms=round((time.perf_counter() - started_at) * 1000, 2),
    )
    logger.info("ClickHouse SQL execution summary", **summary.as_log_fields())
    return summary


def split_sql_statements(sql_content: str) -> list[str]:
    """Split SQL content into executable statements while skipping comments."""
    statements: list[str] = []
    current_statement: list[str] = []

    for line in sql_content.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue

        if "--" in line:
            line = line[: line.index("--")]

        stripped = line.strip()
        if not stripped:
            continue

        current_statement.append(stripped)
        if stripped.endswith(";"):
            statement = " ".join(current_statement).rstrip(";").strip()
            if statement:
                statements.append(statement)
            current_statement = []

    if current_statement:
        statement = " ".join(current_statement).strip()
        if statement:
            statements.append(statement)

    return statements


def execute_sql_script(
    client: ClickHouseClient,
    sql_file: Path,
    layer_name: str,
) -> SQLExecutionSummary:
    """Execute one layer SQL file statement by statement."""
    sql_content = sql_file.read_text(encoding="utf-8")
    statements = split_sql_statements(sql_content)

    if not statements:
        logger.warning("No executable %s SQL found in %s", layer_name, sql_file.name)
        return SQLExecutionSummary(
            layer_name=layer_name,
            source_name=sql_file.name,
            total_statements=0,
            successful_statements=0,
            failed_statements=0,
            duration_ms=0.0,
        )

    logger.info(
        "Executing %s SQL from %s (%s statements)",
        layer_name,
        sql_file.name,
        len(statements),
    )
    return execute_sql_statements(
        client=client,
        statements=statements,
        layer_name=layer_name,
        source_name=sql_file.name,
    )
