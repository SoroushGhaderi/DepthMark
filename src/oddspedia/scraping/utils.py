import json
import os
import tempfile
import time
import random
from datetime import datetime, timezone

from selenium.common.exceptions import TimeoutException, WebDriverException

from src.oddspedia.scraping.config import MIN_DELAY, MAX_DELAY
from src.oddspedia.scraping.driver import wait_for_cloudflare
from src.oddspedia.scraping.logging import get_logger
from src.oddspedia.scraping.metrics import get_metrics
from src.oddspedia.scraping.models import validate_match_result, validate_match_links

logger = get_logger(__name__)


class DataValidationError(ValueError):
    """Raised when a recognised scraper payload does not satisfy its schema."""


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
                                logger.info("cloudflare_retry_reconnected", url=url, attempt=attempt)
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


def save_json(data, path):
    """Write *data* as pretty-printed JSON to *path* atomically via write-then-replace."""
    metrics = get_metrics()
    validated = None
    if isinstance(data, list) and data and "id" in data[0] and "odds" in data[0]:
        try:
            validated = [validate_match_result(item).model_dump(exclude_unset=True) for item in data]
            logger.debug("validated_match_results", count=len(data))
        except Exception as e:
            logger.warning("validation_failed", error=str(e), record_type="match_result")
            metrics.record_validation_failure()
            raise DataValidationError("match_result validation failed") from e
    elif isinstance(data, list) and data and any(key in data[0] for key in ("url", "full_url")):
        try:
            validated = [validate_match_links(item).model_dump() for item in data]
            logger.debug("validated_match_links", count=len(data))
        except Exception as e:
            logger.warning("validation_failed", error=str(e), record_type="match_link_list")
            metrics.record_validation_failure()
            raise DataValidationError("match_link_list validation failed") from e
    elif isinstance(data, dict):
        if "odds" in data or "live_odds" in data:
            try:
                validated = validate_match_result(data).model_dump(exclude_unset=True)
                logger.debug("validated_match_result")
            except Exception as e:
                logger.warning("validation_failed", error=str(e), record_type="match_result")
                metrics.record_validation_failure()
                raise DataValidationError("match_result validation failed") from e
        elif "url" in data or "full_url" in data:
            try:
                validated = validate_match_links(data).model_dump()
                logger.debug("validated_match_link")
            except Exception as e:
                logger.warning("validation_failed", error=str(e), record_type="match_link")
                metrics.record_validation_failure()
                raise DataValidationError("match_link validation failed") from e

    output_data = validated if validated is not None else data
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
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def now_iso():
    """Return current UTC time as ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


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
        resp = driver.execute_cdp_cmd(
            "Network.getResponseBody", {"requestId": request_id}
        )
        body = resp.get("body", "")
        return json.loads(body)
    except Exception:
        return None
