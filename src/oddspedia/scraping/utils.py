import json
import os
import random
import tempfile
import time
from datetime import UTC, datetime
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from selenium.common.exceptions import TimeoutException, WebDriverException

from src.oddspedia.scraping.config import MAX_DELAY, MIN_DELAY
from src.oddspedia.scraping.driver import wait_for_cloudflare
from src.oddspedia.scraping.logging import get_logger
from src.oddspedia.scraping.metrics import get_metrics
from src.oddspedia.scraping.models import (
    validate_match_link_list,
    validate_match_links,
    validate_match_result,
    validate_match_result_list,
)

logger = get_logger(__name__)


class DataValidationError(ValueError):
    """Raised when a recognised scraper payload does not satisfy its schema."""


MATCH_LINKS_ARTIFACT = "match_links"
MATCH_PAYLOAD_ARTIFACT = "match_payload"


def pin_oddspedia_event_url(url: str, event_id: object) -> str:
    """Return a matchup URL pinned to one Oddspedia event via ``?m=``.

    Oddspedia reuses one slug URL for every meeting between two teams.  Without
    the internal event ID in the query string, that URL can render a newer or
    reverse fixture instead of the event selected on the listing page.
    """
    event_id_text = str(event_id or "").strip()
    if not url or not event_id_text:
        return url

    parsed = urlparse(url)
    query = [
        (key, value) for key, value in parse_qsl(parsed.query, keep_blank_values=True) if key != "m"
    ]
    query.append(("m", event_id_text))
    return urlunparse(parsed._replace(query=urlencode(query)))


def random_delay(min_s=MIN_DELAY, max_s=MAX_DELAY):
    """Sleep for a random duration to mimic human behaviour."""
    delay = random.uniform(min_s, max_s)
    logger.debug("sleeping", delay_s=round(delay, 1))
    time.sleep(delay)


def _is_error_page(title: str) -> bool:
    """Return True if *title* indicates a 404 / error page.

    Oddspedia's current 404 title is "This page could not be found" which does
    NOT contain the substring "not found" (there is "be" between "not" and "found").
    """
    t = (title or "").lower()
    return (
        "could not be found" in t
        or "not found" in t
        or "page not found" in t
        or "404" in t
        or "does not exist" in t
    )


def _is_listing_page_title(title: str) -> bool:
    """Return True when a detail URL rendered the generic football listing shell."""
    t = (title or "").lower()
    return "football live scores" in t and (
        "fixtures" in t or "today's" in t or "results and news" in t
    )


def _is_detail_url(url: str) -> bool:
    """Return True when *url* points below a sport listing route."""
    path = urlparse(url).path.strip("/")
    return len(path.split("/")) >= 2


def safe_get(driver, url, retries=3):
    """Navigate to *url* with retry logic and Cloudflare handling.

    On TimeoutException we check if the page partially loaded (has a title
    and is on the expected domain) — if so, treat it as success.

    If *driver* is a ``DriverManager`` instance and the session dies mid-run,
    ``driver.reconnect()`` is called to start a fresh browser session before
    the next retry.
    """
    metrics = get_metrics()
    for attempt in range(1, retries + 1):
        try:
            logger.info("http_request", url=url, attempt=attempt, max_retries=retries)

            t0 = time.time()
            try:
                driver.current_url
            except Exception as session_err:
                logger.warning(
                    "driver_session_lost",
                    error=type(session_err).__name__,
                    error_detail=str(session_err),
                )
                if hasattr(driver, "reconnect"):
                    try:
                        driver.reconnect()
                        logger.info("driver_reconnected", url=url)
                    except Exception as reconnect_err:
                        logger.error("reconnect_failed", error=str(reconnect_err))
                        return False
                else:
                    logger.error("reconnect_not_supported")
                    return False

            driver.get(url)

            try:
                title = driver.title
                current_url = driver.current_url
                load_time_ms = int((time.time() - t0) * 1000)
                metrics.record_page_load(load_time_ms)

                if title and "oddspedia" in current_url.lower():
                    if _is_detail_url(url) and _is_listing_page_title(title):
                        logger.warning(
                            "detail_page_not_rendered",
                            requested_url=url,
                            current_url=current_url,
                            title=title[:80],
                            attempt=attempt,
                        )
                        if attempt < retries and hasattr(driver, "reconnect"):
                            try:
                                driver.reconnect()
                                logger.info(
                                    "detail_page_retry_reconnected",
                                    url=url,
                                    attempt=attempt,
                                )
                            except Exception as reconnect_err:
                                logger.warning(
                                    "detail_page_retry_reconnect_failed",
                                    url=url,
                                    attempt=attempt,
                                    error=str(reconnect_err),
                                )
                        if attempt < retries:
                            random_delay(2, 5)
                            continue
                        return False
                    if _is_error_page(title):
                        logger.warning("http_404", url=url, title=title[:60])
                        return False
                    logger.info("page_loaded", url=url, title=title[:50], load_time_ms=load_time_ms)
                    cf_passed = wait_for_cloudflare(driver)
                    if cf_passed:
                        metrics.record_cloudflare_challenge()
                        return True
                    logger.warning("cloudflare_not_passed", url=url, title=title[:50])
                    metrics.record_cloudflare_timeout()
                    if attempt < retries:
                        if hasattr(driver, "reconnect"):
                            try:
                                driver.reconnect()
                                logger.info(
                                    "cloudflare_retry_reconnected", url=url, attempt=attempt
                                )
                            except Exception as reconnect_err:
                                logger.warning(
                                    "cloudflare_retry_reconnect_failed",
                                    url=url,
                                    attempt=attempt,
                                    error=str(reconnect_err),
                                )
                        random_delay(2, 5)
                        continue
                    return False
            except Exception as check_err:
                logger.warning("page_check_failed", error=str(check_err))

        except TimeoutException:
            logger.warning("request_timeout", url=url, attempt=attempt)
            if attempt < retries:
                random_delay(2, 5)
        except WebDriverException as exc:
            logger.warning("webdriver_exception", url=url, attempt=attempt, error=str(exc))
            if attempt < retries:
                random_delay(2, 5)
        except Exception as exc:
            logger.warning("request_error", url=url, attempt=attempt, error=str(exc))
            if attempt < retries:
                random_delay(2, 5)

    logger.error("all_retries_failed", url=url, retries=retries)
    metrics.record_cloudflare_timeout()
    return False


