"""Bronze layer application service behind script entry points."""

import gzip
import io
import json
import logging
import re
import tarfile
import warnings
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd

from config import FotMobConfig
from src.fotmob.bronze.match_processor import FotMobBronzeMatchProcessor
from src.fotmob.bronze.paths import get_fotmob_historical_path
from src.fotmob.bronze.storage import FotMobBronzeStorage
from src.integrations.clickhouse.client import ClickHouseClient
from src.fotmob.bronze.dead_letter import DeadLetterQueue
from src.warehouse.contracts import (
    LayerContractError,
    assert_bronze_dataframe_contract,
    assert_bronze_layer_contracts,
    get_bronze_invalid_key_rows,
)
from src.common.logging import get_logger

logger = get_logger(__name__)

# ============================================================================
# Constants
# ============================================================================

FOTMOB_TABLES = [
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
]

TABLES_HANDLED_SEPARATELY = ["starters", "substitutes", "coaches"]

TABLES_WITH_INSERTED_AT = ["starters", "substitutes"]  # coaches excluded

UNIQUE_KEY_COLUMNS = {
    "match_reference": ["match_id"],
    "general": ["match_id"],
    "timeline": ["match_id"],
    "venue": ["match_id"],
    "player": ["match_id", "player_id"],
    "shotmap": ["match_id", "shot_id"],
    "goal": ["match_id", "event_id", "player_id", "goal_time"],
    "cards": ["match_id", "event_id"],
    "red_card": ["match_id", "event_id"],
    "period": ["match_id", "period"],
    "momentum": ["match_id", "minute"],
    "starters": ["match_id", "player_id"],
    "substitutes": ["match_id", "player_id"],
    "coaches": ["match_id", "coach_id"],
    "team_form": ["match_id", "team_id", "form_position"],
}

INT64_COLUMNS = {
    "goal": ["event_id", "shot_event_id"],
    "cards": ["event_id"],
    "red_card": ["event_id"],
    "starters": ["player_id"],
    "substitutes": ["player_id"],
    "coaches": ["coach_id"],
    "team_form": ["team_id"],
    "shotmap": ["shot_id"],
}

INT32_RANGE = (2147483647, -2147483648)
INT64_RANGE = (9223372036854775807, -9223372036854775808)
BRONZE_DATABASE = "bronze"


# ============================================================================
# Data Classes
# ============================================================================


@dataclass
class BronzeRunResult:
    """Structured result returned by BronzeService.run()."""

    exit_code: int
    dates_processed: int = 0
    tables_loaded: int = 0
    total_rows: int = 0
    row_counts: Dict[str, int] = field(default_factory=dict)


# ============================================================================
# Utility Functions
# ============================================================================


def to_bronze_table_name(logical_table_name: str) -> str:
    """Map logical table names to physical bronze table names."""
    return logical_table_name


def get_unique_key_columns(table_name: str) -> List[str]:
    """Get unique key columns for a table (used for deduplication)."""
    return UNIQUE_KEY_COLUMNS.get(table_name, ["match_id"])


def _is_missing_table_error(error: Exception) -> bool:
    """Return True when an exception indicates a missing ClickHouse table."""
    error_str = str(error).lower()
    return "does not exist" in error_str or "unknown_table" in error_str


def describe_table_schema_rows(
    client: ClickHouseClient, table_name: str, database: str = BRONZE_DATABASE
) -> Optional[List]:
    """Return DESCRIBE TABLE rows, or None if the table does not exist."""
    try:
        table_info = client.execute(f"DESCRIBE TABLE {database}.{table_name}")
        return _extract_describe_rows(table_info)
    except Exception as exc:
        if _is_missing_table_error(exc):
            return None
        raise


# ============================================================================
# DataFrame Processing
# ============================================================================


