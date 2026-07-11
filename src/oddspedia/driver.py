import os
import plistlib
import platform
import shutil
import subprocess
import time
import urllib.request
import zipfile
from typing import Optional
from urllib.error import HTTPError, URLError

import undetected_chromedriver as uc
from selenium import webdriver
from selenium.common.exceptions import WebDriverException
from selenium.webdriver.chrome.options import Options as SeleniumChromeOptions

from src.oddspedia.config import PAGE_LOAD_TIMEOUT, CLOUDFLARE_WAIT
from src.oddspedia.logging import get_logger

logger = get_logger(__name__)

_RECONNECT_DELAY = 3
_CHROME_PLIST = "/Applications/Google Chrome.app/Contents/Info.plist"
_CFT_KNOWN_GOOD_URL = "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"


def detect_chrome_version() -> Optional[int]:
    """Return the major Chrome version (e.g. 148) or None if detection fails."""
    try:
        with open(_CHROME_PLIST, "rb") as f:
            info = plistlib.load(f)
    except Exception:
        pass
    else:
        version = info.get("KSVersion") or info.get("CFBundleShortVersionString", "")
        if version:
            try:
                return int(version.split(".")[0])
            except (ValueError, IndexError):
                pass
    try:
        import subprocess
        result = subprocess.run(
            ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "--version"],
            capture_output=True, text=True, timeout=10,
        )
        parts = result.stdout.strip().split()
        if parts:
            return int(parts[-1].split(".")[0])
    except Exception:
        pass
    logger.warning("chrome_version_detection_failed")
    return None


def get_driver(headless=False, block_images=True, block_media=True, user_data_dir=None):
    """Create an undetected Chrome driver that bypasses Cloudflare.

    Args:
        headless:       Run Chrome without a visible window.
        block_images:   Disable image loading via the Blink renderer flag.
        block_media:    Block fonts, CSS, and video files at the network layer
                        using CDP. Further reduces bandwidth and load time.
        user_data_dir:  Optional Chrome user data directory path. Use separate
                        dirs per worker to avoid session/profile conflicts
                        in concurrent scraping.
    """
    options = uc.ChromeOptions()
    # Oddspedia continues loading non-essential third-party resources long
    # after its DOM and Cloudflare challenge are usable. Waiting for "normal"
    # page completion needlessly burns the full Selenium timeout.
    options.page_load_strategy = "eager"
    if user_data_dir:
        options.add_argument(f"--user-data-dir={user_data_dir}")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--no-first-run")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-plugins-discovery")

    if block_images:
        options.add_argument("--blink-settings=imagesEnabled=false")
        logger.info("images_blocked", blink_setting="imagesEnabled=false")

    if headless:
        options.add_argument("--headless=new")
        options.add_argument("--disable-gpu")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-software-rasterizer")
        options.add_argument("--mute-audio")

    chrome_ver = detect_chrome_version()
    logger.info("creating_chrome_driver", version_main=chrome_ver)
    driver_path = os.getenv("ODDSPEDIA_CHROMEDRIVER_PATH")
    if not driver_path and chrome_ver:
        driver_path = _cached_chromedriver_path(chrome_ver)
        if driver_path:
            logger.info("chromedriver_cache_selected", path=driver_path)
    try:
        driver = uc.Chrome(options=options, version_main=chrome_ver, driver_executable_path=driver_path)
    except (HTTPError, URLError) as exc:
        if isinstance(exc, HTTPError) and exc.code != 403:
            raise
        logger.warning("chromedriver_download_failed", version_main=chrome_ver, error=str(exc))
        driver = _fallback_driver(headless, block_images, user_data_dir, chrome_ver)

    driver.set_page_load_timeout(PAGE_LOAD_TIMEOUT)
    driver.implicitly_wait(10)

    if block_media:
        driver.execute_cdp_cmd("Network.enable", {})
        driver.execute_cdp_cmd("Network.setBlockedURLs", {
            "urls": [
                "*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.svg", "*.ico",
                "*.css", "*.less", "*.scss",
                "*.woff", "*.woff2", "*.ttf", "*.otf", "*.eot",
                "*.mp4", "*.webm", "*.ogg", "*.mp3", "*.wav",
                "*google-analytics*", "*googletagmanager*",
                "*hotjar*", "*facebook*", "*doubleclick*",
                "*cdn.segment.io*", "*sentry.io*", "*newrelic*",
            ]
        })
        logger.info("cdp_blocking_enabled", blocked_types=["fonts", "css", "media", "trackers"])

    logger.info(
        "driver_initialized",
        headless=headless,
        block_images=block_images,
        block_media=block_media,
    )
    return driver


