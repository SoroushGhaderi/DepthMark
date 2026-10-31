"""Bronze layer application service behind script entry points.

A Source Date loads in three steps (ADR 0031):

1. Read every match payload stored for the date and process it into rows keyed
   by Bronze table.
2. Admit every table's rows against its setup DDL (``admission.admit_rows``).
3. Insert each admitted table, then run the post-load Bronze contract. A failed
   insert is written to the dead-letter queue.

A failure in steps 1-2 is a Date-Level Failure: nothing is written for that
date, and the run continues with the next date. Any other failure is a
Run-Level Failure and stops the run. Either makes the run exit non-zero.

Write modes (ADR 0032): ``append`` inserts each date; ``replace`` admits a date,
then removes its matches, then inserts, so a date that fails keeps its rows;
``rebuild`` is truncate-and-reload of all history without the empty window: it
loads staging copies and swaps them in only when every date loaded.
"""

from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from uuid import uuid4

import pandas as pd

from config.settings import get_settings
from src.common.logging import get_logger
from src.fotmob.bronze.admission import (
    BRONZE_DATABASE,
    AdmittedTable,
    BronzeAdmissionError,
    BronzeTableSpec,
    admit_rows,
    assert_live_bronze_tables_match,
    load_bronze_table_specs,
)
from src.fotmob.bronze.dead_letter import DeadLetterQueue
from src.fotmob.bronze.errors import (
    EXPECTED_RUN_LEVEL_ERRORS,
    BronzeInsertError,
    BronzeSourceError,
    BronzeSourceMissingError,
    is_date_level_failure,
)
from src.fotmob.bronze.match_processor import (
    BronzeProcessingError,
    FotMobBronzeMatchProcessor,
    RowRejection,
)
from src.fotmob.bronze.paths import get_fotmob_historical_path
from src.fotmob.bronze.removal import delete_match_rows, match_dates_for
from src.fotmob.bronze.source import get_matches_dir, iter_match_payloads
from src.fotmob.bronze.write_lock import fotmob_bronze_write_lock
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.contracts import (
    BRONZE_REQUIRED_KEYS,
    LayerContractError,
    assert_bronze_layer_contracts,
    get_bronze_invalid_key_rows,
)
from src.warehouse.databases import STAGING_DATABASE

logger = get_logger(__name__)

FOTMOB_TABLES = list(BRONZE_REQUIRED_KEYS)
WRITE_MODES = ("append", "replace", "rebuild")

__all__ = [
    "BronzeAdmissionError",
    "BronzeDateBatch",
    "BronzeInsertError",
    "BronzeProcessingError",
    "BronzeRunResult",
    "BronzeService",
    "BronzeSourceError",
    "BronzeSourceMissingError",
    "FOTMOB_TABLES",
    "PreparedDate",
    "get_matches_dir",
    "iter_match_payloads",
]


@dataclass
class BronzeRunResult:
    """Structured result returned by BronzeService.run().

    ``failed_dates`` maps each Date-Level Failure to its cause; ``run_error`` is
    the Run-Level Failure that stopped the run, if any. ``removed_rows`` and
    ``stale_match_dates`` describe what ``replace`` removed and which Silver and
    Gold Match Dates it made stale. ``swapped`` tells whether a rebuild replaced
    the warehouse tables.
    """

    exit_code: int
    mode: str = "append"
    dates_processed: int = 0
    tables_loaded: int = 0
    total_rows: int = 0
    row_counts: dict[str, int] = field(default_factory=dict)
    removed_rows: dict[str, int] = field(default_factory=dict)
    stale_match_dates: list[str] = field(default_factory=list)
    dates_without_source: list[str] = field(default_factory=list)
    failed_dates: dict[str, str] = field(default_factory=dict)
    run_error: str | None = None
    swapped: bool | None = None

    def finish(self) -> "BronzeRunResult":
        """Derive totals and the exit code from the recorded outcome."""
        self.tables_loaded = len(self.row_counts)
        self.total_rows = sum(self.row_counts.values())
        self.stale_match_dates = sorted(set(self.stale_match_dates))
        self.exit_code = 1 if self.failed_dates or self.run_error else 0
        return self


@dataclass
class BronzeDateBatch:
    """Every Bronze row read from one Source Date's stored payloads."""

    date_str: str
    match_count: int = 0
    rows: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    rejected_rows: list[RowRejection] = field(default_factory=list)


@dataclass(frozen=True)
class PreparedDate:
    """A Source Date read, processed, and admitted, ready to write."""

    date_str: str
    match_ids: tuple[int, ...]
    admitted: dict[str, AdmittedTable]

    @property
    def match_dates(self) -> list[str]:
        reference = self.admitted.get("match_reference")
        if reference is None:
            return []
        return sorted({str(value) for value in reference.frame["match_date"]})


