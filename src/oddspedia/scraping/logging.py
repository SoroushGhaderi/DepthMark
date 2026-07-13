import logging
import os
import sys
from typing import Any, Optional

import structlog
from structlog.stdlib import LoggerFactory

from src.oddspedia.scraping.config import SCRAPER_ENV


def configure_logging(json_logs: bool = False, log_file: Optional[str] = None) -> None:
    """Configure terminal logging and, optionally, persist the same events."""
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file:
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        handlers.append(logging.FileHandler(log_file, encoding="utf-8"))
    logging.basicConfig(
        format="%(message)s",
        handlers=handlers,
        level=logging.INFO,
        force=True,
    )

    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if json_logs or SCRAPER_ENV == "production":
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: Optional[str] = None, **initial_context: Any) -> structlog.BoundLogger:
    """Get a structlog logger with optional initial context."""
    log = structlog.get_logger(name)
    if initial_context:
        log = log.bind(**initial_context)
    return log
