"""Build and scope-replace enriched signal activation rows in ClickHouse."""

import argparse
import re
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.common.logging import get_logger, setup_logging
from src.fotmob.gold.signal_catalog import (
    SIGNAL_CATALOG_DIR,
    SIGNAL_IDENTITY_SCHEME_VERSION,
    SignalCatalogError,
    SignalDefinition,
    load_signal_catalog,
    signal_instance_id_expression,
)
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.databases import STAGING_DATABASE, gold_db, gold_signals_db
from src.warehouse.identities import client_for_scope
from src.warehouse.publication import (
    assert_upstream_published,
    gold_activations_publication,
    gold_outputs_publication,
)
from src.warehouse.scope import (
    WarehouseExecutionScope,
    add_warehouse_scope_arguments,
    execution_scope_from_args,
)
from src.warehouse.scoped_replace import ScopedReplacementBatch, ScopedSqlJob

logger = get_logger(__name__)

GOLD_SQL_DIR = project_root / "clickhouse" / "gold"
STAGE_TABLE = "signal_activations_stage"
SAFE_IDENTIFIER_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
STAGE_TABLE_SQL_FILE = (
    GOLD_SQL_DIR / "ddl" / "activations" / "create_table_signal_activations_stage.sql"
)
FINAL_INSERT_SQL_FILE = GOLD_SQL_DIR / "dml" / "activations" / "signal_activation_final_insert.sql"


def load_environment() -> None:
    """Load env vars for local script execution."""
    get_settings()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build enriched signal activation rows into gold.signal_activations."
    )
    add_warehouse_scope_arguments(parser)
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        default=SIGNAL_CATALOG_DIR,
        help="Directory containing signal catalog markdown files.",
    )
    parser.add_argument(
        "--source-db",
        default=gold_signals_db(),
        help="Source ClickHouse database that stores signal output tables (sig_*).",
    )
    parser.add_argument(
        "--target-db",
        default=gold_db(),
        help="Target ClickHouse database for signal_activations.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview planned inserts without writing to ClickHouse.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging output.",
    )
    return parser.parse_args(argv)


def _validate_identifier(value: str, kind: str) -> str:
    if not SAFE_IDENTIFIER_RE.match(value):
        raise ValueError(f"Unsafe {kind}: '{value}'")
    return value


def _sql_string_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _sql_array_literal(values: list[str]) -> str:
    return "[" + ", ".join(_sql_string_literal(value) for value in values) + "]"


def _column_names(client: ClickHouseClient, database: str, table: str) -> set[str]:
    result = client.execute(
        """
        SELECT name
        FROM system.columns
        WHERE database = %(database)s
          AND table = %(table)s
        """,
        {"database": database, "table": table},
        log_query=False,
    )
    return {str(row[0]) for row in result.result_rows}


def _table_exists(client: ClickHouseClient, database: str, table: str) -> bool:
    result = client.execute(
        """
        SELECT count()
        FROM system.tables
        WHERE database = %(database)s
          AND name = %(table)s
        """,
        {"database": database, "table": table},
        log_query=False,
    )
    return bool(result.result_rows and int(result.result_rows[0][0]) > 0)


def _source_row_json_expr(available_columns: set[str], table_alias: str = "") -> str:
    """Return a JSON object expression preserving source column names and JSON values."""
    json_parts = []
    for column in sorted(available_columns):
        safe_col = _validate_identifier(column, "column name")
        qualified_col = f"{table_alias}.{safe_col}" if table_alias else safe_col
        json_key = column.replace("\\", "\\\\").replace('"', '\\"')
        json_parts.append(
            f"""concat('"{json_key}":', if(isNull({qualified_col}), 'null', toJSONString({qualified_col})))"""
        )
    return "concat('{', arrayStringConcat([" + ", ".join(json_parts) + "], ','), '}')"


def _stage_table_name() -> str:
    return f"{STAGING_DATABASE}.{STAGE_TABLE}"


def _create_stage_table(client: ClickHouseClient) -> None:
    sql = STAGE_TABLE_SQL_FILE.read_text(encoding="utf-8")
    for statement in sql.split(";"):
        statement = statement.strip()
        if statement:
            client.execute(statement)


