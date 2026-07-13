"""Shared helpers for ClickHouse layer setup scripts."""

import os
import re
import sys
import time
from pathlib import Path
from typing import Callable, Iterable, Optional

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.integrations.clickhouse.client import ClickHouseClient
from src.common.logging import get_logger

logger = get_logger()

LAYER_ORDER = ("bronze", "silver", "gold")
SETUP_EXCLUDED_SQL_NAME_PARTS = ("optimize",)
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
}


def load_local_env_files() -> None:
    """Load .env via pydantic-settings (centralised env loading)."""
    get_settings()


load_local_env_files()


def is_local_development_environment() -> bool:
    """Return whether local-only development credentials are allowed."""
    environment = (
        os.getenv("DEPTHMARK_ENV")
        or os.getenv("ENVIRONMENT")
        or os.getenv("SCRAPER_ENV")
        or ""
    ).strip()
    if environment.lower() in LOCAL_ENVIRONMENT_VALUES:
        return True

    try:
        settings = get_settings()
    except Exception:
        return False

    return settings.environment.value in LOCAL_ENVIRONMENT_VALUES


def validate_clickhouse_credentials(username: str, password: str) -> None:
    """Reject unsafe ClickHouse setup credentials outside explicit local development."""
    if not CLICKHOUSE_IDENTIFIER_PATTERN.fullmatch(username):
        raise RuntimeError(
            "CLICKHOUSE_USER must be a simple ClickHouse identifier containing only "
            "letters, numbers, and underscores, and must not start with a number."
        )

    if is_local_development_environment():
        return

    if password.strip().lower() in INSECURE_CLICKHOUSE_PASSWORDS:
        raise RuntimeError(
            "Refusing to run ClickHouse setup with empty, placeholder, or local-dev "
            "credentials outside local development. Set DEPTHMARK_ENV=local for the "
            "tracked Docker/local-dev workflow, or provide production-grade "
            "CLICKHOUSE_PASSWORD credentials."
        )


def quote_sql_string(value: str) -> str:
    """Quote a SQL string literal for ClickHouse setup statements."""
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def connect_clickhouse() -> ClickHouseClient:
    """Connect to ClickHouse, creating the configured user when needed."""
    host = os.getenv("CLICKHOUSE_HOST", "localhost")
    port = int(os.getenv("CLICKHOUSE_PORT", "8123"))
    username = os.getenv("CLICKHOUSE_USER", "fotmob_user")
    password = os.getenv("CLICKHOUSE_PASSWORD", "fotmob_pass")
    validate_clickhouse_credentials(username, password)
    allows_local_bootstrap = is_local_development_environment()
    is_docker_runtime = Path("/.dockerenv").exists()
    host_candidates = [host]
    if not is_docker_runtime:
        # Host-side runs should prefer local port mapping first, then docker DNS alias.
        if host == "clickhouse":
            host_candidates = ["localhost", "127.0.0.1", "clickhouse"]
        elif host == "localhost":
            host_candidates = ["localhost", "127.0.0.1"]

    # Keep order stable while removing duplicates.
    host_candidates = list(dict.fromkeys(host_candidates))

    attempted_hosts: list[str] = []
    for candidate_host in host_candidates:
        attempted_hosts.append(candidate_host)
        logger.info("Connecting to ClickHouse at %s:%s", candidate_host, port)
        client = ClickHouseClient(
            host=candidate_host,
            port=port,
            username=username,
            password=password,
            database="default",
        )

        if client.connect():
            # User can authenticate, but may still miss newer grants.
            # Try to reconcile grants via default admin user in local development.
            if allows_local_bootstrap and username != "default":
                try:
                    grant_client = ClickHouseClient(
                        host=candidate_host,
                        port=port,
                        username="default",
                        password="",
                        database="default",
                    )
                    if grant_client.connect():
                        try:
                            if not create_user_if_not_exists(grant_client, username, password):
                                logger.warning(
                                    "Could not reconcile grants for user '%s' on host '%s'",
                                    username,
                                    candidate_host,
                                )
                        finally:
                            grant_client.disconnect()
                except Exception as exc:
                    logger.warning(
                        "Skipped grant reconciliation for user '%s' on host '%s': %s",
                        username,
                        candidate_host,
                        exc,
                    )
            return client

        if not allows_local_bootstrap:
            logger.warning(
                "Failed to connect with configured ClickHouse user '%s' on host '%s'. "
                "Default-user bootstrap is local-development only.",
                username,
                candidate_host,
            )
            continue

        logger.warning("Failed to connect with user '%s', trying default user...", username)
        default_client = ClickHouseClient(
            host=candidate_host,
            port=port,
            username="default",
            password="",
            database="default",
        )

        default_connected = default_client.connect()
        if not default_connected:
            try:
                import clickhouse_connect

                default_client.client = clickhouse_connect.get_client(
                    host=candidate_host,
                    port=port,
                    username="default",
                    database="default",
                )
                default_client.client.query("SELECT 1")
                default_connected = True
                logger.info("Connected with default user (no password)")
            except Exception as exc:
                logger.debug("Default user connection without password failed: %s", exc)

        if not default_connected:
            continue

        try:
            if not create_user_if_not_exists(default_client, username, password):
                raise RuntimeError(f"Failed to create ClickHouse user '{username}'")
        finally:
            default_client.disconnect()

        if client.connect():
            return client
        logger.warning(
            "Still failed to connect with user '%s' after creation on host '%s'",
            username,
            candidate_host,
        )

    raise RuntimeError(
        "Failed to connect to ClickHouse even with default user. Tried hosts: "
        f"{', '.join(attempted_hosts)}"
    )


