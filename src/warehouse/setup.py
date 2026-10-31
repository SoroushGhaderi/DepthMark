"""Shared helpers for ClickHouse layer setup scripts."""

import re
import time
from collections.abc import Callable, Iterable
from pathlib import Path

from config.settings import get_settings
from src.common.logging import get_logger
from src.common.paths import PROJECT_ROOT
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.identities import Identity, provision_application_user, warehouse_client
from src.warehouse.schema_drift import (
    assert_setup_sql_is_non_destructive,
    find_schema_drift,
    format_drift_report,
    parse_expected_tables,
)

project_root = PROJECT_ROOT

logger = get_logger()

LAYER_ORDER = ("bronze", "silver", "gold")
SETUP_EXCLUDED_SQL_NAME_PARTS = ("optimize",)
TABLE_RECREATION_COMMAND = "python scripts/maintenance/recreate_clickhouse_tables.py --drifted"
CREATE_TABLE_PATTERN = re.compile(
    r"^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([`\"\w.]+)",
    re.IGNORECASE,
)
CLICKHOUSE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LOCAL_ENVIRONMENT_VALUES = {"local", "development", "dev"}
INSECURE_CLICKHOUSE_PASSWORDS = {
    "",
    "fotmob_pass",
    "password",
    "changeme",
    "your_clickhouse_password_here",
    "your_clickhouse_maintenance_password_here",
}


def is_local_development_environment() -> bool:
    """Return whether local-only development credentials are allowed.

    Reads DEPTHMARK_ENV, ENVIRONMENT, or SCRAPER_ENV (first set wins) from the
    process environment or either .env file; an unset selector is not local.
    """
    environment = get_settings().deployment_environment
    return bool(environment) and environment.strip().lower() in LOCAL_ENVIRONMENT_VALUES


def validate_clickhouse_credentials(
    username: str, password: str, variable: str = "CLICKHOUSE_USER"
) -> None:
    """Reject unsafe ClickHouse setup credentials outside explicit local development."""
    if not CLICKHOUSE_IDENTIFIER_PATTERN.fullmatch(username):
        raise RuntimeError(
            f"{variable} must be a simple ClickHouse identifier containing only "
            "letters, numbers, and underscores, and must not start with a number."
        )

    if is_local_development_environment():
        return

    if password.strip().lower() in INSECURE_CLICKHOUSE_PASSWORDS:
        raise RuntimeError(
            "Refusing to run ClickHouse setup with empty, placeholder, or local-dev "
            "credentials outside local development. Set DEPTHMARK_ENV=local for the "
            "tracked Docker/local-dev workflow, or provide production-grade "
            f"{variable.replace('_USER', '_PASSWORD')} credentials."
        )


def _host_candidates(host: str) -> list[str]:
    """Prefer published local ports for host-side runs, then the Docker DNS name."""
    if Path("/.dockerenv").exists():
        return [host]
    if host in ("clickhouse", "depthmark-clickhouse"):
        return ["localhost", "127.0.0.1", host]
    if host == "localhost":
        return ["localhost", "127.0.0.1"]
    return [host]


def maintenance_credentials() -> tuple[str, str]:
    """Return the validated maintenance identity that setup runs as (ADR 0029)."""
    settings = get_settings()
    if not settings.clickhouse_maintenance_user:
        raise RuntimeError(
            "ClickHouse setup runs as the maintenance identity; set "
            "CLICKHOUSE_MAINTENANCE_USER and CLICKHOUSE_MAINTENANCE_PASSWORD (ADR 0029)."
        )
    username = settings.clickhouse_maintenance_user
    password = settings.clickhouse_maintenance_password
    validate_clickhouse_credentials(username, password, "CLICKHOUSE_MAINTENANCE_USER")
    return username, password


def connect_clickhouse() -> ClickHouseClient:
    """Connect as the maintenance identity and provision the application identity.

    Setup creates databases and tables as the maintenance user, then creates or
    resets the application user (CLICKHOUSE_USER) to its narrow grant set.
    """
    settings = get_settings()
    app_username = settings.clickhouse_user
    app_password = settings.clickhouse_password
    validate_clickhouse_credentials(app_username, app_password)
    username, password = maintenance_credentials()
    if username == app_username:
        raise RuntimeError(
            "CLICKHOUSE_USER must differ from the maintenance identity so the application "
            "user can be granted narrower privileges (ADR 0029)."
        )

    attempted_hosts = []
    for candidate_host in dict.fromkeys(_host_candidates(settings.clickhouse_host)):
        attempted_hosts.append(candidate_host)
        logger.info(
            "Connecting to ClickHouse at %s:%s as %s",
            candidate_host,
            settings.clickhouse_port,
            username,
        )
        client = warehouse_client(Identity.MAINTENANCE, host=candidate_host)
        if client.connect():
            if not create_user_if_not_exists(client, app_username, app_password):
                client.disconnect()
                raise RuntimeError(
                    f"Failed to provision ClickHouse application user '{app_username}'"
                )
            return client

    raise RuntimeError(
        f"Failed to connect to ClickHouse as '{username}'. Tried hosts: "
        f"{', '.join(attempted_hosts)}"
    )