def _fallback_driver(headless: bool, block_images: bool, user_data_dir: Optional[str], chrome_ver: Optional[int]):
    """Create a driver after undetected_chromedriver's own download is blocked."""
    if chrome_ver:
        try:
            fallback_driver_path = _ensure_chrome_for_testing_driver(chrome_ver)
            options = uc.ChromeOptions()
            _apply_common_chrome_options(options, headless, block_images, user_data_dir)
            try:
                return uc.Chrome(
                    options=options,
                    version_main=chrome_ver,
                    driver_executable_path=fallback_driver_path,
                )
            except WebDriverException as driver_exc:
                logger.warning(
                    "chromedriver_cft_start_failed_retrying_after_sign",
                    path=fallback_driver_path,
                    error=str(driver_exc),
                )
                _prepare_chromedriver_binary(fallback_driver_path)
                options = uc.ChromeOptions()
                _apply_common_chrome_options(options, headless, block_images, user_data_dir)
                return uc.Chrome(
                    options=options,
                    version_main=chrome_ver,
                    driver_executable_path=fallback_driver_path,
                )
        except Exception as exc:
            logger.warning("chromedriver_cft_fallback_failed", error=str(exc), fallback="selenium_manager")

    options = SeleniumChromeOptions()
    _apply_common_chrome_options(options, headless, block_images, user_data_dir)
    logger.info("creating_chrome_driver", driver_type="selenium_manager")
    return webdriver.Chrome(options=options)


def _apply_common_chrome_options(options, headless: bool, block_images: bool, user_data_dir: Optional[str]) -> None:
    options.page_load_strategy = "eager"
    if user_data_dir:
        options.add_argument(f"--user-data-dir={user_data_dir}")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--no-first-run")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-plugins-discovery")

    if block_images:
        options.add_argument("--blink-settings=imagesEnabled=false")

    if headless:
        options.add_argument("--headless=new")
        options.add_argument("--disable-gpu")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-software-rasterizer")
        options.add_argument("--mute-audio")


def _ensure_chrome_for_testing_driver(version_main: int) -> str:
    """Download/cache the newest Chrome-for-Testing driver for a Chrome major."""
    platform_name = _chrome_for_testing_platform()
    cache_dir = os.path.join(
        os.path.expanduser("~"),
        ".cache",
        "src.oddspedia",
        "chromedriver",
        str(version_main),
        platform_name,
    )
    driver_path = os.path.join(cache_dir, "chromedriver")
    if os.path.exists(driver_path):
        logger.info("chromedriver_fallback_cache_hit", path=driver_path)
        _prepare_chromedriver_binary(driver_path)
        return driver_path

    os.makedirs(cache_dir, exist_ok=True)
    driver_url, driver_version = _latest_driver_download(version_main, platform_name)
    zip_path = os.path.join(cache_dir, "chromedriver.zip")
    extract_dir = os.path.join(cache_dir, "extract")
    logger.info(
        "chromedriver_fallback_download_start",
        version_main=version_main,
        driver_version=driver_version,
        platform=platform_name,
        url=driver_url,
    )
    try:
        urllib.request.urlretrieve(driver_url, zip_path)
        if os.path.isdir(extract_dir):
            shutil.rmtree(extract_dir)
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)
        extracted = os.path.join(extract_dir, f"chromedriver-{platform_name}", "chromedriver")
        shutil.move(extracted, driver_path)
        _prepare_chromedriver_binary(driver_path)
    finally:
        try:
            os.remove(zip_path)
        except OSError:
            pass
        shutil.rmtree(extract_dir, ignore_errors=True)

    logger.info("chromedriver_fallback_downloaded", path=driver_path)
    return driver_path


