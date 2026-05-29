"""Environment-based settings management for DepthMark project.

This module provides centralized environment configuration management.
All environment variables are loaded from .env file using pydantic-settings.

Usage:
    from config.settings import settings, Environment
    
    if settings.environment == Environment.PROD:
        logger.info("Running in production")
    
    logger.info(f"Log level: {settings.log_level}")
"""

from enum import Enum
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Environment(str, Enum):
    """Application environment types."""
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TESTING = "testing"


class Settings(BaseSettings):
    """Global application settings loaded from environment variables.
    
    Uses pydantic-settings for automatic env var parsing, type coercion,
    and validation.
    
    Environment Variables:
        ENVIRONMENT: Application environment (development/staging/production)
        LOG_LEVEL: Global log level (DEBUG/INFO/WARNING/ERROR)
        DATA_DIR: Base directory for all data storage
        CLICKHOUSE_HOST: ClickHouse database host
        CLICKHOUSE_PORT: ClickHouse database port
        CLICKHOUSE_USER: ClickHouse database user
        CLICKHOUSE_PASSWORD: ClickHouse database password
    """
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="allow",
    )
    
    environment: Environment = Environment.DEVELOPMENT
    
    log_level: str = "INFO"
    log_dir: str = "logs"
    
    data_dir: str = "data"
    
    clickhouse_host: str = "localhost"
    clickhouse_port: int = 8123
    clickhouse_user: str = "default"
    clickhouse_password: str = ""
    clickhouse_database: str = "default"
    clickhouse_db_fotmob: str = "fotmob"
    clickhouse_db_gold_scenarios: str = "gold_scenarios"
    clickhouse_db_gold_signals: str = "gold_signals"
    
    enable_metrics: bool = True
    enable_health_checks: bool = True
    
    telegram_bot_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    
    config_file_path: str = "config.yaml"
    
    fotmob_browser_enabled: bool = False
    fotmob_proxy_enabled: bool = False
    fotmob_proxy_http: Optional[str] = None
    fotmob_proxy_https: Optional[str] = None
    
    s3_endpoint: Optional[str] = None
    s3_access_key: Optional[str] = None
    s3_secret_key: Optional[str] = None
    
    @property
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.environment == Environment.DEVELOPMENT
    
    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.environment == Environment.PRODUCTION
    
    @property
    def is_testing(self) -> bool:
        """Check if running in testing environment."""
        return self.environment == Environment.TESTING
    
    def ensure_directories(self):
        """Create required directories if they don't exist."""
        Path(self.data_dir).mkdir(parents=True, exist_ok=True)
        Path(self.log_dir).mkdir(parents=True, exist_ok=True)
    
    def to_dict(self) -> dict:
        """Convert settings to dictionary."""
        return {
            'environment': self.environment.value,
            'log_level': self.log_level,
            'log_dir': self.log_dir,
            'data_dir': self.data_dir,
            'clickhouse_host': self.clickhouse_host,
            'clickhouse_port': self.clickhouse_port,
            'clickhouse_database': self.clickhouse_database,
            'clickhouse_db_fotmob': self.clickhouse_db_fotmob,
            'enable_metrics': self.enable_metrics,
            'enable_health_checks': self.enable_health_checks,
        }


settings = Settings()

settings.ensure_directories()


__all__ = ['settings', 'Settings', 'Environment']
