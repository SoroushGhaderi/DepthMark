"""Tests for the structured-logging rules in check_logging_style.py."""

from pathlib import Path

from scripts.quality.check_logging_style import structured_call_violations

PATH = Path("example.py")


def test_constant_message_with_arguments_passes() -> None:
    source = 'logger.info("Loaded %s rows", count, table="bronze.match")\n'

    assert structured_call_violations(PATH, source) == []


def test_fstring_message_is_rejected() -> None:
    source = 'self.logger.warning(f"Loaded {count} rows")\n'

    assert structured_call_violations(PATH, source) == ["example.py:1: f-string logger message"]


def test_stdlib_extra_is_rejected() -> None:
    source = 'log.info("Loaded rows", extra={"count": count})\n'

    assert structured_call_violations(PATH, source) == [
        "example.py:1: extra={...} instead of key/value fields"
    ]


def test_non_logger_calls_are_ignored() -> None:
    source = 'parser.error(f"bad value {value}")\nprint(f"{value}")\n'

    assert structured_call_violations(PATH, source) == []
