import inspect
from unittest.mock import Mock

from src.oddspedia.scraping.driver import (
    _BLOCKED_RESOURCE_URLS,
    DriverManager,
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