def create_user_if_not_exists(client: ClickHouseClient, username: str, password: str) -> bool:
    """Create the application user if missing and reset it to its narrow grants."""
    try:
        validate_clickhouse_credentials(username, password)
        logger.info("Provisioning ClickHouse application user '%s'", username)
        provision_application_user(client, username, password)
        return True
    except Exception as exc:
        logger.exception("Failed to provision user '%s': %s", username, exc)
        return False


def resolve_clickhouse_root() -> Path:
    """Locate the ClickHouse SQL root directory."""
    candidates = [
        project_root / "clickhouse",
        Path("/app/clickhouse"),
        Path("clickhouse"),
    ]
    root = next((path for path in candidates if path.exists()), None)
    if root is None:
        tried = "\n".join(f"  - {candidate}" for candidate in candidates)
        raise FileNotFoundError(f"ClickHouse SQL directory not found. Tried:\n{tried}")
    return root


def get_layer_sql_files(layer_name: str, clickhouse_root: Path | None = None) -> list[Path]:
    """Return ordered schema SQL files for a specific medallion layer."""
    if layer_name not in LAYER_ORDER:
        raise ValueError(f"Unknown layer '{layer_name}'")
    root = clickhouse_root or resolve_clickhouse_root()
    layer_dir = root / layer_name
    if not layer_dir.exists():
        raise FileNotFoundError(f"Missing SQL directory for layer '{layer_name}': {layer_dir}")

    # Gradual folder migration support:
    # - prefer new `ddl/`
    # - fall back to legacy `create/`
    # - finally support flat layer directory for existing bronze/gold layouts
    candidate_dirs = [layer_dir / "ddl", layer_dir / "create", layer_dir]
    if layer_name == "gold":
        # `ddl/activations/` holds the activation builder's ephemeral stage table,
        # which the builder drops and recreates itself; it is not setup DDL.
        candidate_dirs.extend(
            [
                layer_dir / "ddl" / "signals" / "match",
                layer_dir / "ddl" / "signals" / "player",
                layer_dir / "ddl" / "signals" / "team",
            ]
        )
    sql_by_name: dict[str, Path] = {}
    for candidate_dir in candidate_dirs:
        if not candidate_dir.exists():
            continue
        candidate_sql_files = [
            sql_file
            for sql_file in candidate_dir.glob("*.sql")
            if not sql_file.name.startswith("scenario_")
            and not _is_excluded_from_layer_setup(sql_file)
        ]
        for sql_file in sorted(candidate_sql_files, key=lambda path: path.name):
            if sql_file.name in sql_by_name:
                logger.warning(
                    "Skipping duplicate %s SQL file %s from %s; using %s",
                    layer_name,
                    sql_file.name,
                    candidate_dir,
                    sql_by_name[sql_file.name],
                )
                continue
            sql_by_name[sql_file.name] = sql_file

    if not sql_by_name:
        searched = ", ".join(str(path) for path in candidate_dirs)
        raise FileNotFoundError(
            f"No SQL files found for layer '{layer_name}'. Searched: {searched}"
        )

    def _sort_key(sql_file: Path) -> tuple[int, int, str]:
        name = sql_file.name
        number_prefix = re.match(r"^(\d+)_", name)
        if number_prefix:
            return (0, int(number_prefix.group(1)), name)
        if name == "create_tables.sql":
            return (1, 0, name)
        return (2, 0, name)

    return sorted(sql_by_name.values(), key=_sort_key)


def _is_excluded_from_layer_setup(sql_file: Path) -> bool:
    """Return whether a SQL file is intentionally outside schema setup."""
    normalized_name = sql_file.name.lower()
    return any(part in normalized_name for part in SETUP_EXCLUDED_SQL_NAME_PARTS)


