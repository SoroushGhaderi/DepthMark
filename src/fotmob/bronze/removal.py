"""Bronze Removal: deleting a Source Date scope's matches from FotMob Bronze (ADR 0032).

Removal touches only Bronze. Silver and Gold are scoped by Match Date and owned
by their own loaders, so removal reports the Match Dates whose Silver and Gold
scopes are now stale, with the commands that rebuild them, instead of cascading.
"""

from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from src.common.logging import get_logger
from src.fotmob.bronze.admission import (
    BRONZE_DATABASE,
    BronzeTableSpec,
    assert_live_bronze_tables_match,
    load_bronze_table_specs,
)
from src.fotmob.bronze.errors import EXPECTED_RUN_LEVEL_ERRORS, is_date_level_failure
from src.fotmob.bronze.source import source_date_match_ids
from src.fotmob.bronze.write_lock import fotmob_bronze_write_lock
from src.warehouse.contracts import BRONZE_REQUIRED_KEYS

logger = get_logger(__name__)

BRONZE_TABLES = tuple(BRONZE_REQUIRED_KEYS)
FULL_HISTORY_FOLLOW_UP = (
    "depthmark load-fotmob-silver --full-history",
    "depthmark load-fotmob-gold --full-history",
)


def _match_id_list(match_ids: Iterable[int]) -> str:
    return ", ".join(str(int(match_id)) for match_id in match_ids)


def _scalar(result) -> int:
    return int(result.result_rows[0][0])


def count_match_rows(
    client, match_ids: Sequence[int], tables: Sequence[str] = BRONZE_TABLES
) -> dict[str, int]:
    """Return the stored rows per Bronze table that belong to the given matches."""
    if not match_ids:
        return {table: 0 for table in tables}
    id_list = _match_id_list(match_ids)
    return {
        table: _scalar(
            client.execute(
                f"SELECT count() FROM {BRONZE_DATABASE}.{table} WHERE match_id IN ({id_list})",
                log_query=False,
            )
        )
        for table in tables
    }


def delete_match_rows(
    client, match_ids: Sequence[int], tables: Sequence[str] = BRONZE_TABLES
) -> dict[str, int]:
    """Delete the given matches from every Bronze table and return the rows removed.

    Each delete waits for its mutation (``mutations_sync = 2``), so rows inserted
    afterwards cannot be caught by it and the counts describe completed work.
    """
    counts = count_match_rows(client, match_ids, tables)
    id_list = _match_id_list(match_ids)
    for table, count in counts.items():
        if count:
            client.execute(
                f"ALTER TABLE {BRONZE_DATABASE}.{table} DELETE WHERE match_id IN ({id_list}) "
                "SETTINGS mutations_sync = 2"
            )
    return counts


def match_dates_for(client, match_ids: Sequence[int]) -> list[str]:
    """Return the ISO Match Dates Bronze holds for the given matches."""
    if not match_ids:
        return []
    result = client.execute(
        f"SELECT DISTINCT toString(match_date) FROM {BRONZE_DATABASE}.match_reference "
        f"WHERE match_id IN ({_match_id_list(match_ids)}) ORDER BY 1",
        log_query=False,
    )
    return [str(row[0]) for row in result.result_rows]


def count_all_rows(client, tables: Sequence[str] = BRONZE_TABLES) -> dict[str, int]:
    """Return the stored rows per Bronze table."""
    return {
        table: _scalar(
            client.execute(f"SELECT count() FROM {BRONZE_DATABASE}.{table}", log_query=False)
        )
        for table in tables
    }


def stale_scope_commands(match_dates: Iterable[str]) -> list[str]:
    """Return the Silver then Gold commands that rebuild the scopes of these Match Dates.

    A month with one stale date reruns that date; a month with several reruns the
    month, which replaces the same partitions in one pass.
    """
    by_month: dict[str, list[str]] = defaultdict(list)
    for iso_date in sorted(set(match_dates)):
        compact = iso_date.replace("-", "")
        by_month[compact[:6]].append(compact)
    scopes = [
        f"--date {dates[0]}" if len(dates) == 1 else f"--month {month}"
        for month, dates in sorted(by_month.items())
    ]
    return [f"depthmark load-fotmob-silver {scope}" for scope in scopes] + [
        f"depthmark load-fotmob-gold {scope}" for scope in scopes
    ]


