"""DepthMark Package - FotMob scraper integration."""

__version__ = "1.0.0"

# Bootstrap logging early so modules using stdlib logging are routed
# through the shared structlog configuration.
from .common.logging import initialize_logging

initialize_logging()
