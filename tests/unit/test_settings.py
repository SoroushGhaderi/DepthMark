"""Contract tests for Settings, the only reader of configuration."""

import pytest
from pydantic import ValidationError

from config.settings import Settings


def _settings(monkeypatch, tmp_path, yaml_text: str = "", **env: str) -> Settings:
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml_text, encoding="utf-8")
    monkeypatch.setenv("CONFIG_FILE_PATH", str(config_file))
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    return Settings(_env_file=None)


def test_documented_flat_names_set_nested_fields_with_validation(monkeypatch, tmp_path) -> None:
    settings = _settings(
        monkeypatch,
        tmp_path,
        FOTMOB_REQUEST_TIMEOUT="45",
        FOTMOB_FILTER_BY_STATUS="false",
        FOTMOB_ALLOWED_MATCH_STATUSES="FT, AET",
        ODDSPEDIA_MIN_DELAY="1.5",
        FOTMOB_TIMEZONE="UTC",
    )

    assert settings.fotmob.request.timeout == 45
    assert settings.fotmob.scraping.filter_by_status is False
    assert settings.fotmob.scraping.allowed_match_statuses == ("FT", "AET")
    assert settings.fotmob.scraping.timezone == "UTC"
    assert settings.oddspedia.min_delay == 1.5


def test_double_underscore_sets_any_nested_field(monkeypatch, tmp_path) -> None:
    settings = _settings(monkeypatch, tmp_path, FOTMOB__RETRY__MAX_ATTEMPTS="7")

    assert settings.fotmob.retry.max_attempts == 7


def test_source_specific_browser_path_beats_the_image_default(monkeypatch, tmp_path) -> None:
    settings = _settings(
        monkeypatch, tmp_path, CHROME_BIN="/usr/bin/chromium", ODDSPEDIA_CHROME_BIN="/opt/chrome"
    )

    assert settings.oddspedia.chrome_binary == "/opt/chrome"


def test_environment_beats_yaml_and_yaml_beats_defaults(monkeypatch, tmp_path) -> None:
    yaml_text = "fotmob:\n  request:\n    timeout: 60\n    delay_min: 9.0\n"
    settings = _settings(monkeypatch, tmp_path, yaml_text, FOTMOB_REQUEST_TIMEOUT="45")

    assert settings.fotmob.request.timeout == 45
    assert settings.fotmob.request.delay_min == 9.0
    assert settings.fotmob.request.delay_max == 4.0


def test_only_scraper_sections_are_read_from_yaml(monkeypatch, tmp_path) -> None:
    settings = _settings(monkeypatch, tmp_path, "log_level: DEBUG\nclickhouse_port: 1\n")

    assert settings.clickhouse_port == 8123
    assert settings.log_level == "INFO"


def test_malformed_values_fail_instead_of_being_coerced(monkeypatch, tmp_path) -> None:
    with pytest.raises(ValidationError):
        _settings(monkeypatch, tmp_path, FOTMOB_FILTER_BY_STATUS="maybe")


def test_deployment_selector_is_unset_until_configured(monkeypatch, tmp_path) -> None:
    for name in ("DEPTHMARK_ENV", "ENVIRONMENT", "SCRAPER_ENV"):
        monkeypatch.delenv(name, raising=False)

    assert _settings(monkeypatch, tmp_path).deployment_environment is None
    assert _settings(monkeypatch, tmp_path, SCRAPER_ENV="production").deployment_environment == (
        "production"
    )
