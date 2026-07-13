"""Logging utilities for DepthMark project with structlog as the global backend."""

import logging
import os
import re
import sys
import warnings
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

import structlog
from structlog.stdlib import LoggerFactory


_STRUCTLOG_CONFIGURED = False
_DEFAULT_LOGGER_NAME = "depthmark"
_ANSI_ESCAPE_RE = re.compile(r"\x1B\[[0-?]*[ -/]*[@-~]")


def _normalize_log_level(log_level: str) -> int:
    """Convert string level to stdlib logging constant."""
    return getattr(logging, log_level.upper(), logging.INFO)


def _is_production_environment() -> bool:
    """Return True when runtime environment should default to JSON logs."""
    env = os.getenv("SCRAPER_ENV") or os.getenv("ENVIRONMENT") or "development"
    return env.lower() == "production"


def _merge_extra_fields(
    _: structlog.typing.WrappedLogger,
    __: str,
    event_dict: structlog.typing.EventDict,
) -> structlog.typing.EventDict:
    """
    Flatten stdlib-style ``extra={...}`` into top-level structured fields.

    This keeps compatibility with existing call-sites while we use BoundLogger.
    """
    extra = event_dict.pop("extra", None)
    if isinstance(extra, dict):
        for key, value in extra.items():
            event_dict.setdefault(key, value)
    return event_dict


def configure_logging(
    json_logs: Optional[bool] = None,
    log_level: str = "INFO",
    force: bool = False,
    suppress_noisy_warnings: bool = True,
) -> None:
    """
    Configure structured logging once for the whole process.

    Best-practice defaults:
    - ConsoleRenderer for local/dev readability
    - JSONRenderer in production
    """
    global _STRUCTLOG_CONFIGURED

    use_json = _is_production_environment() if json_logs is None else json_logs

    if suppress_noisy_warnings:
        warnings.filterwarnings(
            "ignore",
            message=r"urllib3 v2 only supports OpenSSL 1\.1\.1\+",
        )

    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=_normalize_log_level(log_level),
        force=force,
    )

    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.PositionalArgumentsFormatter(),
        _merge_extra_fields,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if use_json:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(
            structlog.dev.ConsoleRenderer(
                colors=_should_use_colors(),
                sort_keys=False,
                pad_event=28,
                exception_formatter=structlog.dev.plain_traceback,
            )
        )

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    _STRUCTLOG_CONFIGURED = True


def _should_use_colors() -> bool:
    """Return True when ANSI colors should be used in console logs."""
    if os.getenv("NO_COLOR") is not None:
        return False
    force_color = os.getenv("FORCE_COLOR", "").strip().lower()
    if force_color in {"1", "true", "yes"}:
        return True
    if force_color in {"0", "false", "no"}:
        return False
    return sys.stdout.isatty()


def _resolve_date_suffix(date_suffix: Optional[str] = None) -> str:
    """Resolve date suffix used in log file names."""
    if date_suffix:
        return date_suffix
    return datetime.now().strftime("%Y%m%d")


class _AnsiStrippingFormatter(logging.Formatter):
    """Formatter that removes ANSI escape sequences from log records."""

    def format(self, record: logging.LogRecord) -> str:
        rendered = super().format(record)
        return _ANSI_ESCAPE_RE.sub("", rendered)


def initialize_logging(
    log_level: str = "INFO",
    json_output: Optional[bool] = None,
    force: bool = False,
) -> logging.Logger:
    """Backward-compatible initializer that delegates to ``configure_logging``."""
    configure_logging(json_logs=json_output, log_level=log_level, force=force)
    return logging.getLogger()


def setup_logging(
    name: str = _DEFAULT_LOGGER_NAME,
    log_dir: str = "logs",
    log_level: str = "INFO",
    log_format: Optional[str] = None,
    date_suffix: Optional[str] = None,
) -> structlog.BoundLogger:
    """
    Configure a named logger and optional file output.

    Console/file rendering follows the same renderer choice from configure_logging:
    human-readable in dev, JSON in production unless overridden upstream.
    """
    initialize_logging(log_level=log_level, json_output=None)

    Path(log_dir).mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger(name)
    level = _normalize_log_level(log_level)
    logger.setLevel(level)
    logger.propagate = True

    for handler in logger.handlers[:]:
        if isinstance(handler, logging.FileHandler):
            logger.removeHandler(handler)
            handler.close()

    # Keep a predictable dated log path for easier daily troubleshooting.
    _ = log_format
    resolved_date_suffix = _resolve_date_suffix(date_suffix)
    log_file = Path(log_dir) / f"{name}_{resolved_date_suffix}.log"

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setLevel(level)
    file_handler.setFormatter(_AnsiStrippingFormatter("%(message)s"))
    logger.addHandler(file_handler)

    bound_logger = get_logger(name)
    bound_logger.info("Logging initialized", log_file=str(log_file), log_level=log_level)
    return bound_logger


def get_logger(name: Optional[str] = None, **initial_context: Any) -> structlog.BoundLogger:
    """Get a structlog logger with optional initial context."""
    if not _STRUCTLOG_CONFIGURED:
        configure_logging()
    log = structlog.get_logger(name or _DEFAULT_LOGGER_NAME)
    if initial_context:
        log = log.bind(**initial_context)
    return log


def setup_json_logging(
    name: str = _DEFAULT_LOGGER_NAME,
    log_dir: str = "logs",
    log_level: str = "INFO",
    date_suffix: Optional[str] = None,
) -> structlog.BoundLogger:
    """Compatibility wrapper: force JSON renderer regardless of environment."""
    initialize_logging(log_level=log_level, json_output=True)
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger(name)
    logger.setLevel(_normalize_log_level(log_level))
    logger.propagate = True

    for handler in logger.handlers[:]:
        if isinstance(handler, logging.FileHandler):
            logger.removeHandler(handler)
            handler.close()

    resolved_date_suffix = _resolve_date_suffix(date_suffix)
    log_file = Path(log_dir) / f"{name}_{resolved_date_suffix}.json"

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(_AnsiStrippingFormatter("%(message)s"))
    file_handler.setLevel(_normalize_log_level(log_level))
    logger.addHandler(file_handler)
    bound_logger = get_logger(name)
    bound_logger.info("JSON logging initialized", log_file=str(log_file), log_level=log_level)
    return bound_logger
