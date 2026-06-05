"""Build deterministic per-match signal activation IDs in ClickHouse."""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import yaml
from dotenv import load_dotenv

project_root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(project_root))

from config.settings import settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_db, gold_signals_db
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)

DEFAULT_CATALOG_DIR = project_root / "scripts" / "gold" / "signal" / "catalogs"
FRONTMATTER_DELIMITER = "\n---\n"
SIGNAL_ID_VERSION = "v1"
SAFE_IDENTIFIER_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")


@dataclass(frozen=True)
class SignalCatalog:
    signal_id: str
    row_identity: list[str]
    signal_prefix: str
    signal_entity: str
    signal_family: str
    signal_subfamily: str
    signal_name: str
    signal_tags: list[str]


def load_environment() -> None:
    """Load env vars for local script execution."""
    env_files = [
        project_root / ".env",
        project_root.parent / ".env",
    ]
    for env_file in env_files:
        if env_file.exists():
            load_dotenv(env_file, override=False)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build deterministic signal activation IDs into gold.signal_activations."
    )
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        default=DEFAULT_CATALOG_DIR,
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


def _parse_signal_id_parts(signal_id: str) -> tuple[str, str, str, str, str, list[str]]:
    parts = signal_id.split("_")
    if len(parts) < 5:
        raise ValueError(
            f"signal_id '{signal_id}' must have at least 5 underscore-separated parts"
        )
    if parts[0] != "sig":
        raise ValueError(f"signal_id '{signal_id}' must start with 'sig_'")

    signal_prefix = parts[0]
    signal_entity = parts[1]
    signal_family = parts[2]
    signal_subfamily = parts[3]
    signal_name = "_".join(parts[4:])
    signal_tags = [signal_family, signal_subfamily]
    return (
        signal_prefix,
        signal_entity,
        signal_family,
        signal_subfamily,
        signal_name,
        signal_tags,
    )


def split_frontmatter(content: str, source_path: Path) -> tuple[dict, str]:
    """Split markdown into frontmatter dict and body text."""
    if not content.startswith("---\n"):
        raise ValueError(f"Missing YAML frontmatter start in {source_path}")

    parts = content.split(FRONTMATTER_DELIMITER, 1)
    if len(parts) != 2:
        raise ValueError(f"Missing YAML frontmatter end in {source_path}")

    yaml_block = parts[0][4:]
    body = parts[1].strip()

    frontmatter = yaml.safe_load(yaml_block) or {}
    if not isinstance(frontmatter, dict):
        raise ValueError(f"Frontmatter is not an object in {source_path}")

    return frontmatter, body


def iter_signal_catalogs(catalog_dir: Path) -> Iterable[SignalCatalog]:
    """Yield active signal metadata from markdown catalogs."""
    for file_path in sorted(catalog_dir.glob("*.md")):
        if file_path.name.lower() == "readme.md":
            continue

        content = file_path.read_text(encoding="utf-8")
        frontmatter, _ = split_frontmatter(content, file_path)

        signal_id = str(frontmatter.get("signal_id", "")).strip()
        if not signal_id:
            raise ValueError(f"Missing signal_id in {file_path}")

        if signal_id != file_path.stem:
            raise ValueError(
                f"signal_id '{signal_id}' does not match file name '{file_path.stem}' in {file_path}"
            )

        if str(frontmatter.get("status", "")).lower() != "active":
            continue

        row_identity = frontmatter.get("row_identity")
        if not isinstance(row_identity, list) or not all(isinstance(v, str) for v in row_identity):
            raise ValueError(f"row_identity must be a list of strings in {file_path}")

        (
            signal_prefix,
            signal_entity,
            signal_family,
            signal_subfamily,
            signal_name,
            signal_tags,
        ) = _parse_signal_id_parts(signal_id)

        frontmatter_entity = str(frontmatter.get("entity", "")).strip()
        frontmatter_family = str(frontmatter.get("family", "")).strip()
        frontmatter_subfamily = str(frontmatter.get("subfamily", "")).strip()
        if frontmatter_entity and frontmatter_entity != signal_entity:
            logger.warning(
                "signal_id/frontmatter entity mismatch; using parsed signal_id entity",
                signal_id=signal_id,
                parsed_entity=signal_entity,
                frontmatter_entity=frontmatter_entity,
                source_path=str(file_path),
            )
        if frontmatter_family and frontmatter_family != signal_family:
            logger.warning(
                "signal_id/frontmatter family mismatch; using parsed signal_id family",
                signal_id=signal_id,
                parsed_family=signal_family,
                frontmatter_family=frontmatter_family,
                source_path=str(file_path),
            )
        if frontmatter_subfamily and frontmatter_subfamily != signal_subfamily:
            logger.warning(
                "signal_id/frontmatter subfamily mismatch; using parsed signal_id subfamily",
                signal_id=signal_id,
                parsed_subfamily=signal_subfamily,
                frontmatter_subfamily=frontmatter_subfamily,
                source_path=str(file_path),
            )

        yield SignalCatalog(
            signal_id=signal_id,
            row_identity=row_identity,
            signal_prefix=signal_prefix,
            signal_entity=signal_entity,
            signal_family=signal_family,
            signal_subfamily=signal_subfamily,
            signal_name=signal_name,
            signal_tags=signal_tags,
        )


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