@dataclass
class BronzeRemovalResult:
    """What a removal removed (or, with ``dry_run``, would remove) and what it made stale."""

    dry_run: bool = False
    full_history: bool = False
    exit_code: int = 0
    dates_removed: list[str] = field(default_factory=list)
    removed_rows: dict[str, int] = field(default_factory=dict)
    stale_match_dates: list[str] = field(default_factory=list)
    follow_up_commands: list[str] = field(default_factory=list)
    failed_dates: dict[str, str] = field(default_factory=dict)
    run_error: str | None = None

    def finish(self) -> "BronzeRemovalResult":
        self.stale_match_dates = sorted(set(self.stale_match_dates))
        if self.full_history:
            self.follow_up_commands = list(FULL_HISTORY_FOLLOW_UP)
        else:
            self.follow_up_commands = stale_scope_commands(self.stale_match_dates)
        self.exit_code = 1 if self.failed_dates or self.run_error else 0
        return self


class BronzeRemovalService:
    """Removes Source Date scopes from FotMob Bronze (``remove-fotmob-bronze``).

    A date whose payloads are no longer stored cannot be identified and is a
    Date-Level Failure; the run continues. Any other failure stops the run.
    """

    def __init__(
        self,
        client,
        historical_root: Path,
        specs: Mapping[str, BronzeTableSpec] | None = None,
        lock_path: Path | None = None,
    ):
        self.client = client
        self.historical_root = historical_root
        self._specs = specs
        self.lock_path = lock_path

    @property
    def specs(self) -> Mapping[str, BronzeTableSpec]:
        if self._specs is None:
            self._specs = load_bronze_table_specs()
        return self._specs

    def run(
        self,
        *,
        dates: list[str] | None = None,
        full_history: bool = False,
        dry_run: bool = False,
    ) -> BronzeRemovalResult:
        """Remove the scope; ``dry_run`` only counts and takes no lock."""
        result = BronzeRemovalResult(dry_run=dry_run, full_history=full_history)
        try:
            if dry_run:
                self._remove(result, dates or [], full_history)
            else:
                with fotmob_bronze_write_lock("remove-fotmob-bronze", self.lock_path):
                    self._remove(result, dates or [], full_history)
        except Exception as error:
            logger.error(
                "Bronze removal stopped",
                database=BRONZE_DATABASE,
                error_type=type(error).__name__,
                error=str(error),
                exc_info=not isinstance(error, EXPECTED_RUN_LEVEL_ERRORS),
            )
            result.run_error = f"{type(error).__name__}: {error}"
        return self._report(result.finish())

    def _remove(self, result: BronzeRemovalResult, dates: list[str], full_history: bool) -> None:
        assert_live_bronze_tables_match(self.client, self.specs)
        if full_history:
            result.removed_rows = count_all_rows(self.client)
            if not result.dry_run:
                for table in BRONZE_TABLES:
                    self.client.truncate_table(table, database=BRONZE_DATABASE)
            return
        for date_str in dates:
            try:
                match_ids = source_date_match_ids(self.historical_root, date_str)
            except Exception as error:
                if not is_date_level_failure(error):
                    raise
                result.failed_dates[date_str] = str(error)
                logger.error(
                    "Bronze removal date failed; continuing with the next date",
                    date=date_str,
                    error=str(error),
                )
                continue
            result.stale_match_dates.extend(match_dates_for(self.client, match_ids))
            if result.dry_run:
                counts = count_match_rows(self.client, match_ids)
            else:
                counts = delete_match_rows(self.client, match_ids)
            for table, count in counts.items():
                result.removed_rows[table] = result.removed_rows.get(table, 0) + count
            result.dates_removed.append(date_str)
            logger.info(
                "Would remove Bronze rows for date" if result.dry_run else "Removed Bronze rows",
                date=date_str,
                matches=len(match_ids),
                rows=counts,
            )

    @staticmethod
    def _report(result: BronzeRemovalResult) -> BronzeRemovalResult:
        if result.failed_dates:
            logger.error(
                "Bronze removal dates failed",
                count=len(result.failed_dates),
                dates=",".join(sorted(result.failed_dates)),
            )
        if result.follow_up_commands and not result.run_error:
            logger.warning(
                "Silver and Gold scopes are stale; rerun them after reloading Bronze",
                match_dates=",".join(result.stale_match_dates) or "all",
                commands=" ; ".join(result.follow_up_commands),
            )
        return result