# ============================================================================
# Reading and admission
# ============================================================================


def collect_date_rows(
    matches_dir: Path, date_str: str, processor: FotMobBronzeMatchProcessor
) -> BronzeDateBatch:
    """Process every stored match of a Source Date into Bronze rows keyed by table."""
    batch = BronzeDateBatch(date_str=date_str, rows={table: [] for table in FOTMOB_TABLES})
    for source, payload in iter_match_payloads(matches_dir, date_str):
        try:
            processed = processor.process_match(payload)
        except BronzeProcessingError as error:
            raise BronzeProcessingError(f"{error} (source {source})") from error
        batch.match_count += 1
        for table, rows in processed.rows.items():
            batch.rows[table].extend(rows)
        batch.rejected_rows.extend(processed.rejected_rows)
    return batch


def admit_date_rows(
    batch: BronzeDateBatch, specs: Mapping[str, BronzeTableSpec]
) -> dict[str, AdmittedTable]:
    """Admit every table with rows; raise once with every table's violations."""
    if batch.rejected_rows:
        raise BronzeAdmissionError(
            f"{len(batch.rejected_rows)} row(s) for {batch.date_str} failed source "
            "validation in the processor: "
            + "; ".join(rejection.describe() for rejection in batch.rejected_rows[:5])
        )
    admitted: dict[str, AdmittedTable] = {}
    errors: list[BronzeAdmissionError] = []
    for table in FOTMOB_TABLES:
        rows = batch.rows.get(table) or []
        if not rows:
            continue
        try:
            admitted[table] = admit_rows(specs[table], rows)
        except BronzeAdmissionError as error:
            errors.append(error)
    if errors:
        raise BronzeAdmissionError(
            f"Bronze rows for {batch.date_str} cannot be admitted",
            violations=[violation for error in errors for violation in error.violations],
        )
    return admitted


def prepare_date(
    date_str: str,
    specs: Mapping[str, BronzeTableSpec],
    historical_root: Path,
    processor: FotMobBronzeMatchProcessor | None = None,
) -> PreparedDate | None:
    """Read, process, and admit a Source Date; ``None`` when nothing is stored for it.

    Raises only Date-Level Failures; nothing is written.
    """
    matches_dir = get_matches_dir(historical_root, date_str)
    if not matches_dir.is_dir():
        logger.warning(
            "No FotMob Bronze source directory for date",
            date=date_str,
            matches_dir=str(matches_dir),
        )
        return None
    batch = collect_date_rows(matches_dir, date_str, processor or FotMobBronzeMatchProcessor())
    if batch.match_count == 0:
        logger.warning(
            "No FotMob match payloads stored for date", date=date_str, matches_dir=str(matches_dir)
        )
        return None
    admitted = admit_date_rows(batch, specs)
    collapsed = {
        table: table_rows.collapsed_duplicates
        for table, table_rows in admitted.items()
        if table_rows.collapsed_duplicates
    }
    if collapsed:
        logger.warning(
            "Collapsed exact duplicate Bronze rows from the source",
            date=date_str,
            collapsed_rows=collapsed,
        )
    match_ids = tuple(sorted({int(row["match_id"]) for row in batch.rows["general"]}))
    logger.info(
        "Admitted FotMob Bronze rows",
        date=date_str,
        matches=batch.match_count,
        rows={table: len(table_rows.frame) for table, table_rows in admitted.items()},
    )
    return PreparedDate(date_str=date_str, match_ids=match_ids, admitted=admitted)


# ============================================================================
# Writing
# ============================================================================


def insert_admitted_table(
    client: ClickHouseClient,
    table: str,
    frame: pd.DataFrame,
    date_str: str,
    dead_letter_queue: DeadLetterQueue | None = None,
    *,
    database: str = BRONZE_DATABASE,
    physical_table: str | None = None,
) -> int:
    """Insert one admitted table; a failure goes to the DLQ and raises."""
    target = physical_table or table
    try:
        inserted = client.insert_dataframe_qualified_table(target, frame, database=database)
    except Exception as error:
        dlq_path = (dead_letter_queue or DeadLetterQueue()).send_to_dlq(
            table=table,
            data=frame,
            error=str(error),
            context={"date": date_str, "database": database},
        )
        raise BronzeInsertError(
            f"Insert into {database}.{target} for {date_str} failed "
            f"({len(frame)} rows written to {dlq_path}): {error}"
        ) from error
    if inserted != len(frame):
        raise BronzeInsertError(
            f"Insert into {database}.{target} for {date_str} reported "
            f"{inserted} rows; {len(frame)} were admitted"
        )
    logger.info(
        "Loaded rows into table",
        database=database,
        table_name=target,
        date=date_str,
        rows_inserted=inserted,
    )
    return inserted