def _identity_fields(row_identity: list[str]) -> list[str]:
    # Enforce deterministic field order from catalog and guarantee match_id inclusion.
    if "match_id" in row_identity:
        return row_identity
    return ["match_id", *row_identity]


def _hash_component_expr(column_name: str) -> str:
    safe_col = _validate_identifier(column_name, "column name")
    return f"coalesce(toString({safe_col}), '')"


def _activation_insert_sql(
    source_database: str,
    target_database: str,
    catalog: SignalCatalog,
    available_columns: set[str],
) -> str:
    safe_source_database = _validate_identifier(source_database, "source database")
    safe_target_database = _validate_identifier(target_database, "target database")
    safe_signal_table = _validate_identifier(catalog.signal_id, "table")

    def optional_col(column: str, cast_type: str) -> str:
        safe_col = _validate_identifier(column, "column name")
        if column in available_columns:
            return safe_col
        return f"CAST(NULL, '{cast_type}')"

    key_fields = _identity_fields(catalog.row_identity)
    missing_key_fields = [field for field in key_fields if field not in available_columns]
    if missing_key_fields:
        raise ValueError(
            f"Signal {catalog.signal_id} is missing required row_identity columns: {missing_key_fields}"
        )

    key_expr_parts = [
        f"'{SIGNAL_ID_VERSION}'",
        f"'{catalog.signal_id}'",
        *[_hash_component_expr(field) for field in key_fields],
    ]
    key_expr = ", '|', ".join(key_expr_parts)

    match_date_expr = optional_col("match_date", "Nullable(Date)")
    return f"""
    INSERT INTO {safe_target_database}.signal_activations (
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
        triggered_side,
        triggered_team_id,
        triggered_player_id,
        source_table
    )
    SELECT
        lower(hex(SHA256(concat({key_expr})))) AS signal_instance_id,
        '{catalog.signal_id}' AS signal_id,
        '{SIGNAL_ID_VERSION}' AS signal_id_version,
        {_sql_string_literal(catalog.signal_prefix)} AS signal_prefix,
        {_sql_string_literal(catalog.signal_entity)} AS signal_entity,
        {_sql_string_literal(catalog.signal_family)} AS signal_family,
        {_sql_string_literal(catalog.signal_subfamily)} AS signal_subfamily,
        {_sql_string_literal(catalog.signal_name)} AS signal_name,
        {_sql_array_literal(catalog.signal_tags)} AS signal_tags,
        toInt32(match_id) AS match_id,
        toDate({match_date_expr}) AS match_date,
        {optional_col('triggered_side', 'Nullable(String)')} AS triggered_side,
        toNullable(toInt32({optional_col('triggered_team_id', 'Nullable(Int32)')})) AS triggered_team_id,
        toNullable(toInt32({optional_col('triggered_player_id', 'Nullable(Int32)')})) AS triggered_player_id,
        '{catalog.signal_id}' AS source_table
    FROM {safe_source_database}.{safe_signal_table}
    WHERE match_id > 0
      AND {match_date_expr} IS NOT NULL
    """


def build_signal_activations(
    client: ClickHouseClient,
    source_database: str,
    target_database: str,
    catalogs: list[SignalCatalog],
    dry_run: bool,
) -> tuple[int, int]:
    processed = 0
    skipped = 0

    if not dry_run:
        client.execute(
            f"TRUNCATE TABLE {_validate_identifier(target_database, 'database')}.signal_activations"
        )

    for catalog in catalogs:
        signal_table = catalog.signal_id
        if not _table_exists(client, source_database, signal_table):
            logger.warning(
                "Signal table not found; skipping activation backfill",
                signal_id=catalog.signal_id,
                table=f"{source_database}.{signal_table}",
            )
            skipped += 1
            continue

        columns = _column_names(client, source_database, signal_table)
        query = _activation_insert_sql(
            source_database=source_database,
            target_database=target_database,
            catalog=catalog,
            available_columns=columns,
        )

        if dry_run:
            logger.info(
                "[dry-run] Planned signal activation insert",
                signal_id=catalog.signal_id,
                identity_fields=",".join(_identity_fields(catalog.row_identity)),
            )
        else:
            client.execute(query)
            logger.info(
                "Signal activation rows inserted",
                signal_id=catalog.signal_id,
                identity_fields=",".join(_identity_fields(catalog.row_identity)),
            )
        processed += 1

    return processed, skipped


def main(argv: Optional[list[str]] = None) -> int:
    global logger
    load_environment()
    args = parse_args(argv)
    logger = setup_logging(
        name="gold_build_signal_activations",
        log_dir=settings.log_dir,
        log_level="DEBUG" if args.verbose else settings.log_level,
    )

    catalog_dir = args.catalog_dir.resolve()
    if not catalog_dir.exists():
        logger.error("Catalog directory does not exist", catalog_dir=str(catalog_dir))
        return 2

    try:
        catalogs = list(iter_signal_catalogs(catalog_dir))
    except Exception as exc:
        logger.error("Failed to parse signal catalogs", error=str(exc))
        return 1

    if not catalogs:
        logger.warning("No active signal catalogs found", catalog_dir=str(catalog_dir))
        return 0

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

    try:
        processed, skipped = build_signal_activations(
            client=client,
            source_database=args.source_db,
            target_database=args.target_db,
            catalogs=catalogs,
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
        logger.error("Signal activation build failed", error=str(exc))
        return 1
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
