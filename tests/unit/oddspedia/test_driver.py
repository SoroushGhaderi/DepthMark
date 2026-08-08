import inspect
from unittest.mock import Mock

from src.oddspedia.scraping.driver import (
    _BLOCKED_RESOURCE_URLS,
    DriverManager,
    _chrome_for_testing_platform,
    _configure_resource_policy,
    get_driver,
)


def test_resource_policy_blocks_nonessential_resources_by_default():
    driver = Mock()

    _configure_resource_policy(driver, load_resources=False)

    driver.execute_cdp_cmd.assert_any_call("Network.enable", {})
    driver.execute_cdp_cmd.assert_any_call(
        "Network.setBlockedURLs",
        {"urls": list(_BLOCKED_RESOURCE_URLS)},
    )


def test_resource_policy_load_resources_skips_all_blocking():
    driver = Mock()

    _configure_resource_policy(driver, load_resources=True)

    driver.execute_cdp_cmd.assert_not_called()


def test_resource_policy_has_one_false_by_default():
    assert inspect.signature(get_driver).parameters["load_resources"].default is False
    assert inspect.signature(DriverManager).parameters["load_resources"].default is False


def test_chrome_for_testing_platform_uses_linux_artifact_on_linux(monkeypatch):
    monkeypatch.setattr("src.oddspedia.scraping.driver.platform.system", lambda: "Linux")
    monkeypatch.setattr("src.oddspedia.scraping.driver.platform.machine", lambda: "x86_64")

    assert _chrome_for_testing_platform() == "linux64"


def test_get_driver_honors_container_chrome_and_driver_environment(monkeypatch):
    options = Mock()
    driver = Mock()
    chrome = Mock(return_value=driver)
    monkeypatch.setattr("src.oddspedia.scraping.driver.uc.ChromeOptions", lambda: options)
    monkeypatch.setattr("src.oddspedia.scraping.driver.uc.Chrome", chrome)
    monkeypatch.setattr(
        "src.oddspedia.scraping.driver.detect_chrome_version",
        lambda chrome_binary=None: 148,
    )
    monkeypatch.setattr("src.oddspedia.scraping.driver._configure_resource_policy", Mock())
    monkeypatch.setenv("CHROME_BIN", "/usr/bin/google-chrome")
    monkeypatch.setenv("CHROMEDRIVER_PATH", "/usr/local/bin/chromedriver")

    get_driver()

    assert options.binary_location == "/usr/bin/google-chrome"
    assert chrome.call_args.kwargs["driver_executable_path"] == "/usr/local/bin/chromedriver"