def execute_sql_file(client: ClickHouseClient, sql_file: Path, database: str | None = None) -> bool:
    """Execute an SQL file statement by statement."""
    try:
        sql_content = sql_file.read_text(encoding="utf-8")
        if database:
            client.execute(f"USE {database}")
            client.database = database

        statements = []
        current_statement = []
        for line in sql_content.splitlines():
            if line.strip().startswith("--"):
                continue
            if "--" in line:
                line = line[: line.index("--")]
            line = line.strip()
            if not line:
                continue
            if database and line.upper().startswith("USE "):
                continue
            current_statement.append(line)
            if line.endswith(";"):
                statement = " ".join(current_statement).rstrip(";").strip()
                if statement:
                    statements.append(statement)
                current_statement = []

        if current_statement:
            statement = " ".join(current_statement).strip()
            if statement:
                statements.append(statement)

        total_statements = len(statements)
        executed_count = 0
        for statement in statements:
            normalized_statement = statement.strip()
            create_match = CREATE_TABLE_PATTERN.match(normalized_statement)
            table_name = create_match.group(1).strip('`"') if create_match else None
            statement_start = time.perf_counter()
            try:
                client.execute(statement)
                executed_count += 1
            except Exception as exc:
                if "already exists" in str(exc).lower():
                    executed_count += 1
                else:
                    logger.exception("Failed while executing %s: %s", sql_file.name, exc)
                    logger.error("Statement: %s", statement)
                    return False
            elapsed_seconds = time.perf_counter() - statement_start

            if table_name:
                logger.info(
                    "Table processed from %s: %s (%s/%s) in %.2f seconds",
                    sql_file.name,
                    table_name,
                    executed_count,
                    total_statements,
                    elapsed_seconds,
                )
            else:
                logger.info(
                    "Processed statement from %s (%s/%s) in %.2f seconds",
                    sql_file.name,
                    executed_count,
                    total_statements,
                    elapsed_seconds,
                )

        logger.info(
            "Executed %s/%s statements from %s", executed_count, total_statements, sql_file.name
        )
        return executed_count > 0
    except Exception as exc:
        logger.error("Error reading/executing %s: %s", sql_file, exc, exc_info=True)
        return False


def verify_setup_sql(client: ClickHouseClient, sql_files: list[Path]) -> bool:
    """Fail closed unless setup SQL is create-only and existing tables match it."""
    try:
        assert_setup_sql_is_non_destructive(sql_files)
    except ValueError as exc:
        logger.error("Refusing to run setup: %s", exc)
        return False
    drifts = find_schema_drift(client, parse_expected_tables(sql_files))
    if drifts:
        logger.error(
            "Refusing to run setup: %s existing table(s) drifted from their setup DDL.\n%s\n"
            "Setup never drops or alters tables. Plan the Table Recreation with `%s`, "
            "rerun it with --execute, then reload the affected scope.",
            len(drifts),
            format_drift_report(drifts),
            TABLE_RECREATION_COMMAND,
        )
        return False
    return True


def _execute_layer_sql_files(
    client: ClickHouseClient, layer_name: str, sql_files: list[Path]
) -> int:
    """Execute already-verified setup SQL files for one layer."""
    if not sql_files:
        logger.warning("No SQL files selected for %s layer setup", layer_name)
        return 0
    logger.info("Executing %s layer SQL...", layer_name.upper())
    for sql_file in sql_files:
        logger.info("Running %s", sql_file.name)
        file_start = time.perf_counter()
        succeeded = execute_sql_file(client, sql_file)
        elapsed_seconds = time.perf_counter() - file_start
        if not succeeded:
            logger.error("Failed %s in %.2f seconds", sql_file.name, elapsed_seconds)
            return 1
        logger.info("Completed %s in %.2f seconds", sql_file.name, elapsed_seconds)
    logger.info("%s layer setup completed", layer_name.upper())
    return 0


def run_clickhouse_layer_setup(
    layer_name: str,
    client: ClickHouseClient | None = None,
    sql_file_filter: Callable[[Path], bool] | None = None,
) -> int:
    """Create the missing tables of one ClickHouse medallion layer."""
    owns_client = client is None
    active_client = client or connect_clickhouse()
    try:
        clickhouse_root = resolve_clickhouse_root()
        sql_files = get_layer_sql_files(layer_name, clickhouse_root=clickhouse_root)
        if sql_file_filter is not None:
            sql_files = [sql_file for sql_file in sql_files if sql_file_filter(sql_file)]
        logger.info("Using ClickHouse SQL root: %s", clickhouse_root)
        if not verify_setup_sql(active_client, sql_files):
            return 1
        return _execute_layer_sql_files(active_client, layer_name, sql_files)
    finally:
        if owns_client:
            active_client.disconnect()


def run_clickhouse_layers(layer_names: Iterable[str]) -> int:
    """Create missing tables for multiple layers after verifying all of them first."""
    client = connect_clickhouse()
    try:
        clickhouse_root = resolve_clickhouse_root()
        logger.info("Using ClickHouse SQL root: %s", clickhouse_root)
        layer_sql_files = {
            layer_name: get_layer_sql_files(layer_name, clickhouse_root=clickhouse_root)
            for layer_name in layer_names
        }
        all_sql_files = [path for paths in layer_sql_files.values() for path in paths]
        if not verify_setup_sql(client, all_sql_files):
            return 1
        for layer_name, sql_files in layer_sql_files.items():
            if _execute_layer_sql_files(client, layer_name, sql_files) != 0:
                return 1
        return 0
    finally:
        client.disconnect()
