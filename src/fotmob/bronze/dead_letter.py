"""
Dead Letter Queue (DLQ) for storing failed records.

Stores failed records that couldn't be inserted to ClickHouse for later analysis and reprocessing.
"""

import json
import math
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from src.common.logging import get_logger

logger = get_logger(__name__)


class DeadLetterQueue:
    """Store failed records for later processing."""

    def __init__(self, dlq_path: str = "data/dlq"):
        """
        Initialize Dead Letter Queue.

        Args:
            dlq_path: Path to DLQ directory (default: data/dlq)
        """
        self.dlq_path = Path(dlq_path)
        self.dlq_path.mkdir(parents=True, exist_ok=True)
        self.logger = logger

    def send_to_dlq(
        self, table: str, data: Any, error: str, context: Optional[Dict[str, Any]] = None
    ) -> Path:
        """
        Send failed record to DLQ.

        Args:
            table: Table name where insert failed
            data: The data that failed (can be DataFrame, dict, list, etc.)
            error: Error message or exception
            context: Additional context (date, match_id, etc.)

        Returns:
            Path to DLQ file where record was written
        """
        today = datetime.now().strftime("%Y%m%d")
        dlq_file = self.dlq_path / f"{table}_{today}.jsonl"

        data_serializable = self._serialize_data(data)

        record = {
            "timestamp": datetime.now().isoformat(),
            "table": table,
            "error": str(error),
            "context": context or {},
            "data": data_serializable,
            "row_count": self._get_row_count(data),
        }

        try:
            with open(dlq_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(record, ensure_ascii=False) + "\n")

            self.logger.warning(
                f"Sent failed record to DLQ: {dlq_file.name} "
                f"(table: {table}, rows: {record['row_count']})"
            )
            return dlq_file
        except Exception as e:
            self.logger.error(f"Failed to write to DLQ file {dlq_file}: {e}")
            raise

    def _serialize_data(self, data: Any) -> Any:
        """
        Convert data to JSON-serializable format.

        Args:
            data: Data to serialize (DataFrame, dict, list, etc.)

        Returns:
            Serialized data
        """
        from datetime import date, datetime

        import pandas as pd
        from pandas import Timestamp

        if isinstance(data, pd.DataFrame):
            # Convert DataFrame to dict with proper datetime handling
            df_copy = data.copy()
            # Convert all datetime/timestamp columns to ISO format strings
            for col in df_copy.columns:
                if pd.api.types.is_datetime64_any_dtype(df_copy[col]):
                    df_copy[col] = df_copy[col].astype(str)
            return self._replace_nan(df_copy.to_dict("records"))

        if isinstance(data, (datetime, date, Timestamp)):
            return data.isoformat() if hasattr(data, "isoformat") else str(data)

        if isinstance(data, dict):
            return {k: self._serialize_data(v) for k, v in data.items()}

        if isinstance(data, list):
            return [self._serialize_data(item) for item in data]

        return self._replace_nan(data)

    def _replace_nan(self, value: Any) -> Any:
        """Recursively convert NaN values to None for strict JSON compatibility."""
        import pandas as pd

        if isinstance(value, dict):
            return {k: self._replace_nan(v) for k, v in value.items()}
        if isinstance(value, list):
            return [self._replace_nan(item) for item in value]
        if isinstance(value, (datetime,)):
            return value.isoformat()
        if isinstance(value, pd.Timestamp):
            return value.isoformat()
        if value is pd.NaT:
            return None
        if isinstance(value, float) and math.isnan(value):
            return None
        try:
            if pd.isna(value):
                return None
        except Exception:
            pass
        return value

    def _get_row_count(self, data: Any) -> int:
        """
        Get row count from data.

        Args:
            data: Data to count rows from

        Returns:
            Number of rows
        """
        import pandas as pd

        if isinstance(data, pd.DataFrame):
            return len(data)

        if isinstance(data, dict):
            for v in data.values():
                if isinstance(v, pd.DataFrame):
                    return len(v)
            return 1

        if isinstance(data, list):
            return len(data)

        return 1

    def get_dlq_records(
        self, table: Optional[str] = None, date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Read records from DLQ files.

        Args:
            table: Filter by table name (optional)
            date: Filter by date YYYYMMDD (optional)

        Returns:
            List of DLQ records
        """
        records = []

        if table and date:
            pattern = f"{table}_{date}.jsonl"
        elif table:
            pattern = f"{table}_*.jsonl"
        elif date:
            pattern = f"*_{date}.jsonl"
        else:
            pattern = "*.jsonl"

        for dlq_file in self.dlq_path.glob(pattern):
            try:
                with open(dlq_file, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.strip():
                            records.append(json.loads(line))
            except Exception as e:
                self.logger.error(f"Error reading DLQ file {dlq_file}: {e}")

        return records

    def get_dlq_stats(self) -> Dict[str, Any]:
        """
        Get statistics about DLQ.

        Returns:
            Dictionary with DLQ statistics
        """
        stats = {
            "total_files": 0,
            "total_records": 0,
            "total_size_bytes": 0,
            "by_table": {},
            "by_date": {},
        }

        for dlq_file in self.dlq_path.glob("*.jsonl"):
            try:
                file_size = dlq_file.stat().st_size
                stats["total_size_bytes"] += file_size
                stats["total_files"] += 1

                parts = dlq_file.stem.split("_", 1)
                if len(parts) == 2:
                    table_name = parts[0]
                    file_date = parts[1]

                    record_count = self._count_records(dlq_file)
                    stats["total_records"] += record_count

                    if table_name not in stats["by_table"]:
                        stats["by_table"][table_name] = {"files": 0, "records": 0}
                    stats["by_table"][table_name]["files"] += 1
                    stats["by_table"][table_name]["records"] += record_count

                    if file_date not in stats["by_date"]:
                        stats["by_date"][file_date] = {"files": 0, "records": 0}
                    stats["by_date"][file_date]["files"] += 1
                    stats["by_date"][file_date]["records"] += record_count
            except Exception as e:
                self.logger.warning(f"Error processing DLQ file {dlq_file}: {e}")

        stats["total_size_mb"] = stats["total_size_bytes"] / (1024 * 1024)
        return stats

    def _count_records(self, dlq_file: Path) -> int:
        """Count non-empty JSONL records in a DLQ file."""
        with open(dlq_file, "r", encoding="utf-8") as handle:
            return sum(1 for line in handle if line.strip())
