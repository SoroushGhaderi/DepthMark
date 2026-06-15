"""Thin transport layer for the Telegram Bot API.

Reads configuration from ``config.settings`` (single source of truth).
"""

from pathlib import Path
from typing import Any

import requests

from config.settings import settings
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)

_TEMPLATE_DIR = Path(__file__).parent / "templates"


def _format_duration(seconds: float) -> str:
    """Format seconds into a human-readable duration string."""
    if seconds < 60:
        return f"{seconds:.0f}s"
    if seconds < 3600:
        minutes = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{minutes}m {secs}s"
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{hours}h {minutes}m"


class TelegramClient:
    """Thin transport layer for sending Telegram messages via Bot API."""

    def __init__(self) -> None:
        self._bot_token = settings.telegram_bot_token
        self._chat_id = settings.telegram_chat_id
        self._base_url = (
            f"https://api.telegram.org/bot{self._bot_token}" if self._bot_token else ""
        )
        self._jinja_env = self._build_jinja_env()

    @staticmethod
    def _build_jinja_env():
        from jinja2 import Environment, FileSystemLoader

        return Environment(
            loader=FileSystemLoader(str(_TEMPLATE_DIR)),
            autoescape=False,
        )

    @property
    def is_configured(self) -> bool:
        return bool(self._bot_token and self._chat_id)

    def send_message(self, html: str, silent: bool = False) -> bool:
        """Send a pre-rendered HTML message to the configured chat."""
        if not self.is_configured:
            logger.warning("Telegram not configured, skipping send")
            return False
        payload = {
            "chat_id": self._chat_id,
            "text": html,
            "parse_mode": "HTML",
            "disable_notification": silent,
        }
        try:
            resp = requests.post(
                f"{self._base_url}/sendMessage", json=payload, timeout=30
            )
            resp.raise_for_status()
            logger.info("Telegram message sent successfully")
            return True
        except requests.RequestException as exc:
            logger.error("Telegram send failed: %s", exc)
            return False

    def render_and_send(self, template_name: str, data: Any, silent: bool = False) -> bool:
        """Render a Jinja2 template with *data* and send the result."""
        html = self._render(template_name, data)
        override = getattr(data, "silent", None)
        use_silent = override if override is not None else silent
        return self.send_message(html, silent=use_silent)

    def _render(self, template_name: str, data: Any) -> str:
        template = self._jinja_env.get_template(template_name)
        return template.render(data=data, format_duration=_format_duration)