def write_prepared_date(
    client: ClickHouseClient, prepared: PreparedDate, *, replace: bool, result: BronzeRunResult
) -> dict[str, int]:
    """Write an admitted Source Date into Bronze and check the post-load contract.

    With ``replace``, the date's matches are removed first and the Match Dates
    they covered (before and after) are recorded as stale for Silver and Gold.
    """
    if replace:
        stale = set(match_dates_for(client, prepared.match_ids)) | set(prepared.match_dates)
        removed = delete_match_rows(client, prepared.match_ids)
        for table, count in removed.items():
            result.removed_rows[table] = result.removed_rows.get(table, 0) + count
        result.stale_match_dates.extend(stale)
        logger.info(
            "Removed Bronze rows before replacing date",
            date=prepared.date_str,
            matches=len(prepared.match_ids),
            removed_rows=removed,
        )
    baseline_invalid_rows = get_bronze_invalid_key_rows(
        client, table_names=list(prepared.admitted), database=BRONZE_DATABASE
    )
    inserted = {
        table: insert_admitted_table(client, table, table_rows.frame, prepared.date_str)
        for table, table_rows in prepared.admitted.items()
    }
    assert_bronze_layer_contracts(
        client,
        inserted_rows_by_table=inserted,
        baseline_invalid_rows_by_table=baseline_invalid_rows,
        database=BRONZE_DATABASE,
        log=logger,
    )
    return inserted


# ============================================================================
# BronzeService
# ============================================================================