def _cached_chromedriver_path(version_main: int) -> Optional[str]:
    """Return the existing per-version fallback without making a request."""
    path = os.path.join(
        os.path.expanduser("~"),
        ".cache",
        "src.oddspedia",
        "chromedriver",
        str(version_main),
        _chrome_for_testing_platform(),
        "chromedriver",
    )
    if not os.path.isfile(path):
        return None
    _prepare_chromedriver_binary(path)
    return path


def _prepare_chromedriver_binary(driver_path: str) -> None:
    os.chmod(driver_path, 0o755)
    if platform.system() != "Darwin":
        return
    try:
        subprocess.run(["xattr", "-dr", "com.apple.quarantine", driver_path], check=False, timeout=10)
    except Exception:
        pass
    try:
        subprocess.run(["codesign", "--force", "--deep", "--sign", "-", driver_path], check=False, timeout=20)
    except Exception as exc:
        logger.warning("chromedriver_codesign_failed", path=driver_path, error=str(exc))


def _latest_driver_download(version_main: int, platform_name: str) -> tuple[str, str]:
    with urllib.request.urlopen(_CFT_KNOWN_GOOD_URL, timeout=30) as response:
        import json

        data = json.load(response)

    matches = []
    for version_info in data.get("versions", []):
        version = version_info.get("version", "")
        if not version.startswith(f"{version_main}."):
            continue
        downloads = version_info.get("downloads", {}).get("chromedriver", [])
        for item in downloads:
            if item.get("platform") == platform_name and item.get("url"):
                matches.append((version, item["url"]))
                break

    if not matches:
        raise RuntimeError(f"No Chrome-for-Testing driver found for Chrome {version_main} on {platform_name}")
    return matches[-1][1], matches[-1][0]


def _chrome_for_testing_platform() -> str:
    machine = platform.machine().lower()
    if machine in {"arm64", "aarch64"}:
        return "mac-arm64"
    return "mac-x64"


def wait_for_cloudflare(driver, timeout=CLOUDFLARE_WAIT):
    """Block until the Cloudflare 'Just a moment...' challenge resolves."""
    logger.info("cloudflare_wait_start", timeout_s=timeout)
    deadline = time.time() + timeout

    while time.time() < deadline:
        title = driver.title.lower()
        if "just a moment" in title or "attention required" in title:
            time.sleep(1)
            continue
        logger.info("cloudflare_passed", page_title=driver.title)
        return True

    logger.warning("cloudflare_timeout", timeout_s=timeout)
    return False


class DriverManager:
    """Transparent proxy around a Chrome driver with auto-reconnect.

    Pass a ``DriverManager`` instance anywhere a raw Selenium driver is
    expected — all attribute lookups are forwarded to the underlying driver via
    ``__getattr__``.  Call ``reconnect()`` (or rely on ``safe_get`` to call it
    automatically) to tear down the dead session and start a fresh one.
    """

    def __init__(self, headless: bool = False, block_images: bool = True, block_media: bool = True, user_data_dir: Optional[str] = None):
        self._headless = headless
        self._block_images = block_images
        self._block_media = block_media
        self._user_data_dir = user_data_dir
        self._driver = get_driver(headless, block_images, block_media, user_data_dir)

    def __getattr__(self, name: str):
        return getattr(self._driver, name)

    def is_alive(self) -> bool:
        try:
            _ = self._driver.current_url
            return True
        except Exception:
            return False

    def reconnect(self) -> None:
        logger.info(
            "driver_reconnect_start",
            headless=self._headless,
            block_images=self._block_images,
            block_media=self._block_media,
        )
        try:
            self._driver.quit()
        except Exception:
            pass
        time.sleep(_RECONNECT_DELAY)
        self._driver = get_driver(self._headless, self._block_images, self._block_media, self._user_data_dir)
        logger.info("driver_reconnected")

    def quit(self) -> None:
        if self._driver is not None:
            try:
                self._driver.quit()
            except Exception:
                pass
            self._driver = None
