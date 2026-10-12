"""FotMob Bronze error types and their failure class (ADR 0031).

A Date-Level Failure is confined to one Source Date's source; the run records it
and continues. Every other error is a Run-Level Failure and stops the run.
"""

from src.fotmob.bronze.admission import BronzeAdmissionError, BronzeSchemaError
from src.fotmob.bronze.match_processor import BronzeProcessingError
from src.fotmob.bronze.write_lock import BronzeWriteLockedError
from src.warehouse.contracts import LayerContractError


class BronzeSourceError(RuntimeError):
    """Raised when a stored FotMob payload for a Source Date cannot be read."""


class BronzeSourceMissingError(BronzeSourceError):
    """Raised when a Source Date has no stored payloads to identify its Bronze rows."""


class BronzeInsertError(RuntimeError):
    """Raised when ClickHouse does not accept an admitted Bronze table."""


EXPECTED_RUN_LEVEL_ERRORS = (
    BronzeInsertError,
    BronzeSchemaError,
    BronzeWriteLockedError,
    LayerContractError,
)


def is_date_level_failure(error: BaseException) -> bool:
    """Return True for failures confined to one Source Date's source.

    Unreadable or missing payloads, processor errors, and admission violations
    affect only their date. Schema errors are admission errors that affect every
    date, so they stay Run-Level Failures.
    """
    if isinstance(error, BronzeSchemaError):
        return False
    return isinstance(error, (BronzeSourceError, BronzeProcessingError, BronzeAdmissionError))