def create_user_if_not_exists(client: ClickHouseClient, username: str, password: str) -> bool:
    """Create ClickHouse user if it does not exist."""
    try:
        validate_clickhouse_credentials(username, password)
        result = client.execute(
            f"SELECT name FROM system.users WHERE name = {quote_sql_string(username)}"
        )
        user_exists = False
        if hasattr(result, "result_rows") and result.result_rows:
            user_exists = True
        elif hasattr(result, "result_columns") and result.result_columns:
            user_exists = len(result.result_columns[0]) > 0

        if user_exists:
            logger.info("User '%s' already exists, ensuring grants...", username)
        else:
            logger.info("Creating user '%s'...", username)
            client.execute(
                f"CREATE USER IF NOT EXISTS {username} IDENTIFIED BY {quote_sql_string(password)}"
            )

        for grant_query in (
            f"GRANT ALL ON bronze.* TO {username}",
            f"GRANT ALL ON silver.* TO {username}",
            f"GRANT ALL ON gold.* TO {username}",
            f"GRANT ALL ON gold_scenarios.* TO {username}",
            f"GRANT ALL ON gold_signals.* TO {username}",
            f"GRANT CREATE DATABASE ON *.* TO {username}",
            f"GRANT TABLE ENGINE ON ReplacingMergeTree TO {username}",
        ):
            try:
                client.execute(grant_query)
            except Exception as exc:
                logger.warning("Could not grant permission (may already exist): %s", exc)
        return True
    except Exception as exc:
        logger.error("Failed to create user '%s': %s", username, exc)
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


def get_layer_sql_files(layer_name: str, clickhouse_root: Optional[Path] = None) -> list[Path]:
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
        candidate_dirs.extend(
            [
                layer_dir / "ddl" / "activations",
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


def execute_sql_file(
    client: ClickHouseClient, sql_file: Path, database: Optional[str] = None
) -> bool:
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
                    logger.error("Failed while executing %s: %s", sql_file.name, exc)
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


def run_clickhouse_layer_setup(
    layer_name: str,
    client: Optional[ClickHouseClient] = None,
    sql_file_filter: Optional[Callable[[Path], bool]] = None,
) -> int:
    """Create one ClickHouse medallion layer."""
    owns_client = client is None
    active_client = client or connect_clickhouse()
    try:
        clickhouse_root = resolve_clickhouse_root()
        sql_files = get_layer_sql_files(layer_name, clickhouse_root=clickhouse_root)
        if sql_file_filter is not None:
            sql_files = [sql_file for sql_file in sql_files if sql_file_filter(sql_file)]
        logger.info("Using ClickHouse SQL root: %s", clickhouse_root)
        if not sql_files:
            logger.warning("No SQL files selected for %s layer setup", layer_name)
            return 0
        logger.info("Executing %s layer SQL...", layer_name.upper())
        for sql_file in sql_files:
            logger.info("Running %s", sql_file.name)
            file_start = time.perf_counter()
            succeeded = execute_sql_file(active_client, sql_file)
            elapsed_seconds = time.perf_counter() - file_start
            if not succeeded:
                logger.error("Failed %s in %.2f seconds", sql_file.name, elapsed_seconds)
                return 1
            logger.info("Completed %s in %.2f seconds", sql_file.name, elapsed_seconds)
        logger.info("%s layer setup completed", layer_name.upper())
        return 0
    finally:
        if owns_client:
            active_client.disconnect()


def run_clickhouse_layers(layer_names: Iterable[str]) -> int:
    """Create multiple ClickHouse layers with one shared connection."""
    client = connect_clickhouse()
    try:
        for layer_name in layer_names:
            if run_clickhouse_layer_setup(layer_name, client=client) != 0:
                return 1
        return 0
    finally:
        client.disconnect()
