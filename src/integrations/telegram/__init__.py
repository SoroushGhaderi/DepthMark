"""Telegram notification service for DepthMark.

Provides a thin transport layer (TelegramClient), typed dataclasses for message
payloads, and Jinja2 templates for rendering formatted HTML messages.
"""

from .client import TelegramClient
from .messages import (
    DailyReportData,
    ErrorAlertData,
    LayerAlertData,
    MonthlyReportData,
    PipelineSummaryData,
)

__all__ = [
    "TelegramClient",
    "DailyReportData",
    "MonthlyReportData",
    "LayerAlertData",
    "PipelineSummaryData",
    "ErrorAlertData",
]
