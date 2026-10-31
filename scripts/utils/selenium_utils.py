"""Optimized Selenium utilities for faster scraping performance.

These utilities help reduce the overhead of Selenium operations, particularly
around implicit waits and element lookups.
"""

from contextlib import contextmanager

from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.support.ui import WebDriverWait


@contextmanager
def fast_lookup(driver: WebDriver):
    """Context manager for fast element lookups with zero implicit wait.

    Use this when you know an element might not exist and want to fail fast.

    Example:
        with fast_lookup(driver):
            elements = driver.find_elements(By.CSS_SELECTOR, ".optional-element")
            if not elements:
                return None
    """
    original_wait = 10
    try:
        driver.implicitly_wait(0)
        yield
    finally:
        driver.implicitly_wait(original_wait)


@contextmanager
def temporary_wait(driver: WebDriver, seconds: float):
    """Context manager to temporarily change implicit wait.

    Example:
        with temporary_wait(driver, 2.0):
            element = driver.find_element(By.ID, "quick-check")
    """
    original_wait = 10
    try:
        driver.implicitly_wait(seconds)
        yield
    finally:
        driver.implicitly_wait(original_wait)


def find_with_fallbacks(
    driver: WebDriver, selectors: list[tuple], timeout: float = 2.0, must_be_visible: bool = True
) -> WebElement | None:
    """Try multiple selectors in order, returning first match.

    Args:
        driver: Selenium WebDriver
        selectors: List of (By.TYPE, "selector") tuples
        timeout: Max seconds to wait for each selector
        must_be_visible: If True, only return visible elements

    Returns:
        First matching element, or None

    Example:
        element = find_with_fallbacks(
            driver,
            [
                (By.CSS_SELECTOR, ".primary-table"),
                (By.CSS_SELECTOR, "table.data"),
                (By.TAG_NAME, "table")
            ],
            timeout=1.0
        )
    """
    with temporary_wait(driver, timeout):
        for by, selector in selectors:
            try:
                elements = driver.find_elements(by, selector)
                if elements:
                    if must_be_visible:
                        visible = [e for e in elements if e.is_displayed()]
                        if visible:
                            return visible[0]
                    else:
                        return elements[0]
            except WebDriverException:
                continue
    return None


def find_all_with_fallbacks(
    driver: WebDriver, selectors: list[tuple], timeout: float = 2.0, must_be_visible: bool = True
) -> list[WebElement]:
    """Try multiple selectors in order, returning all matches from first successful selector.

    Similar to find_with_fallbacks but returns all matching elements.
    """
    with temporary_wait(driver, timeout):
        for by, selector in selectors:
            try:
                elements = driver.find_elements(by, selector)
                if elements:
                    if must_be_visible:
                        visible = [e for e in elements if e.is_displayed()]
                        if visible:
                            return visible
                    else:
                        return elements
            except WebDriverException:
                continue
    return []


def quick_check(driver: WebDriver, by: str, selector: str) -> bool:
    """Quickly check if element exists without waiting.

    Returns True if found, False otherwise. Never waits.

    Example:
        if quick_check(driver, By.CSS_SELECTOR, ".table"):
            pass
        else:
            pass
    """
    with fast_lookup(driver):
        try:
            elements = driver.find_elements(by, selector)
            return len(elements) > 0
        except WebDriverException:
            return False


def wait_for_any(
    driver: WebDriver, selectors: list[tuple], timeout: float = 10.0
) -> WebElement | None:
    """Wait for any of the given selectors to appear.

    More efficient than multiple separate waits.

    Args:
        driver: Selenium WebDriver
        selectors: List of (By.TYPE, "selector") tuples
        timeout: Total timeout for all selectors

    Returns:
        First element that appears, or None if timeout
    """
    try:

        def any_selector_present(driver):
            for by, selector in selectors:
                try:
                    elements = driver.find_elements(by, selector)
                    if elements:
                        return elements[0]
                except WebDriverException:
                    continue
            return False

        return WebDriverWait(driver, timeout).until(any_selector_present)
    except TimeoutException:
        return None


class ElementCache:
    """Cache for frequently accessed elements to avoid repeated lookups.

    Use this when you need to access the same element multiple times.
    Automatically validates stale elements.

    Example:
        cache = ElementCache(driver)

        table = cache.get(By.CSS_SELECTOR, ".data-table")

        table = cache.get(By.CSS_SELECTOR, ".data-table")
    """

    def __init__(self, driver: WebDriver):
        self.driver = driver
        self._cache = {}

    def get(self, by: str, selector: str) -> WebElement | None:
        """Get element, using cache if available and not stale."""
        cache_key = (by, selector)

        if cache_key in self._cache:
            element = self._cache[cache_key]
            try:
                element.is_enabled()
                return element
            except WebDriverException:
                del self._cache[cache_key]

        try:
            elements = self.driver.find_elements(by, selector)
            if elements:
                element = elements[0]
                self._cache[cache_key] = element
                return element
        except WebDriverException:
            pass

        return None

    def clear(self):
        """Clear the cache (e.g., after page navigation)."""
        self._cache.clear()