class BronzeService:
    """Coordinates FotMob Bronze loading into ClickHouse.

    Owns the write lock, the warehouse-schema check, date iteration, failure
    classes, and the run result. Reading, admission, and writing of a date live
    in the module-level functions above.
    """

    def __init__(
        self,
        client: ClickHouseClient | None = None,
        force: bool = False,
        historical_root: Path | None = None,
        specs: Mapping[str, BronzeTableSpec] | None = None,
        lock_path: Path | None = None,
    ):
        self.client = client
        self.force = force
        self._historical_root = historical_root
        self._specs = specs
        self.lock_path = lock_path

    @property
    def historical_root(self) -> Path:
        if self._historical_root is None:
            self._historical_root = get_fotmob_historical_path(
                get_settings().fotmob.storage.bronze_path
            )
        return self._historical_root

    @property
    def specs(self) -> Mapping[str, BronzeTableSpec]:
        if self._specs is None:
            self._specs = load_bronze_table_specs()
        return self._specs

    def load_dates(self, dates: list[str], mode: str = "append") -> BronzeRunResult:
        """Write dates in order; a Date-Level Failure fails only its date."""
        if mode not in WRITE_MODES:
            raise ValueError(f"Unknown Bronze write mode: {mode}")
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for loading")
        result = BronzeRunResult(exit_code=0, mode=mode)
        try:
            with fotmob_bronze_write_lock(f"load-fotmob-bronze --{mode}", self.lock_path):
                assert_live_bronze_tables_match(self.client, self.specs)
                if mode == "rebuild":
                    self._rebuild(dates, result)
                else:
                    for date_str in dates:
                        self._write_one_date(date_str, result, replace=mode == "replace")
        except Exception as error:  # noqa: BLE001 - logged by _record_run_failure; exits non-zero
            self._record_run_failure(result, error)
        return self._report(result.finish())

    def _prepare_or_record(
        self, date_str: str, result: BronzeRunResult, *, require_source: bool
    ) -> PreparedDate | None:
        """Prepare a date; record a Date-Level Failure or a date without source as ``None``."""
        logger.info("Loading data for date", database=BRONZE_DATABASE, date=date_str)
        try:
            prepared = prepare_date(date_str, self.specs, self.historical_root)
            if prepared is None and require_source:
                raise BronzeSourceMissingError(
                    f"No stored FotMob payloads for Source Date {date_str}; "
                    "it cannot be replaced (ADR 0032)"
                )
        except Exception as error:
            if not is_date_level_failure(error):
                raise
            result.failed_dates[date_str] = str(error)
            logger.error(
                "Bronze date failed; continuing with the next date",
                database=BRONZE_DATABASE,
                date=date_str,
                error_type=type(error).__name__,
                error=str(error),
            )
            return None
        result.dates_processed += 1
        if prepared is None:
            result.dates_without_source.append(date_str)
        return prepared

    def _write_one_date(self, date_str: str, result: BronzeRunResult, *, replace: bool) -> None:
        prepared = self._prepare_or_record(date_str, result, require_source=replace)
        if prepared is None:
            return
        inserted = write_prepared_date(self.client, prepared, replace=replace, result=result)
        for table, count in inserted.items():
            result.row_counts[table] = result.row_counts.get(table, 0) + count

    def _rebuild(self, dates: list[str], result: BronzeRunResult) -> None:
        """Truncate-and-reload without the empty window: load staging copies, then swap.

        The copies clone each warehouse table, so the swap never changes a table
        definition. They are swapped in only if every date loaded and at least one
        row did (an unmounted data folder must not empty Bronze); otherwise they are
        dropped and Bronze is unchanged. Each ``EXCHANGE TABLES`` is atomic per
        table, so a crash inside the swap loop can leave tables mixed until rerun.
        """
        run_id = uuid4().hex[:12]
        stage_tables = {
            table: f"_depthmark_{run_id}_{BRONZE_DATABASE}__{table}_rebuild"
            for table in FOTMOB_TABLES
        }
        created: list[str] = []
        result.swapped = False
        try:
            for table, stage_table in stage_tables.items():
                self.client.execute(
                    f"CREATE TABLE {STAGING_DATABASE}.{stage_table} AS {BRONZE_DATABASE}.{table}"
                )
                created.append(stage_table)
            for date_str in dates:
                prepared = self._prepare_or_record(date_str, result, require_source=False)
                if prepared is None:
                    continue
                for table, table_rows in prepared.admitted.items():
                    count = insert_admitted_table(
                        self.client,
                        table,
                        table_rows.frame,
                        date_str,
                        database=STAGING_DATABASE,
                        physical_table=stage_tables[table],
                    )
                    result.row_counts[table] = result.row_counts.get(table, 0) + count
            if result.failed_dates:
                logger.error(
                    "Bronze rebuild not swapped; the warehouse tables are unchanged",
                    failed_dates=len(result.failed_dates),
                )
                return
            if not result.row_counts:
                raise LayerContractError(
                    "Bronze rebuild staged no rows; refusing to swap empty tables into Bronze. "
                    f"Check that Historical storage is available under {self.historical_root}"
                )
            for table, stage_table in stage_tables.items():
                self.client.execute(
                    f"EXCHANGE TABLES {BRONZE_DATABASE}.{table} "
                    f"AND {STAGING_DATABASE}.{stage_table}"
                )
            result.swapped = True
            logger.info(
                "Bronze rebuild swapped into the warehouse tables",
                dates=len(dates),
                total_rows=sum(result.row_counts.values()),
            )
        finally:
            for stage_table in created:
                self.client.execute(f"DROP TABLE IF EXISTS {STAGING_DATABASE}.{stage_table}")

    @staticmethod
    def _record_run_failure(result: BronzeRunResult, error: Exception) -> None:
        """Record the Run-Level Failure that stopped the run."""
        logger.error(
            "Bronze run stopped",
            database=BRONZE_DATABASE,
            error_type=type(error).__name__,
            error=str(error),
            exc_info=not isinstance(error, EXPECTED_RUN_LEVEL_ERRORS),
        )
        result.run_error = f"{type(error).__name__}: {error}"

    @staticmethod
    def _report(result: BronzeRunResult) -> BronzeRunResult:
        if result.dates_without_source:
            logger.warning(
                "Dates without stored FotMob Bronze source",
                dates=",".join(result.dates_without_source),
                count=len(result.dates_without_source),
            )
        if result.failed_dates:
            logger.error(
                "Bronze dates failed",
                count=len(result.failed_dates),
                dates=",".join(sorted(result.failed_dates)),
            )
        if result.stale_match_dates:
            logger.warning(
                "Silver and Gold scopes are stale for replaced matches",
                match_dates=",".join(result.stale_match_dates),
            )
        return result

    def run(
        self,
        *,
        dates: list[str] | None = None,
        dry_run: bool = False,
        mode: str = "append",
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
                "Running bronze loader in dry-run mode (nothing is removed, swapped, or loaded)"
            )
            logger.info(
                "Bronze dry-run plan",
                database=BRONZE_DATABASE,
                mode=mode,
                dates=",".join(planned_dates),
                total_dates=len(planned_dates),
                tables=",".join(FOTMOB_TABLES),
                force=self.force,
            )
            result = BronzeRunResult(exit_code=0, mode=mode)
            result.dates_processed = len(planned_dates)
            return result

        if not dates:
            logger.warning("No dates to process")
            return BronzeRunResult(exit_code=0, mode=mode)

        return self.load_dates(dates, mode=mode)