def prepare_int64_columns(df: pd.DataFrame, table_name: str) -> pd.DataFrame:
    """Convert specified columns to Int64 type."""
    if table_name not in INT64_COLUMNS:
        return df

    local_logger = logging.getLogger(__name__)
    int64_max, int64_min = INT64_RANGE

    for col_name in INT64_COLUMNS[table_name]:
        if col_name in df.columns:
            numeric_col = pd.to_numeric(df[col_name], errors="coerce")

            overflow_mask = (numeric_col > int64_max) | (numeric_col < int64_min)
            if overflow_mask.any():
                local_logger.warning(
                    "Found Int64 overflow values; clipping to Int64 bounds",
                    extra={
                        "table_name": table_name,
                        "column_name": col_name,
                        "overflow_count": int(overflow_mask.sum()),
                    },
                )
                numeric_col = numeric_col.clip(lower=int64_min, upper=int64_max)

            fractional_mask = numeric_col.notna() & ((numeric_col % 1) != 0)
            if fractional_mask.any():
                local_logger.warning(
                    "Found non-integer values in Int64 column; rounding before cast",
                    extra={
                        "table_name": table_name,
                        "column_name": col_name,
                        "fractional_count": int(fractional_mask.sum()),
                    },
                )
                numeric_col = numeric_col.round()

            df[col_name] = numeric_col.astype("Int64")

    return df


