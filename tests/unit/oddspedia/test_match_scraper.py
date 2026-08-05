from src.oddspedia.scraping import match_scraper


class _EventuallyPresentDriver:
    def __init__(self):
        self.calls = 0

    def find_elements(self, by, value):
        self.calls += 1
        return [] if self.calls == 1 else ["show-more"]


def test_optional_element_poll_returns_as_soon_as_control_appears(monkeypatch):
    driver = _EventuallyPresentDriver()
    monkeypatch.setattr(match_scraper.time, "sleep", lambda _seconds: None)

    elements = match_scraper._find_optional_elements(driver, "xpath", "show-more")

    assert elements == ["show-more"]
    assert driver.calls == 2
