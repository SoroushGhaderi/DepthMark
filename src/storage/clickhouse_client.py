"""ClickHouse client for Bronze, Silver, and Gold warehouse operations."""

import re
import time
from dataclasses import asdict, dataclass
from typing import Any, Dict, Optional

import clickhouse_connect

from ..utils.health_check import check_clickhouse_connection
from ..utils.logging_utils import get_logger

logger = get_logger(__name__)


@dataclass
class QueryExecutionSummary:
    """Normalized summary emitted for every ClickHouse query execution."""

    query_type: str
    duration_ms: float
    success: bool
    error: Optional[str] = None

    def as_log_fields(self) -> Dict[str, Any]:
        """Return compact structured fields suitable for structured logs."""
        fields = asdict(self)
        return {key: value for key, value in fields.items() if value is not None}


class ClickHouseClient:
    """ClickHouse client for data warehouse operations."""

    ALLOWED_TABLES = {
        "match_reference",
        "general",
        "timeline",
        "venue",
        "player",
        "shotmap",
        "goal",
        "cards",
        "red_card",
        "period",
        "momentum",
        "starters",
        "substitutes",
        "coaches",
        "team_form",
        "event",
        "match_payload",
        "market",
        "oddspedia_match_resolution",
        "scenario_demolition",
        "scenario_defensive_shutdown_win",
        "scenario_underdog_heist",
        "scenario_dead_ball_dominance",
        "scenario_low_block_heist",
        "scenario_tactical_stalemate",
        "scenario_great_escape",
        "scenario_one_man_army",
        "scenario_last_gasp",
        "scenario_shot_stopper",
        "scenario_war_zone",
        "scenario_clinical_finisher",
        "scenario_russian_roulette",
        "scenario_efficiency_machine",
        "scenario_away_day_masterclass",
        "scenario_key_pass_king",
        "scenario_wildcard",
        "scenario_lead_by_example",
        "scenario_young_gun",
        "scenario_second_half_warriors",
        "scenario_big_chance_killer",
        "scenario_ten_men_stand",
        "scenario_progressive_powerhouse",
        "scenario_sterile_control",
        "scenario_defensive_masterclass",
        "scenario_metronome",
        "scenario_high_intensity_engine",
        "scenario_box_to_box_general",
        "scenario_against_the_grain",
        "scenario_unpunished_aggression",
        "scenario_pressing_masterclass",
        "scenario_elite_shot_stopper",
        "scenario_hollow_dominance",
        "scenario_touchline_terror",
        "scenario_line_breaker",
        "scenario_basketball_match",
        "scenario_lightning_rod",
        "scenario_human_shield",
        "scenario_golden_touch",
        "scenario_chaos_engine",
        "scenario_tired_legs",
        "scenario_black_hole",
        "scenario_high_line_trap",
        "scenario_ghost_poacher",
        "scenario_route_one_masterclass",
        "scenario_total_suffocation",
        "scenario_territorial_suffocation",
        "scenario_clinical_pivot",
        "player_match_stats",
        "match_summary",
        "team_season_stats",
    }

    def __init__(
        self,
        host: str = "localhost",
        port: int = 8123,
        username: str = "default",
        password: str = "",
        database: str = "default",
    ):
        """Initialize ClickHouse client.

        Args:
            host: ClickHouse server host
            port: ClickHouse HTTP port
            username: ClickHouse username
            password: ClickHouse password
            database: Database name
        """
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.logger = logger
        self.client: Optional[clickhouse_connect.driver.Client] = None

    def _validate_table_name(self, table: str) -> str:
        """Validate table name against whitelist to prevent SQL injection.

        Args:
            table: Table name to validate

        Returns:
            Validated table name

        Raises:
            ValueError: If table name not in whitelist
        """
        if table not in self.ALLOWED_TABLES:
            raise ValueError(
                f"Invalid table name: '{table}'. "
                f"Allowed tables: {', '.join(sorted(self.ALLOWED_TABLES))}"
            )
        return table

    _SAFE_IDENT = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
    _QUERY_TYPE_RE = re.compile(r"^\s*([a-zA-Z]+)")
    _LEADING_SQL_COMMENTS_RE = re.compile(
        r"^\s*(?:(?:--[^\n]*(?:\n|$))|(?:/\*.*?\*/\s*))*",
        re.DOTALL,
    )

    @classmethod
    def summarize_query(cls, query: str, max_preview_length: int = 160) -> Dict[str, Any]:
        """Build a lightweight summary for a raw SQL query string."""
        query_without_leading_comments = cls._LEADING_SQL_COMMENTS_RE.sub("", query, count=1)
        query_clean = " ".join(query_without_leading_comments.split())
        query_type_match = cls._QUERY_TYPE_RE.match(query_clean)
        query_type = query_type_match.group(1).upper() if query_type_match else "UNKNOWN"
        return {"query_type": query_type}

    def _validate_identifier(self, value: str, kind: str = "identifier") -> str:
        """Validate database/table identifier to prevent SQL injection.

        Args:
            value: Identifier to validate
            kind: Description of identifier type for error messages

        Returns:
            Validated identifier

        Raises:
            ValueError: If identifier contains unsafe characters
        """
        if not self._SAFE_IDENT.match(value):
            raise ValueError(f"Unsafe {kind}: '{value}'")
        return value

    def connect(self) -> bool:
        """Connect to ClickHouse server."""
        try:
            self.client = clickhouse_connect.get_client(
                host=self.host,
                port=self.port,
                username=self.username,
                password=self.password,
                database=self.database,
            )

            self.client.query("SELECT 1")
            self.logger.info(f"Connected to ClickHouse: {self.host}:{self.port}/{self.database}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to connect to ClickHouse: {e}")
            return False

    def disconnect(self):
        """Disconnect from ClickHouse."""
        if self.client:
            self.client.close()
            self.client = None

    def execute(
        self,
        query: str,
        parameters: Optional[Dict[str, Any]] = None,
        *,
        log_query: bool = True,
    ) -> Any:
        """Execute a query."""
        if not self.client:
            raise RuntimeError("Not connected to ClickHouse. Call connect() first.")

        query_summary = self.summarize_query(query)
        started_at = time.perf_counter()

        try:
            if parameters:
                result = self.client.query(query, parameters=parameters)
            else:
                result = self.client.query(query)

            execution_summary = QueryExecutionSummary(
                query_type=query_summary["query_type"],
                duration_ms=round((time.perf_counter() - started_at) * 1000, 2),
                success=True,
            )
            if log_query:
                self.logger.info(
                    "ClickHouse query executed",
                    **execution_summary.as_log_fields(),
                )
            return result
        except Exception as e:
            execution_summary = QueryExecutionSummary(
                query_type=query_summary["query_type"],
                duration_ms=round((time.perf_counter() - started_at) * 1000, 2),
                success=False,
                error=str(e),
            )
            if log_query:
                self.logger.error(
                    "ClickHouse query failed",
                    **execution_summary.as_log_fields(),
                )
            raise

    def insert_dataframe(self, table: str, df, database: Optional[str] = None) -> int:
        """Insert pandas DataFrame to ClickHouse table with SQL injection protection.

        Args:
            table: Table name (validated against whitelist)
            df: Pandas DataFrame
            database: Optional database name (overrides default)

        Returns:
            Number of rows inserted

        Raises:
            ValueError: If table name not in whitelist
        """
        if not self.client:
            raise RuntimeError("Not connected to ClickHouse. Call connect() first.")

        table = self._validate_table_name(table)

        if df.empty:
            self.logger.warning(f"DataFrame is empty, skipping insert to {table}")
            return 0

        try:
            db = database or self.database
            full_table = f"{db}.{table}" if db else table

            self.client.insert_df(full_table, df)
            rows_inserted = len(df)
            self.logger.info(f"Inserted {rows_inserted} rows to {full_table}")
            return rows_inserted

        except Exception as e:
            self.logger.error(f"Failed to insert to {table}: {e}")
            raise

    def get_table_stats(self, table: str, database: Optional[str] = None) -> Dict[str, Any]:
        """Get table statistics with SQL injection protection.

        Args:
            table: Table name (validated against whitelist)
            database: Optional database name

        Returns:
            Dictionary with table statistics

        Raises:
            ValueError: If table name not in whitelist
        """
        if not self.client:
            raise RuntimeError("Not connected to ClickHouse. Call connect() first.")

        table = self._validate_table_name(table)

        db = database or self.database
        db = self._validate_identifier(db, "database")
        full_table = f"{db}.{table}" if db else table

        try:
            count_result = self.execute(f"SELECT COUNT(*) as count FROM {full_table}")
            row_count = count_result.result_rows[0][0] if count_result.result_rows else 0

            size_query = (
                f"SELECT formatReadableSize(sum(bytes)) as size, sum(rows) as rows "
                f"FROM system.parts WHERE database = '{db}' AND table = '{table}' AND active"
            )
            size_result = self.execute(size_query)
            size_info = size_result.result_rows[0] if size_result.result_rows else ("0 B", 0)

            return {
                "table": full_table,
                "row_count": row_count,
                "size": size_info[0],
                "rows_in_parts": size_info[1],
            }

        except Exception as e:
            self.logger.error(f"Failed to get stats for {table}: {e}")
            return {"table": full_table, "error": str(e)}

    def truncate_table(self, table: str, database: Optional[str] = None):
        """Truncate a table with SQL injection protection.

        Args:
            table: Table name (validated against whitelist)
            database: Optional database name

        Raises:
            ValueError: If table name not in whitelist
        """
        if not self.client:
            raise RuntimeError("Not connected to ClickHouse. Call connect() first.")

        table = self._validate_table_name(table)

        db = database or self.database
        db = self._validate_identifier(db, "database")
        full_table = f"{db}.{table}" if db else table

        try:
            self.execute(f"TRUNCATE TABLE {full_table}")
            self.logger.info(f"Truncated table {full_table}")
        except Exception as e:
            self.logger.error(f"Failed to truncate {table}: {e}")
            raise

    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()

    def health_check(self) -> Dict[str, Any]:
        """Check ClickHouse connection health.

        Returns:
            Dictionary with health check results
        """
        return check_clickhouse_connection(
            host=self.host,
            port=self.port,
            username=self.username,
            password=self.password,
            database=self.database,
        )