def _activation_insert_sql(
    source_database: str,
    definition: SignalDefinition,
    available_columns: set[str],
) -> str:
    safe_source_database = _validate_identifier(source_database, "source database")
    safe_signal_table = _validate_identifier(definition.signal_id, "table")
    stage_table = _stage_table_name()
    source_alias = "sig"
    match_reference_alias = "mr"
    venue_alias = "venue"

    def optional_col(column: str, cast_type: str) -> str:
        safe_col = _validate_identifier(column, "column name")
        if column in available_columns:
            return f"{source_alias}.{safe_col}"
        return f"CAST(NULL, '{cast_type}')"

    missing_key_fields = [
        field for field in definition.identity_fields if field not in available_columns
    ]
    if missing_key_fields:
        raise ValueError(
            f"Signal {definition.signal_id} is missing required row_identity columns: "
            f"{missing_key_fields}"
        )

    signal_instance_expr = (
        f"{source_alias}.signal_instance_id"
        if "signal_instance_id" in available_columns
        else signal_instance_id_expression(definition, source_alias)
    )

    match_date_expr = optional_col("match_date", "Nullable(Date)")
    return f"""
    INSERT INTO {stage_table} (
        signal_instance_id,
        signal_id,
        signal_id_version,
        signal_prefix,
        signal_entity,
        signal_family,
        signal_subfamily,
        signal_name,
        signal_tags,
        match_id,
        match_date,
        match_kickoff_utc,
        match_round,
        coverage_level,
        country_code,
        league_id,
        league_name,
        league_round_name,
        parent_league_id,
        parent_league_name,
        parent_league_season,
        parent_league_tournament_id,
        match_started,
        match_finished,
        full_score,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        home_score,
        away_score,
        stadium_name,
        stadium_city,
        stadium_country,
        stadium_latitude,
        stadium_longitude,
        stadium_capacity,
        stadium_surface,
        attendance,
        referee_name,
        referee_country,
        triggered_side,
        triggered_team_id,
        triggered_team_name,
        triggered_player_id,
        triggered_player_name,
        opponent_team_id,
        opponent_team_name,
        source_table,
        source_row_json,
        source_row_columns,
        inserted_at
    )
    SELECT
        {signal_instance_expr} AS signal_instance_id,
        '{definition.signal_id}' AS signal_id,
        '{SIGNAL_IDENTITY_SCHEME_VERSION}' AS signal_id_version,
        {_sql_string_literal(definition.prefix)} AS signal_prefix,
        {_sql_string_literal(definition.entity)} AS signal_entity,
        {_sql_string_literal(definition.family)} AS signal_family,
        {_sql_string_literal(definition.subfamily)} AS signal_subfamily,
        {_sql_string_literal(definition.name)} AS signal_name,
        {_sql_array_literal(list(definition.tags))} AS signal_tags,
        toInt32({source_alias}.match_id) AS match_id,
        toDate({match_date_expr}) AS match_date,
        parseDateTime64BestEffortOrNull(
            coalesce(nullIf({match_reference_alias}.match_time_utc, ''), nullIf({venue_alias}.match_date_utc, '')),
            3,
            'UTC'
        ) AS match_kickoff_utc,
        {match_reference_alias}.match_round AS match_round,
        {match_reference_alias}.coverage_level AS coverage_level,
        {match_reference_alias}.country_code AS country_code,
        {match_reference_alias}.league_id AS league_id,
        {match_reference_alias}.league_name AS league_name,
        {match_reference_alias}.league_round_name AS league_round_name,
        {match_reference_alias}.parent_league_id AS parent_league_id,
        {match_reference_alias}.parent_league_name AS parent_league_name,
        {match_reference_alias}.parent_league_season AS parent_league_season,
        {match_reference_alias}.parent_league_tournament_id AS parent_league_tournament_id,
        {match_reference_alias}.match_started AS match_started,
        {match_reference_alias}.match_finished AS match_finished,
        {match_reference_alias}.full_score AS full_score,
        toNullable(toInt32({optional_col("home_team_id", "Nullable(Int32)")})) AS home_team_id,
        toNullable(toString({optional_col("home_team_name", "Nullable(String)")})) AS home_team_name,
        toNullable(toInt32({optional_col("away_team_id", "Nullable(Int32)")})) AS away_team_id,
        toNullable(toString({optional_col("away_team_name", "Nullable(String)")})) AS away_team_name,
        toNullable(toInt32({optional_col("home_score", "Nullable(Int32)")})) AS home_score,
        toNullable(toInt32({optional_col("away_score", "Nullable(Int32)")})) AS away_score,
        {venue_alias}.stadium_name AS stadium_name,
        {venue_alias}.stadium_city AS stadium_city,
        {venue_alias}.stadium_country AS stadium_country,
        {venue_alias}.stadium_latitude AS stadium_latitude,
        {venue_alias}.stadium_longitude AS stadium_longitude,
        {venue_alias}.stadium_capacity AS stadium_capacity,
        {venue_alias}.stadium_surface AS stadium_surface,
        {venue_alias}.attendance AS attendance,
        {venue_alias}.referee_name AS referee_name,
        {venue_alias}.referee_country AS referee_country,
        toNullable(toString({optional_col("triggered_side", "Nullable(String)")})) AS triggered_side,
        toNullable(toInt32({optional_col("triggered_team_id", "Nullable(Int32)")})) AS triggered_team_id,
        toNullable(toString({optional_col("triggered_team_name", "Nullable(String)")})) AS triggered_team_name,
        toNullable(toInt32({optional_col("triggered_player_id", "Nullable(Int32)")})) AS triggered_player_id,
        toNullable(toString({optional_col("triggered_player_name", "Nullable(String)")})) AS triggered_player_name,
        toNullable(toInt32({optional_col("opponent_team_id", "Nullable(Int32)")})) AS opponent_team_id,
        toNullable(toString({optional_col("opponent_team_name", "Nullable(String)")})) AS opponent_team_name,
        '{definition.signal_id}' AS source_table,
        {_source_row_json_expr(available_columns, source_alias)} AS source_row_json,
        {_sql_array_literal(sorted(available_columns))} AS source_row_columns,
        now() AS inserted_at
    FROM {safe_source_database}.{safe_signal_table} AS {source_alias}
    LEFT JOIN bronze.match_reference AS {match_reference_alias}
        ON {match_reference_alias}.match_id = {source_alias}.match_id
    LEFT JOIN bronze.venue AS {venue_alias}
        ON {venue_alias}.match_id = {source_alias}.match_id
    WHERE {source_alias}.match_id > 0
      AND {match_date_expr} IS NOT NULL
    SETTINGS join_use_nulls = 1
    """