def prepare_nullable_numeric_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Convert all float columns that contain only integers to Int64."""
    for col in df.columns:
        if df[col].dtype in ["float64", "float32"]:
            try:
                non_null_values = df[col].dropna()
                if (
                    len(non_null_values) > 0
                    and (non_null_values == non_null_values.astype(int)).all()
                ):
                    df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
            except (ValueError, TypeError):
                pass
    return df


def prepare_temporal_columns_for_schema(
    df: pd.DataFrame,
    schema_rows: List,
    table_name: str,
    log: logging.Logger,
) -> pd.DataFrame:
    """Convert ClickHouse Date/DateTime columns to Python temporal values."""
    for row in schema_rows:
        if not row or len(row) < 2:
            continue
        col_name = row[0] if isinstance(row, (list, tuple)) else str(row)
        col_type = str(row[1] if isinstance(row, (list, tuple)) else row)
        if col_name not in df.columns:
            continue

        is_nullable = "Nullable" in col_type
        if "DateTime" in col_type:
            parsed = pd.to_datetime(df[col_name], errors="coerce")
            if is_nullable:
                df[col_name] = parsed.astype(object).where(parsed.notna(), None)
            else:
                df[col_name] = parsed.fillna(datetime(1970, 1, 1))
        elif re.search(r"\bDate\b", col_type):
            parsed = pd.to_datetime(df[col_name], errors="coerce")
            fallback_date = date(1970, 1, 1)
            if is_nullable:
                df[col_name] = parsed.dt.date.where(parsed.notna(), None)
            else:
                null_count = int(parsed.isna().sum())
                if null_count:
                    log.warning(
                        "Found invalid dates in non-nullable Date column; using fallback",
                        extra={
                            "table_name": table_name,
                            "column_name": col_name,
                            "invalid_count": null_count,
                            "fallback_date": fallback_date.isoformat(),
                        },
                    )
                df[col_name] = parsed.dt.date.where(parsed.notna(), fallback_date)

    return df


def rename_columns_for_table(
    df: pd.DataFrame, table_name: str, log: logging.Logger
) -> pd.DataFrame:
    """Rename columns for specific tables."""
    column_renames = {}

    if table_name == "player":
        if "id" in df.columns:
            column_renames["id"] = "player_id"
        if "name" in df.columns:
            column_renames["name"] = "player_name"
    elif table_name == "cards":
        if "time" in df.columns:
            column_renames["time"] = "event_time"
        if "score" in df.columns:
            column_renames["score"] = "score_at_event"
    elif table_name == "shotmap":
        if "id" in df.columns:
            column_renames["id"] = "shot_id"
        if "min" in df.columns:
            column_renames["min"] = "minute"
        if "min_added" in df.columns:
            column_renames["min_added"] = "minute_added"
    elif table_name == "coaches":
        if "id" in df.columns:
            column_renames["id"] = "coach_id"

    if column_renames:
        df = df.rename(columns=column_renames)
        log.debug(
            "Renamed columns for table",
            extra={"table_name": table_name, "column_renames": column_renames},
        )

    return df


def check_table_has_inserted_at(schema_rows: List) -> bool:
    """Check if DESCRIBE TABLE rows include inserted_at column."""
    for row in schema_rows:
        if not row or len(row) < 2:
            continue
        col_name = row[0] if isinstance(row, (list, tuple)) else str(row)
        if col_name == "inserted_at":
            return True
    return False


def _extract_describe_rows(table_info) -> List:
    """Extract rows from DESCRIBE TABLE result."""
    if hasattr(table_info, "result_rows") and table_info.result_rows:
        return table_info.result_rows
    elif hasattr(table_info, "result_columns") and table_info.result_columns:
        num_cols = len(table_info.result_columns)
        num_rows = len(table_info.result_columns[0]) if table_info.result_columns[0] else 0
        return [[table_info.result_columns[i][j] for i in range(num_cols)] for j in range(num_rows)]
    elif isinstance(table_info, (list, tuple)):
        return table_info
    return []


def _int_bounds_from_clickhouse_type(col_type: str) -> Optional[tuple[int, int, str]]:
    """Return integer bounds for a ClickHouse Int/UInt type."""
    match = re.search(r"\b(U?Int)(8|16|32|64|128|256)\b", col_type)
    if not match:
        return None

    family = match.group(1)
    bits = int(match.group(2))
    type_label = f"{family}{bits}"

    if family == "UInt":
        min_val = 0
        max_val = (1 << bits) - 1
    else:
        max_val = (1 << (bits - 1)) - 1
        min_val = -(1 << (bits - 1))

    return min_val, max_val, type_label


def _normalize_string_value(value: Any, nullable: bool) -> Optional[str]:
    """Normalize value to a ClickHouse-compatible string."""
    if _is_null_like(value):
        return None if nullable else ""
    if isinstance(value, str):
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _is_null_like(value: Any) -> bool:
    """Return True for scalar null-like values without array truth-value warnings."""
    if value is None:
        return True
    if isinstance(value, (list, tuple, dict, set)):
        return False

    null_check = pd.isna(value)
    if hasattr(null_check, "size"):
        return bool(null_check.all()) if null_check.size > 0 else False
    return bool(null_check)


def validate_and_fix_schema(
    df: pd.DataFrame,
    table_name: str,
    log: logging.Logger,
    schema_rows: List,
) -> pd.DataFrame:
    """Validate DataFrame against table schema and fix issues."""
    try:
        rows = schema_rows

        non_nullable_int_cols = []
        non_nullable_uint_cols = []
        non_nullable_float_cols = []
        non_nullable_string_cols = []
        nullable_int_cols = []
        nullable_float_cols = []
        nullable_string_cols = []
        integer_col_bounds: Dict[str, tuple[int, int, str]] = {}
        table_columns = set()

        for row in rows:
            if not row or len(row) < 2:
                continue
            col_name = row[0] if isinstance(row, (list, tuple)) else str(row)
            col_type = str(row[1] if isinstance(row, (list, tuple)) else row)
            table_columns.add(col_name)

            bounds = _int_bounds_from_clickhouse_type(col_type)
            if bounds:
                integer_col_bounds[col_name] = bounds

            if col_name not in df.columns:
                continue

            if "Nullable" in col_type:
                if "Int" in col_type:
                    nullable_int_cols.append(col_name)
                elif "Float" in col_type:
                    nullable_float_cols.append(col_name)
                elif col_name == "fun_facts":
                    df.loc[:, col_name] = df[col_name].apply(
                        lambda value: []
                        if value is None or (isinstance(value, float) and pd.isna(value))
                        else value
                    )
                elif "String" in col_type:
                    nullable_string_cols.append(col_name)
            elif col_name in df.columns:
                if col_name == "fun_facts":
                    df.loc[:, col_name] = df[col_name].apply(
                        lambda value: []
                        if value is None or (isinstance(value, float) and pd.isna(value))
                        else value
                    )
                if "UInt" in col_type:
                    non_nullable_uint_cols.append(col_name)
                elif "Int" in col_type:
                    non_nullable_int_cols.append(col_name)
                elif "Float" in col_type:
                    non_nullable_float_cols.append(col_name)
                elif "String" in col_type:
                    non_nullable_string_cols.append(col_name)

        unknown_columns = [col for col in df.columns if col not in table_columns]
        if unknown_columns:
            log.warning(
                "Dropping columns not present in target schema",
                extra={"table_name": table_name, "columns": unknown_columns},
            )
            df = df.drop(columns=unknown_columns)

        for col in (
            non_nullable_int_cols
            + non_nullable_uint_cols
            + non_nullable_float_cols
            + non_nullable_string_cols
        ):
            null_mask = df[col].isna()
            if null_mask.any():
                log.error(
                    f"Found {null_mask.sum()} NULL values in non-nullable column {table_name}.{col}. Setting defaults."
                )
                if col in non_nullable_float_cols:
                    df.loc[null_mask, col] = 0.0
                elif col in non_nullable_string_cols:
                    df.loc[null_mask, col] = ""
                else:
                    df.loc[null_mask, col] = 0

        for col in non_nullable_int_cols:
            min_val, max_val, type_label = integer_col_bounds.get(
                col, (INT32_RANGE[1], INT32_RANGE[0], "Int32")
            )
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)
            overflow_mask = (df[col] < min_val) | (df[col] > max_val)
            if overflow_mask.any():
                log.error(
                    f"Found {overflow_mask.sum()} {type_label} overflow values in {table_name}.{col}. Clipping."
                )
                df.loc[overflow_mask & (df[col] > max_val), col] = max_val
                df.loc[overflow_mask & (df[col] < min_val), col] = min_val
            df[col] = df[col].astype("int64")

        for col in non_nullable_uint_cols:
            min_val, max_val, type_label = integer_col_bounds.get(
                col, (0, INT32_RANGE[0], "UInt32")
            )
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)
            below_min_mask = df[col] < min_val
            above_max_mask = df[col] > max_val
            if below_min_mask.any():
                log.error(
                    f"Found {below_min_mask.sum()} negative values in unsigned column {table_name}.{col}. Clamping to {min_val}."
                )
                df.loc[below_min_mask, col] = min_val
            if above_max_mask.any():
                log.error(
                    f"Found {above_max_mask.sum()} {type_label} overflow values in {table_name}.{col}. Clipping to {max_val}."
                )
                df.loc[above_max_mask, col] = max_val
            df[col] = df[col].astype("int64")

        for col in non_nullable_float_cols:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0).astype("float64")

        for col in non_nullable_string_cols:
            try:
                df[col] = df[col].map(lambda v: _normalize_string_value(v, nullable=False))
            except Exception as col_err:
                log.debug(
                    "Could not normalize non-nullable string column",
                    extra={"table_name": table_name, "column_name": col, "error": str(col_err)},
                )

        for col in nullable_int_cols:
            try:
                numeric_col = pd.to_numeric(df[col], errors="coerce")
                df[col] = numeric_col.astype("Int64")
            except Exception as col_err:
                log.debug(
                    "Could not convert nullable int column",
                    extra={"table_name": table_name, "column_name": col, "error": str(col_err)},
                )

        for col in nullable_float_cols:
            try:
                numeric_col = pd.to_numeric(df[col], errors="coerce")
                df[col] = numeric_col.where(numeric_col.notna(), None)
            except Exception as col_err:
                log.debug(
                    "Could not convert nullable float column",
                    extra={"table_name": table_name, "column_name": col, "error": str(col_err)},
                )

        for col in nullable_string_cols:
            try:
                df[col] = df[col].map(lambda v: _normalize_string_value(v, nullable=True))
            except Exception as col_err:
                log.debug(
                    "Could not normalize nullable string column",
                    extra={"table_name": table_name, "column_name": col, "error": str(col_err)},
                )

    except Exception as exc:
        log.debug(
            "Schema validation skipped",
            extra={"table_name": table_name, "error": str(exc)},
        )

    return df


def add_inserted_at_column(df: pd.DataFrame, table_has_inserted_at: bool) -> pd.DataFrame:
    """Add or remove inserted_at column based on table schema."""
    if table_has_inserted_at and "inserted_at" not in df.columns:
        df["inserted_at"] = datetime.now()
    elif not table_has_inserted_at and "inserted_at" in df.columns:
        df = df.drop(columns=["inserted_at"])
    return df


# ============================================================================
# Data Insertion
# ============================================================================


def insert_dataframe_with_dlq(
    client: ClickHouseClient,
    df: pd.DataFrame,
    table_name: str,
    database: str,
    date_str: str,
    log: logging.Logger,
    context: Optional[Dict] = None,
) -> int:
    """Insert DataFrame with DLQ fallback for failures."""
    if df.empty:
        log.info("No rows to insert", extra={"table_name": table_name, "database": database})
        return 0

    dlq = DeadLetterQueue()

    try:
        rows_inserted = client.insert_dataframe(table_name, df, database=database)
        log.info(
            "Loaded rows into table",
            extra={"database": database, "table_name": table_name, "rows_inserted": rows_inserted},
        )
        return rows_inserted
    except Exception as insert_error:
        dlq.send_to_dlq(
            table=table_name,
            data=df,
            error=str(insert_error),
            context={"date": date_str, "database": database, **(context or {})},
        )
        log.error(
            "Failed to insert table; sent to DLQ",
            extra={"table_name": table_name, "database": database, "error": str(insert_error)},
        )
        raise


# ============================================================================
# File Loading
# ============================================================================


def load_match_files_from_tar(
    archive_path: Path, processor: FotMobBronzeMatchProcessor, log: logging.Logger
) -> Dict[str, List]:
    """Load match files from TAR archive."""
    all_dataframes = {}

    log.info("Found TAR archive", extra={"archive_path": str(archive_path)})
    try:
        with tarfile.open(archive_path, "r") as tar:
            json_gz_members = [m for m in tar.getmembers() if m.name.endswith(".json.gz")]
            log.info(
                "Found match files in TAR archive",
                extra={"archive_path": str(archive_path), "match_file_count": len(json_gz_members)},
            )

            for member in json_gz_members:
                try:
                    f = tar.extractfile(member)
                    if f:
                        with gzip.open(io.BytesIO(f.read()), "rt", encoding="utf-8") as gz:
                            file_data = json.load(gz)
                        raw_data = file_data.get("data", file_data)
                        dataframes, _ = processor.process_all(raw_data)
                        _add_processed_dataframes(dataframes, all_dataframes)
                except Exception as exc:
                    log.error(
                        "Error processing member from TAR",
                        extra={
                            "archive_path": str(archive_path),
                            "member_name": member.name,
                            "error": str(exc),
                        },
                        exc_info=True,
                    )
    except Exception as exc:
        log.error(
            "Error reading TAR archive",
            extra={"archive_path": str(archive_path), "error": str(exc)},
            exc_info=True,
        )

    return all_dataframes


def load_match_files_from_json_gz(
    matches_dir: Path, processor: FotMobBronzeMatchProcessor, log: logging.Logger
) -> Dict[str, List]:
    """Load match files from JSON.gz files."""
    all_dataframes = {}
    json_gz_files = list(matches_dir.glob("match_*.json.gz"))

    if json_gz_files:
        log.info(
            "Found JSON.GZ files",
            extra={"matches_dir": str(matches_dir), "file_count": len(json_gz_files)},
        )
        for json_gz_file in json_gz_files:
            try:
                with gzip.open(json_gz_file, "rt", encoding="utf-8") as f:
                    file_data = json.load(f)
                raw_data = file_data.get("data", file_data)
                dataframes, _ = processor.process_all(raw_data)
                _add_processed_dataframes(dataframes, all_dataframes)
            except Exception as exc:
                log.error(
                    "Error processing JSON.GZ file",
                    extra={"file_path": str(json_gz_file), "error": str(exc)},
                    exc_info=True,
                )

    return all_dataframes


def load_match_files_from_json(
    matches_dir: Path, processor: FotMobBronzeMatchProcessor, log: logging.Logger
) -> Dict[str, List]:
    """Load match files from JSON files."""
    all_dataframes = {}
    json_files = list(matches_dir.glob("match_*.json"))

    if json_files:
        log.info(
            "Found JSON files",
            extra={"matches_dir": str(matches_dir), "file_count": len(json_files)},
        )
        for json_file in json_files:
            try:
                with open(json_file, "r", encoding="utf-8") as f:
                    file_data = json.load(f)
                raw_data = file_data.get("data", file_data)
                dataframes, _ = processor.process_all(raw_data)
                _add_processed_dataframes(dataframes, all_dataframes)
            except Exception as exc:
                log.error(
                    "Error processing JSON file",
                    extra={"file_path": str(json_file), "error": str(exc)},
                    exc_info=True,
                )

    return all_dataframes


def _add_processed_dataframes(dataframes: Dict, all_dataframes: Dict) -> None:
    """Add processed dataframes to collection."""
    for table_name, df in dataframes.items():
        if table_name not in all_dataframes:
            all_dataframes[table_name] = []
        if isinstance(df, pd.DataFrame) and not df.empty:
            all_dataframes[table_name].append(df)


def load_fotmob_match_files(
    matches_dir: Path, date_str: str, processor: FotMobBronzeMatchProcessor, log: logging.Logger
) -> Dict[str, List]:
    """Load all FotMob match files from a directory."""
    all_dataframes = {}

    archive_path = matches_dir / f"{date_str}_matches.tar"
    if archive_path.exists():
        all_dataframes = load_match_files_from_tar(archive_path, processor, log)

    if not all_dataframes:
        all_dataframes = load_match_files_from_json_gz(matches_dir, processor, log)

    if not all_dataframes:
        all_dataframes = load_match_files_from_json(matches_dir, processor, log)

    return all_dataframes


# ============================================================================
# Table Processing
# ============================================================================


def process_fotmob_table(
    client: ClickHouseClient,
    table_name: str,
    df_list: List[pd.DataFrame],
    date_str: str,
    log: logging.Logger,
) -> int:
    """Process and load a single FotMob table."""
    if not df_list:
        return 0

    non_empty_dfs = [df for df in df_list if isinstance(df, pd.DataFrame) and not df.empty]
    if not non_empty_dfs:
        return 0

    clickhouse_table = table_name
    if table_name == "cards_only":
        clickhouse_table = "cards"
    elif table_name == "lineup_data":
        return 0

    physical_table = to_bronze_table_name(clickhouse_table)

    schema_rows = describe_table_schema_rows(client, physical_table, database=BRONZE_DATABASE)
    if schema_rows is None:
        log.error(
            f"Table {BRONZE_DATABASE}.{physical_table} does not exist. "
            f"Please run 'python scripts/orchestration/setup_clickhouse.py' to create all required tables."
        )
        return 0

    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore", category=FutureWarning, message=".*DataFrame concatenation.*"
        )
        combined_df = pd.concat(non_empty_dfs, ignore_index=True, sort=False)

    combined_df = rename_columns_for_table(combined_df, clickhouse_table, log)
    combined_df = prepare_int64_columns(combined_df, clickhouse_table)
    combined_df = prepare_nullable_numeric_columns(combined_df)

    table_has_inserted_at = check_table_has_inserted_at(schema_rows)
    combined_df = validate_and_fix_schema(combined_df, physical_table, log, schema_rows)
    combined_df = prepare_temporal_columns_for_schema(combined_df, schema_rows, physical_table, log)
    combined_df = add_inserted_at_column(combined_df, table_has_inserted_at)
    assert_bronze_dataframe_contract(clickhouse_table, combined_df, log=log)

    try:
        rows_inserted = insert_dataframe_with_dlq(
            client,
            combined_df,
            physical_table,
            BRONZE_DATABASE,
            date_str,
            log,
            {"source_files_count": len(df_list)},
        )

        return rows_inserted
    except LayerContractError:
        raise
    except Exception as exc:
        error_str = str(exc).lower()
        if "does not exist" in error_str or "unknown_table" in error_str:
            log.error(
                "Table does not exist. Run setup_clickhouse.py to create required tables.",
                extra={"database": BRONZE_DATABASE, "table_name": physical_table},
            )
        else:
            log.error(
                "Error loading table",
                extra={"table_name": table_name, "date": date_str, "error": str(exc)},
                exc_info=True,
            )
        return 0


def _process_special_fotmob_table(
    client: ClickHouseClient,
    table_name: str,
    df_list: List[pd.DataFrame],
    date_str: str,
    log: logging.Logger,
) -> int:
    """Process special FotMob tables (starters, substitutes, coaches)."""
    non_empty_dfs = [df for df in df_list if isinstance(df, pd.DataFrame) and not df.empty]
    if not non_empty_dfs:
        return 0

    physical_table = to_bronze_table_name(table_name)
    schema_rows = describe_table_schema_rows(client, physical_table, database=BRONZE_DATABASE)
    if schema_rows is None:
        log.error(
            f"Table {BRONZE_DATABASE}.{physical_table} does not exist. "
            f"Please run 'python scripts/orchestration/setup_clickhouse.py' to create all required tables."
        )
        return 0

    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore", category=FutureWarning, message=".*DataFrame concatenation.*"
        )
        combined_df = pd.concat(non_empty_dfs, ignore_index=True, sort=False)

    combined_df = rename_columns_for_table(combined_df, table_name, log)
    combined_df = prepare_int64_columns(combined_df, table_name)
    combined_df = prepare_nullable_numeric_columns(combined_df)
    combined_df = validate_and_fix_schema(combined_df, physical_table, log, schema_rows)
    combined_df = prepare_temporal_columns_for_schema(combined_df, schema_rows, physical_table, log)
    assert_bronze_dataframe_contract(table_name, combined_df, log=log)

    if table_name in TABLES_WITH_INSERTED_AT and "inserted_at" not in combined_df.columns:
        combined_df["inserted_at"] = datetime.now()

    if combined_df.empty:
        log.info("No rows to insert", extra={"table_name": table_name, "date": date_str})
        return 0

    try:
        rows_inserted = insert_dataframe_with_dlq(
            client, combined_df, physical_table, BRONZE_DATABASE, date_str, log
        )

        return rows_inserted
    except LayerContractError:
        raise
    except Exception:
        return 0


# ============================================================================
# Core Loading Orchestration
# ============================================================================


def load_fotmob_data(
    client: ClickHouseClient,
    date_str: str,
    force: bool = False,
    log: Optional[logging.Logger] = None,
) -> Dict[str, int]:
    """Load FotMob data from bronze JSON files to ClickHouse."""
    if log is None:
        log = logger

    stats: Dict[str, int] = {}
    try:
        config = FotMobConfig()
        bronze_storage = FotMobBronzeStorage(
            str(get_fotmob_historical_path(config.storage.bronze_path))
        )
        processor = FotMobBronzeMatchProcessor()

        matches_dir = bronze_storage._date_partition_dir(bronze_storage.matches_dir, date_str)

        if not matches_dir.exists():
            log.warning(
                "No bronze files found for date",
                extra={"date": date_str, "matches_dir": str(matches_dir)},
            )
            return stats

        all_dataframes = load_fotmob_match_files(matches_dir, date_str, processor, log)

        if not all_dataframes:
            log.warning(
                "No match files found", extra={"matches_dir": str(matches_dir), "date": date_str}
            )
            return stats

        log.info(
            "Match files processed",
            extra={
                "date": date_str,
                "tables_with_data": len(all_dataframes),
            },
        )

        total_accumulated_rows = 0
        for table_name, df_list in all_dataframes.items():
            total_rows = sum(len(df) for df in df_list) if df_list else 0
            total_accumulated_rows += total_rows
            log.debug(
                "Accumulated dataframe stats",
                extra={
                    "date": date_str,
                    "table_name": table_name,
                    "dataframe_count": len(df_list),
                    "total_rows": total_rows,
                },
            )
        log.info(
            "Accumulated dataframe summary",
            extra={
                "date": date_str,
                "tables_with_data": len(all_dataframes),
                "total_rows": total_accumulated_rows,
            },
        )

        touched_tables = [
            to_bronze_table_name(table_name)
            for table_name in all_dataframes.keys()
            if table_name in FOTMOB_TABLES
        ]
        baseline_invalid_rows_by_table = get_bronze_invalid_key_rows(
            client,
            table_names=touched_tables,
            database=BRONZE_DATABASE,
        )

        for table_name, df_list in all_dataframes.items():
            if table_name in TABLES_HANDLED_SEPARATELY:
                continue
            stats[table_name] = process_fotmob_table(client, table_name, df_list, date_str, log)

        for table_name in TABLES_HANDLED_SEPARATELY:
            if table_name in all_dataframes and all_dataframes[table_name]:
                stats[table_name] = _process_special_fotmob_table(
                    client,
                    table_name,
                    all_dataframes[table_name],
                    date_str,
                    log,
                )

        inserted_rows_by_table: Dict[str, int] = {}
        for table_name, inserted_rows in stats.items():
            if table_name == "cards_only":
                inserted_rows_by_table["cards"] = (
                    inserted_rows_by_table.get("cards", 0) + inserted_rows
                )
            else:
                inserted_rows_by_table[to_bronze_table_name(table_name)] = (
                    inserted_rows_by_table.get(to_bronze_table_name(table_name), 0) + inserted_rows
                )
        assert_bronze_layer_contracts(
            client,
            inserted_rows_by_table=inserted_rows_by_table,
            baseline_invalid_rows_by_table=baseline_invalid_rows_by_table,
            database=BRONZE_DATABASE,
            log=log,
        )

    except LayerContractError:
        raise
    except Exception as exc:
        log.error(
            "Error loading FotMob data", extra={"date": date_str, "error": str(exc)}, exc_info=True
        )

    return stats


# ============================================================================
# BronzeService
# ============================================================================


class BronzeService:
    """Coordinates FotMob Bronze layer file loading into ClickHouse.

    Owns: date iteration, table truncation, per-date data loading,
    row-count aggregation, and layer contract assertion.

    Does NOT own DataFrame processing, schema validation, or
    ClickHouse insertion logic; those live in the module-level
    helper functions defined above.
    """

    def __init__(
        self,
        client: Optional[ClickHouseClient] = None,
        force: bool = False,
    ):
        self.client = client
        self.force = force

    def truncate_tables(self) -> None:
        """Truncate all FotMob bronze tables."""
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for truncation")
        for table in FOTMOB_TABLES:
            try:
                self.client.truncate_table(table, database=BRONZE_DATABASE)
            except Exception as exc:
                logger.warning(
                    "Could not truncate table",
                    extra={
                        "database": BRONZE_DATABASE,
                        "table_name": table,
                        "error": str(exc),
                    },
                )

    def load_date(self, date_str: str) -> Dict[str, int]:
        """Load FotMob data for a single date. Returns per-table row counts."""
        logger.info(
            "Loading data for date",
            extra={"database": BRONZE_DATABASE, "date": date_str},
        )
        return load_fotmob_data(
            self.client,
            date_str,
            self.force,
            logger,
        )

    def load_dates(self, dates: List[str], truncate: bool = False) -> BronzeRunResult:
        """Load data for a list of dates. Returns aggregated result."""
        result = BronzeRunResult(exit_code=0)

        if truncate:
            logger.warning("Truncating tables before loading...")
            self.truncate_tables()

        for date_str in dates:
            try:
                stats = self.load_date(date_str)
                for table, count in stats.items():
                    result.row_counts[table] = result.row_counts.get(table, 0) + count
            except LayerContractError as exc:
                logger.error(
                    "Bronze layer contract assertion failed",
                    extra={
                        "database": BRONZE_DATABASE,
                        "date": date_str,
                        "error": str(exc),
                    },
                )
                result.exit_code = 1
                return result
            except Exception as exc:
                logger.error(
                    "Failed to load data for date",
                    extra={
                        "database": BRONZE_DATABASE,
                        "date": date_str,
                        "error": str(exc),
                    },
                    exc_info=True,
                )
                result.exit_code = 1
                return result

        result.dates_processed = len(dates)
        result.tables_loaded = len(result.row_counts)
        result.total_rows = sum(result.row_counts.values())
        return result

    def run(
        self,
        *,
        dates: Optional[List[str]] = None,
        truncate: bool = False,
        dry_run: bool = False,
    ) -> BronzeRunResult:
        """Execute the Bronze layer loading pipeline and return a structured result.

        The caller (script) is responsible for:
        - ClickHouse client creation and teardown
        - Telegram notification via TelegramClient
        - Mapping the result to an exit code
        """
        if dry_run:
            planned_dates = dates or []
            logger.info(
                "Running bronze loader in dry-run mode (no tables will be truncated and no data will be loaded)"
            )
            logger.info(
                "Bronze dry-run plan",
                extra={
                    "database": BRONZE_DATABASE,
                    "dates": ",".join(planned_dates),
                    "total_dates": len(planned_dates),
                    "truncate": truncate,
                    "tables": ",".join(FOTMOB_TABLES),
                    "force": self.force,
                },
            )
            if truncate:
                logger.warning(
                    "[dry-run] Would truncate bronze tables before loading",
                    extra={
                        "database": BRONZE_DATABASE,
                        "table_count": len(FOTMOB_TABLES),
                    },
                )
            result = BronzeRunResult(exit_code=0)
            result.dates_processed = len(planned_dates)
            return result

        if not dates:
            logger.warning("No dates to process")
            return BronzeRunResult(exit_code=0)

        return self.load_dates(dates, truncate=truncate)