def _validate_json_artifact(data, artifact_type=None):
    """Validate a known artifact without normalizing or serializing the model.

    ``artifact_type`` is explicit at production call sites. Shape detection is
    retained only for backward-compatible callers of ``save_json``.
    """
    metrics = get_metrics()
    record_type = artifact_type
    try:
        if artifact_type == MATCH_LINKS_ARTIFACT:
            if not isinstance(data, list):
                raise TypeError("match_links must be a list")
            validate_match_link_list(data)
        elif artifact_type == MATCH_PAYLOAD_ARTIFACT:
            if not isinstance(data, dict):
                raise TypeError("match_payload must be an object")
            validate_match_result(data)
        elif artifact_type is not None:
            raise ValueError(f"unsupported Oddspedia artifact type: {artifact_type}")
        elif isinstance(data, list) and data and "id" in data[0] and "odds" in data[0]:
            record_type = "match_result_list"
            validate_match_result_list(data)
        elif isinstance(data, list) and data and any(key in data[0] for key in ("url", "full_url")):
            record_type = MATCH_LINKS_ARTIFACT
            validate_match_link_list(data)
        elif isinstance(data, dict) and ("odds" in data or "live_odds" in data):
            record_type = MATCH_PAYLOAD_ARTIFACT
            validate_match_result(data)
        elif isinstance(data, dict) and ("url" in data or "full_url" in data):
            record_type = "match_link"
            validate_match_links(data)
        else:
            return
    except Exception as exc:
        logger.warning(
            "validation_failed",
            error=str(exc),
            record_type=record_type or "unknown",
        )
        metrics.record_validation_failure()
        raise DataValidationError(f"{record_type or 'json'} validation failed") from exc

    logger.debug("artifact_validated", record_type=record_type)


def save_json(data, path, artifact_type=None):
    """Validate and atomically write JSON without changing the caller's structure."""
    _validate_json_artifact(data, artifact_type=artifact_type)

    # Source artifacts are written exactly as supplied. Pydantic is only the
    # contract checker: serializing its model would add defaults, coerce values,
    # and silently change the raw provider shape.
    output_data = data
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(output_data, fh, indent=2, ensure_ascii=False, default=str)
            fh.flush()
            os.fsync(fd)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
        raise
    logger.info("json_saved", path=path)


def load_json(path):
    """Read and return JSON from *path*."""
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def now_iso():
    """Return current UTC time as ISO-8601 string."""
    return datetime.now(UTC).isoformat()


def get_performance_logs(driver):
    """Pull Chrome DevTools performance log entries and return parsed JSON."""
    entries = []
    for entry in driver.get_log("performance"):
        try:
            msg = json.loads(entry["message"])["message"]
            entries.append(msg)
        except (json.JSONDecodeError, KeyError):
            continue
    return entries


def extract_network_response_body(driver, request_id):
    """Use CDP to fetch the response body for a given *request_id*."""
    try:
        resp = driver.execute_cdp_cmd("Network.getResponseBody", {"requestId": request_id})
        body = resp.get("body", "")
        return json.loads(body)
    except Exception:
        return None