def _final_activation_insert_sql() -> str:
    return FINAL_INSERT_SQL_FILE.read_text(encoding="utf-8").rstrip(";")


def build_signal_activations(
    client: ClickHouseClient,
    source_database: str,
    target_database: str,
    definitions: tuple[SignalDefinition, ...],
    scope: WarehouseExecutionScope,
    dry_run: bool,
) -> tuple[int, int]:
    processed = 0
    skipped = 0

    if not dry_run:
        assert_upstream_published(
            client, gold_outputs_publication(), consumer="Signal activation build"
        )
        _create_stage_table(client)

    for definition in definitions:
        signal_table = definition.signal_id
        if not _table_exists(client, source_database, signal_table):
            logger.warning(
                "Signal table not found; skipping activation backfill",
                signal_id=definition.signal_id,
                table=f"{source_database}.{signal_table}",
            )
            skipped += 1
            continue

        columns = _column_names(client, source_database, signal_table)
        query = _activation_insert_sql(
            source_database=source_database,
            definition=definition,
            available_columns=columns,
        )

        if dry_run:
            logger.info(
                "[dry-run] Planned signal activation insert",
                signal_id=definition.signal_id,
                identity_fields=",".join(definition.identity_fields),
            )
        else:
            client.execute(query)
            logger.info(
                "Signal activation stage rows inserted",
                signal_id=definition.signal_id,
                identity_fields=",".join(definition.identity_fields),
            )
        processed += 1

    target_table = f"{target_database}.signal_activations"
    final_insert_sql = _final_activation_insert_sql().replace(
        "gold.signal_activations",
        target_table,
        1,
    )
    activation_job = ScopedSqlJob(
        job_id="signal_activations",
        target_table=target_table,
        statements=(final_insert_sql,),
        date_expression="match_date",
    )
    ScopedReplacementBatch(
        client if not dry_run else None,
        scope,
        dry_run=dry_run,
        log=logger,
        publication=gold_activations_publication(),
    ).run([activation_job])

    if not dry_run:
        client.execute(f"DROP TABLE IF EXISTS {_stage_table_name()}")

    return processed, skipped


def main(argv: list[str] | None = None) -> int:
    global logger
    load_environment()
    args = parse_args(argv)
    try:
        scope = execution_scope_from_args(args)
    except ValueError as error:
        logger.error("Invalid activation execution scope: %s", error)
        return 2
    settings = get_settings()
    logger = setup_logging(
        name="gold_build_signal_activations",
        log_dir=settings.log_dir,
        log_level="DEBUG" if args.verbose else settings.log_level,
    )

    try:
        catalog = load_signal_catalog(args.catalog_dir)
    except SignalCatalogError as error:
        for violation in error.violations:
            logger.error("Signal catalog violation", violation=violation.describe())
        logger.error("Signal catalog is invalid", violations=len(error.violations))
        return 1

    definitions = catalog.active()
    if not definitions:
        logger.warning("No active signal catalogs found", catalog_dir=str(catalog.catalog_dir))
        return 0

    try:
        client = client_for_scope(scope)
    except RuntimeError as identity_error:
        logger.error(str(identity_error))
        return 1

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        return 1

    try:
        processed, skipped = build_signal_activations(
            client=client,
            source_database=args.source_db,
            target_database=args.target_db,
            definitions=definitions,
            scope=scope,
            dry_run=args.dry_run,
        )
        logger.info(
            "Signal activation build completed",
            source_db=args.source_db,
            target_db=args.target_db,
            processed=processed,
            skipped=skipped,
            dry_run=args.dry_run,
        )
        return 0
    except Exception as exc:
        logger.exception("Signal activation build failed", error=str(exc))
        return 1
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
