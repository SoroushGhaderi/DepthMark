"""Match detail extraction – visit each match page and extract all data.

Extracts from each match page:
  - Event metadata (players, tournament, round, rankings, date)
  - Match result (winner, sets, set-by-set scores)
  - Odds from all bookmakers (Match Winner, Totals, Handicap, etc.)
  - Match statistics (aces, double faults, serve percentages, etc.)
"""

import json
import re
import time
import unicodedata
from urllib.parse import urlparse

from selenium.common.exceptions import StaleElementReferenceException, WebDriverException
from selenium.webdriver.common.by import By

from src.oddspedia.scraping.config import (
    FOOTBALL_ODDS_MAX_ATTEMPTS,
    base_url,
    get_settings,
    normalize_sport,
)
from src.oddspedia.scraping.logging import get_logger
from src.oddspedia.scraping.metrics import get_metrics
from src.oddspedia.scraping.odds_contract import (
    FOOTBALL_DEFAULT_LINE_LABEL,
    FootballOddsCoverageError,
    FootballOddsRetryableError,
    FootballOddsUnavailableError,
    apply_football_selector_context,
    build_odds,
    football_filter_markets,
    football_market_names_match,
    football_missing_market_names,
    football_odds_coverage_error,
    football_selector_rendered,
    has_football_market,
    is_football_market_selector_text,
    merge_odds_markets,
    normalize_football_odds,
    validate_european_handicap_coverage,
)
from src.oddspedia.scraping.utils import (
    _is_detail_url,
    _is_error_page,
    _is_listing_page_title,
    now_iso,
    pin_oddspedia_event_url,
    safe_get,
)

logger = get_logger(__name__)

OPTIONAL_CONTROL_WAIT_SECONDS = 2.0
OPTIONAL_CONTROL_POLL_SECONDS = 0.1


class FootballScoreUnavailableError(RuntimeError):
    """Raised when a completed football event has no final score."""


class MatchPageNotRenderedError(RuntimeError):
    """Raised when a detail URL renders the listing shell instead of an event."""


class MatchIdentityMismatchError(RuntimeError):
    """Raised when a matchup URL renders a different event than the listing."""


_ODDS_NOT_YET_AVAILABLE_MESSAGE = "odds are not yet available from bookies"


# ── Helpers ───────────────────────────────────────────────────────────────────


def _scroll_page(driver, pause=None, max_scrolls=10):
    """Scroll incrementally to trigger lazy-loaded content."""
    if pause is None:
        pause = get_settings().scroll_pause
    last_h = driver.execute_script("return document.body.scrollHeight")
    for _ in range(max_scrolls):
        driver.execute_script("window.scrollBy(0, 600);")
        time.sleep(pause)
        new_h = driver.execute_script("return document.body.scrollHeight")
        if new_h == last_h:
            break
        last_h = new_h
    driver.execute_script("window.scrollTo(0, 0);")
    time.sleep(0.5)


def _is_finished_football_status(value):
    """Return whether *value* is a terminal, score-bearing football status."""
    return str(value or "").strip().lower() in {"finished", "ft", "aet", "ot", "pen"}


def _oddspedia_slug(value):
    """Build the lowercase slug format used by Oddspedia match paths."""
    value = unicodedata.normalize("NFKD", str(value or ""))
    value = value.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"^-+|-+$", "", re.sub(r"[^a-z0-9]+", "-", value.lower()))


def _identity_key(value):
    """Return a conservative comparison key for source-rendered team names."""
    value = unicodedata.normalize("NFKD", str(value or ""))
    value = value.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _team_names_equivalent(left, right):
    left_key = _identity_key(left)
    right_key = _identity_key(right)
    return bool(left_key and right_key and left_key == right_key)


def _same_team_pair(match_info, meta):
    """Return whether the rendered page contains the same two teams."""
    expected_home = match_info.get("home", "")
    expected_away = match_info.get("away", "")
    rendered_home = meta.get("home", "")
    rendered_away = meta.get("away", "")
    if not all((expected_home, expected_away, rendered_home, rendered_away)):
        return False
    return (
        _team_names_equivalent(expected_home, rendered_home)
        and _team_names_equivalent(expected_away, rendered_away)
    ) or (
        _team_names_equivalent(expected_home, rendered_away)
        and _team_names_equivalent(expected_away, rendered_home)
    )


def _match_date_key(value):
    match = re.match(r"\s*(\d{4})-(\d{2})-(\d{2})", str(value or ""))
    return "" if not match else "".join(match.groups())


def _event_identity_mismatch_reasons(match_info, meta):
    """Return strong evidence that page metadata belongs to another event."""
    reasons = []
    expected_id = str(match_info.get("id") or "").strip()
    rendered_id = str(meta.get("event_id") or "").strip()
    if expected_id and rendered_id and expected_id != rendered_id:
        reasons.append(f"event_id expected={expected_id} rendered={rendered_id}")

    expected_date = _match_date_key(match_info.get("date"))
    rendered_date = _match_date_key(meta.get("date"))
    if expected_date and rendered_date and expected_date != rendered_date:
        reasons.append(f"date expected={expected_date} rendered={rendered_date}")

    expected_home = match_info.get("home", "")
    expected_away = match_info.get("away", "")
    rendered_home = meta.get("home", "")
    rendered_away = meta.get("away", "")
    if all((expected_home, expected_away, rendered_home, rendered_away)):
        same_order = _team_names_equivalent(
            expected_home, rendered_home
        ) and _team_names_equivalent(expected_away, rendered_away)
        reversed_order = _team_names_equivalent(
            expected_home, rendered_away
        ) and _team_names_equivalent(expected_away, rendered_home)
        if reversed_order:
            reasons.append("home and away teams are reversed")
        elif not same_order and not (expected_id and rendered_id and expected_id == rendered_id):
            reasons.append(
                "teams differ "
                f"expected={expected_home} vs {expected_away} "
                f"rendered={rendered_home} vs {rendered_away}"
            )
    return reasons


def _archived_match_url(url, match_info, sport="football"):
    """Return Oddspedia's canonical archived URL for a finished match.

    Some listing records contain a stale plain ``/{sport}/...`` URL.  For
    completed events Oddspedia's archived route is ``/a/{sport}/`` and uses
    away-home slug order.  Return ``None`` when the source record cannot
    provide enough information to construct that route.
    """
    if sport != "football" or not _is_finished_football_status(match_info.get("status")):
        return None

    path = urlparse(url).path.strip("/")
    parts = path.split("/")
    if len(parts) >= 3 and parts[-3] == "a" and parts[-2] == sport:
        return None
    if len(parts) < 2 or parts[-2] != sport:
        return None

    match_key = str(match_info.get("matchKey") or parts[-1] or "")
    match_id_match = re.search(r"-(\d+)$", match_key)
    if not match_id_match:
        match_id_match = re.search(r"-(\d+)$", parts[-1])
    if not match_id_match:
        return None

    # Do not derive these from display names: Oddspedia can reuse a numeric
    # event ID across seasons, and names such as "Algeciras" may need a
    # source-specific suffix such as ``-cf`` in the canonical URL.
    home_slug = _oddspedia_slug(match_info.get("home_slug") or match_info.get("homeSlug"))
    away_slug = _oddspedia_slug(match_info.get("away_slug") or match_info.get("awaySlug"))
    if not home_slug or not away_slug:
        return None

    match_url_id = match_id_match.group(1)
    return f"{base_url()}/a/{sport}/{away_slug}-{home_slug}-{match_url_id}"


def _listing_shell_is_current(driver, sport="football"):
    """Return whether the browser is currently showing the sport listing shell."""
    try:
        title = driver.title or ""
        current_path = urlparse(driver.current_url or "").path.rstrip("/")
    except WebDriverException:
        return False
    return _is_listing_page_title(title) or current_path == f"/{sport}"


def _football_odds_not_yet_available(driver):
    """Return whether Oddspedia explicitly says that bookie odds are pending.

    This is a valid detail-page response, not a scraper failure. Keep the
    check scoped to Oddspedia's no-results component and its current message so
    an unrelated empty section cannot suppress the normal market coverage
    checks.
    """
    try:
        detected = driver.execute_script(
            """
            var expected = arguments[0];
            var notices = document.querySelectorAll('.no-results-found');
            for (var i = 0; i < notices.length; i++) {
                var text = (notices[i].textContent || '').replace(/\\s+/g, ' ').trim().toLowerCase();
                if (text.indexOf(expected) >= 0) return true;
            }
            return false;
            """,
            _ODDS_NOT_YET_AVAILABLE_MESSAGE,
        )
        return detected is True
    except WebDriverException as exc:
        logger.debug("football_odds_availability_check_failed", error=str(exc))
        return False


def _wait_for_event_metadata(driver, max_attempts=15, poll_interval=0.2, sport="football"):
    """Return event metadata as soon as the page state exposes it.

    This replaces a fixed post-navigation sleep: ready pages proceed
    immediately, while slow pages get a bounded wait before extraction.
    """
    last_meta = {}
    for attempt in range(max_attempts):
        try:
            meta = driver.execute_script(_JS_EVENT_META) or {}
        except WebDriverException:
            meta = {}
        if isinstance(meta, dict):
            last_meta = meta
        if isinstance(meta, dict) and any(
            meta.get(field) for field in ("home", "away", "date", "status")
        ):
            # Final football scores are occasionally populated after the rest
            # of Vuex event metadata. Do not snapshot a known-final event
            # before either the direct score or a period-score payload exists.
            score_ready = (
                meta.get("home_score", "") != "" and meta.get("away_score", "") != ""
            ) or _parse_football_score_payload(meta.get("score_payload") or meta.get("raw_status"))
            if (
                sport != "football"
                or not _is_finished_football_status(meta.get("status"))
                or score_ready
            ):
                return meta
        if attempt < max_attempts - 1:
            time.sleep(poll_interval)
    logger.warning("event_metadata_score_not_ready", attempts=max_attempts, sport=sport)
    return last_meta


def _click_tab(driver, name):
    """Click a named tab (e.g. 'Statistics') and wait for it to render.

    Returns True if a matching tab was found and clicked.
    """
    clicked = driver.execute_script(
        """
        var target = arguments[0].toLowerCase();
        var els = document.querySelectorAll(
            '[role="tab"], .tab, [class*="tab-item"], [class*="nav-item"], button, a'
        );
        for (var i = 0; i < els.length; i++) {
            if (els[i].textContent.trim().toLowerCase() === target) {
                els[i].click();
                return true;
            }
        }
        return false;
    """,
        name,
    )
    if clicked:
        time.sleep(1.5)
    return bool(clicked)


def _click_btn_group_item(driver, label):
    """Click a .btn-group-item button whose text matches *label* (case-insensitive).

    These buttons appear on match pages (e.g. "Live Odds", "Pre-match Odds").
    Returns True if the button was found and clicked.
    """
    clicked = driver.execute_script(
        """
        var target = arguments[0].toLowerCase();
        var btns = document.querySelectorAll('.btn-group-item');
        for (var i = 0; i < btns.length; i++) {
            if (btns[i].textContent.trim().toLowerCase() === target) {
                btns[i].click();
                return true;
            }
        }
        return false;
    """,
        label,
    )
    if clicked:
        time.sleep(2)
    return bool(clicked)


def _find_optional_elements(
    driver,
    by,
    value,
    timeout=OPTIONAL_CONTROL_WAIT_SECONDS,
    poll_interval=OPTIONAL_CONTROL_POLL_SECONDS,
):
    """Poll for optional controls without imposing a global implicit wait.

    The caller needs to distinguish "not rendered yet" from "not present" for
    lazy-loaded controls. This keeps that behavior local and bounded while
    returning immediately when the controls are already present.
    """
    deadline = time.monotonic() + timeout
    while True:
        elements = driver.find_elements(by, value)
        if elements:
            return elements
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return []
        time.sleep(min(poll_interval, remaining))


def _click_show_more_with_selenium(driver, max_rounds=8):
    """Use trusted Selenium clicks for Oddspedia Show more pagination controls."""
    total = 0
    xpath = (
        "//*["
        "contains(concat(' ', normalize-space(@class), ' '), ' btn-pagination__label ')"
        " or self::button or self::a or @role='button'"
        "]"
        "[ancestor::*[@data-module-name='Odds Comparison']]"
        "[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'show more')"
        " or contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'show all')"
        " or contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'view all')]"
    )

    for _ in range(max_rounds):
        clicked_this_round = 0
        try:
            page_height = (
                driver.execute_script(
                    "return Math.max(document.body.scrollHeight || 0, document.documentElement.scrollHeight || 0);"
                )
                or 0
            )
            viewport = driver.execute_script("return window.innerHeight || 900;") or 900
        except WebDriverException:
            break

        positions = list(range(0, int(page_height) + int(viewport), max(350, int(viewport * 0.65))))
        positions.append(int(page_height))

        for y in positions:
            try:
                driver.execute_script("window.scrollTo(0, arguments[0]);", y)
                time.sleep(0.15)
                elements = _find_optional_elements(driver, By.XPATH, xpath)
            except WebDriverException:
                continue

            for element in elements:
                try:
                    if not element.is_displayed():
                        continue
                    clickable = driver.execute_script(
                        """
                        var el = arguments[0];
                        if (!el) return null;
                        return el.closest('button, a, [role="button"], .btn-pagination') || el;
                    """,
                        element,
                    )
                    if not clickable:
                        continue
                    driver.execute_script(
                        "arguments[0].scrollIntoView({block: 'center'});", clickable
                    )
                    time.sleep(0.2)
                    clickable.click()
                    clicked_this_round += 1
                    total += 1
                    time.sleep(0.8)
                    break
                except (WebDriverException, StaleElementReferenceException):
                    continue
            if clicked_this_round:
                break

        if not clicked_this_round:
            break

    driver.execute_script("window.scrollTo(0, 0);")
    if total:
        logger.info("show_more_selenium_clicked", count=total)
    return total


def _expand_all_odds_lines(driver):
    """Click every 'Show all lines' / 'Show more' button visible on the page.

    Each market card shows only 3–4 lines by default.  These expand buttons
    reveal all remaining alternative lines.  We must click them before running
    the odds extractor so every line is present in the DOM.

    Returns the number of buttons that were clicked.
    """
    total = _click_show_more_with_selenium(driver)
    last_state = None
    stable_passes = 0
    for _ in range(12):
        state = driver.execute_script(
            """
        // Keywords that identify an expand/show-all button (lowercase, partial match).
        var KEYWORDS = [
            'show all lines', 'show all', 'all lines',
            'more lines', 'show more', 'view all'
        ];

        function isVisible(el) {
            if (!el) return false;
            var rect = el.getBoundingClientRect();
            var style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 &&
                   style.visibility !== 'hidden' && style.display !== 'none';
        }

        function clickEl(el) {
            try {
                el.scrollIntoView({block: 'center'});
                ['mouseover', 'mousedown', 'mouseup', 'click'].forEach(function(type) {
                    el.dispatchEvent(new MouseEvent(type, {
                        bubbles: true,
                        cancelable: true,
                        view: window
                    }));
                });
                return true;
            } catch (e) {
                try { el.click(); return true; } catch (ex) {}
            }
            return false;
        }

        function findClickable(el) {
            if (!el) return null;
            var direct = el.closest('button, a, [role="button"]');
            if (direct) return direct;

            var node = el;
            for (var depth = 0; depth < 6 && node; depth++) {
                if (node.classList) {
                    var cls = Array.from(node.classList).join(' ');
                    if (/\\bbtn-pagination\\b/.test(cls) || /(^|\\s)pagination(\\s|$)/.test(cls)) {
                        return node;
                    }
                }
                node = node.parentElement;
            }
            return el;
        }

        var oddsRoot = document.querySelector('[data-module-name="Odds Comparison"]');
        if (!oddsRoot) return {clicked: 0, height: 0, marketCards: 0, lineRows: 0};

        var pageHeight = Math.max(
            document.body.scrollHeight || 0,
            document.documentElement.scrollHeight || 0
        );
        var viewport = window.innerHeight || 900;
        var positions = [];
        for (var y = 0; y <= pageHeight + viewport; y += Math.max(350, Math.floor(viewport * 0.65))) {
            positions.push(y);
        }
        positions.push(pageHeight);

        var clicked = 0;
        var seen = new Set();
        for (var p = 0; p < positions.length; p++) {
            window.scrollTo(0, positions[p]);
            var candidates = oddsRoot.querySelectorAll(
                'button, a, [role="button"], .btn-pagination__label, '
                + '[class*="show-all"], [class*="show_all"], '
                + '[class*="expand"], [class*="more-lines"], [class*="all-lines"], '
                + '[class*="pagination"]'
            );

            for (var i = 0; i < candidates.length; i++) {
                var txt = candidates[i].textContent.trim().toLowerCase();
                if (!txt) continue;
                for (var k = 0; k < KEYWORDS.length; k++) {
                    if (txt === KEYWORDS[k] || txt.indexOf(KEYWORDS[k]) >= 0) {
                        var el = candidates[i];
                        var clickable = findClickable(el);
                        if (!isVisible(clickable)) break;
                        var key = txt + '|' + Math.round(clickable.getBoundingClientRect().top + window.scrollY);
                        if (seen.has(key)) break;
                        seen.add(key);
                        if (clickEl(clickable)) clicked++;
                        break;
                    }
                }
            }
        }

        var marketCards = oddsRoot.querySelectorAll('.matchup-odds-comparison-card').length;
        var lineRows = oddsRoot.querySelectorAll('.flex-grow-1.flex.align-items-center.justify-content-between').length;
        return {
            clicked: clicked,
            height: Math.max(document.body.scrollHeight || 0, document.documentElement.scrollHeight || 0),
            marketCards: marketCards,
            lineRows: lineRows
        };
        """
        )
        clicked = int((state or {}).get("clicked") or 0)
        total += clicked
        state_key = (
            (state or {}).get("height"),
            (state or {}).get("marketCards"),
            (state or {}).get("lineRows"),
        )
        if clicked == 0 and state_key == last_state:
            stable_passes += 1
        else:
            stable_passes = 0
        last_state = state_key
        if stable_passes >= 2:
            break
        time.sleep(1.2)
    driver.execute_script("window.scrollTo(0, 0);")
    logger.info("odds_buttons_expanded", count=total)
    return total


_JS_FOOTBALL_COLLAPSED_MARKET_TITLES = """
    return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))
        .map(function(card) {
            var header = card.querySelector('.matchup-odds-comparison-card__header');
            var title = header ? header.textContent.replace(/\\s+/g, ' ').trim() : '';
            var hasOdds = !!card.querySelector('.odd-box-with-label, .odd-box-with-logo');
            return title && !hasOdds ? title : '';
        })
        .filter(Boolean);
"""


_JS_FOOTBALL_MARKET_INVENTORY = """
    var root = document.querySelector('[data-module-name="Odds Comparison"]') || document;
    var cards = Array.from(root.querySelectorAll('.matchup-odds-comparison-card'));
    var names = cards.map(function(card) {
        var header = card.querySelector(
            '.matchup-odds-comparison-card__header, [class*="market-header"], '
            + '[class*="market-name"], [class*="title"], h2, h3, h4'
        );
        return header ? header.textContent.replace(/\\s+/g, ' ').trim() : '';
    }).filter(Boolean);
    return {total_markets: cards.length, market_names: names};
"""


def _football_market_inventory(driver):
    """Return the market-card inventory exposed after page expansion.

    The card count is the source-side denominator for odds coverage. It is
    intentionally collected separately from the extracted odds count because
    Oddspedia can render the market inventory before the individual card odds
    finish loading.
    """
    try:
        inventory = driver.execute_script(_JS_FOOTBALL_MARKET_INVENTORY) or {}
    except WebDriverException as exc:
        logger.warning("football_market_inventory_failed", error=str(exc))
        return {"total_markets": None, "market_names": []}

    if not isinstance(inventory, dict):
        logger.warning(
            "football_market_inventory_invalid",
            value_type=type(inventory).__name__,
        )
        return {"total_markets": None, "market_names": []}

    names = []
    for value in inventory.get("market_names") or []:
        name = re.sub(r"\\s+", " ", str(value or "")).strip()
        if name and name not in names:
            names.append(name)

    try:
        total_markets = int(inventory.get("total_markets"))
    except (TypeError, ValueError):
        total_markets = None
    if total_markets is not None and total_markets <= 0:
        total_markets = None
    if total_markets is not None and len(names) > total_markets:
        total_markets = len(names)

    return {"total_markets": total_markets, "market_names": names}


def _expand_football_market_list(driver, timeout=10.0, max_rounds=8):
    """Reveal every collapsed full-time market card exposed by the market list."""
    total_added = 0
    for _ in range(max_rounds):
        state = (
            driver.execute_script(
                """
        var root = document.querySelector('[data-module-name="Odds Comparison"]');
        if (!root) return {button: null, cards: 0};
        var button = Array.from(root.querySelectorAll(
            'button, a, [role="button"], .btn-pagination, .btn-pagination__label, '
            + '[class*="pagination"], [class*="show-more"], [class*="show_more"]'
        )).map(function(candidate) {
            return candidate.closest('button, a, [role="button"], .btn-pagination') || candidate;
        }).find(function(candidate) {
            var text = (candidate.textContent || '').replace(/\\s+/g, ' ').trim().toLowerCase();
            var expandsMarketList = /^(?:show more(?: markets)?|show all(?: markets)?|view all(?: markets)?)$/.test(text);
            return expandsMarketList && !candidate.closest('.matchup-odds-comparison-card');
        }) || null;
        return {button: button, cards: root.querySelectorAll('.matchup-odds-comparison-card').length};
    """
            )
            or {}
        )
        if not isinstance(state, dict):
            logger.warning("football_market_list_state_invalid", value_type=type(state).__name__)
            break
        button = state.get("button")
        before = int(state.get("cards") or 0)
        if not button:
            if not total_added:
                logger.info("football_market_list_already_expanded", cards=before)
            break

        try:
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
            button.click()
        except (WebDriverException, StaleElementReferenceException) as exc:
            logger.warning("football_market_list_expand_failed", error=str(exc))
            break

        deadline = time.monotonic() + timeout
        current = before
        while time.monotonic() < deadline:
            current = int(
                driver.execute_script(
                    """
            var root = document.querySelector('[data-module-name="Odds Comparison"]');
            return root ? root.querySelectorAll('.matchup-odds-comparison-card').length : 0;
        """
                )
                or 0
            )
            if current > before:
                break
            time.sleep(0.1)
        added = max(0, current - before)
        total_added += added
        logger.info("football_market_list_expanded", before=before, after=current, added=added)
        # A control which remains visible without adding another card is stale;
        # do not repeatedly click it for the full retry budget.
        if not added:
            break
    return total_added


def _click_football_market_card(driver, market_title):
    """Return whether a collapsed football market card was expanded."""
    header = driver.execute_script(
        """
        var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
        var cards = Array.from(document.querySelectorAll('.matchup-odds-comparison-card'));
        for (var i = 0; i < cards.length; i++) {
            var card = cards[i];
            var button = card.querySelector('.matchup-odds-comparison-card__header');
            var title = button ? button.textContent.replace(/\\s+/g, ' ').trim().toLowerCase() : '';
            if (title === target) return button;
        }
        return null;
    """,
        market_title,
    )
    if not header:
        return False
    try:
        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", header)
        header.click()
        return True
    except (WebDriverException, StaleElementReferenceException):
        return False


def _wait_for_football_market_card(driver, market_title, timeout=10.0):
    """Wait until an expanded market card has rendered its odds controls."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            state = (
                driver.execute_script(
                    """
                var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
                var cards = Array.from(document.querySelectorAll('.matchup-odds-comparison-card'));
                for (var i = 0; i < cards.length; i++) {
                    var card = cards[i];
                    var header = card.querySelector('.matchup-odds-comparison-card__header');
                    var title = header ? header.textContent.replace(/\\s+/g, ' ').trim().toLowerCase() : '';
                    if (title !== target) continue;
                    return {
                        found: true,
                        loading: !!card.querySelector('.loader'),
                        hasOdds: !!card.querySelector('.odd-box-with-label, .odd-box-with-logo')
                    };
                }
                return {found: false, loading: false, hasOdds: false};
            """,
                    market_title,
                )
                or {}
            )
            if state.get("hasOdds") and not state.get("loading"):
                return True
        except WebDriverException:
            return False
        time.sleep(0.2)
    return False


def _expand_football_market_card_lines(driver, market_title, max_rounds=12):
    """Expand every visible alternative-lines control in one rendered card.

    Oddspedia uses both ``Show all lines`` and paginated ``Show more`` controls,
    and a market can expose several batches.  The control is not consistently a
    ``button`` element, so resolve the nearest interactive ancestor instead of
    depending on one tag/class combination.
    """
    expanded = 0
    for _ in range(max_rounds):
        button = driver.execute_script(
            """
            var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
            var cards = Array.from(document.querySelectorAll('.matchup-odds-comparison-card'));
            for (var i = 0; i < cards.length; i++) {
                var card = cards[i];
                var header = card.querySelector('.matchup-odds-comparison-card__header');
                var title = header ? header.textContent.replace(/\\s+/g, ' ').trim().toLowerCase() : '';
                if (title !== target) continue;
                var candidates = Array.from(card.querySelectorAll(
                    'button, a, [role="button"], .btn-pagination, .btn-pagination__label, '
                    + '[class*="pagination"], [class*="show-more"], [class*="show_more"], '
                    + '[class*="more-lines"], [class*="all-lines"]'
                ));
                for (var c = 0; c < candidates.length; c++) {
                    var candidate = candidates[c];
                    var text = (candidate.textContent || '').replace(/\\s+/g, ' ').trim().toLowerCase();
                    if (!/^(?:show more(?: lines)?|show all(?: lines)?|more lines|view all(?: lines)?)$/.test(text)) continue;
                    var control = candidate.closest('button, a, [role="button"], .btn-pagination') || candidate;
                    var rect = control.getBoundingClientRect();
                    var style = window.getComputedStyle(control);
                    if (rect.width > 0 && rect.height > 0 && style.display !== 'none'
                        && style.visibility !== 'hidden') return control;
                }
            }
            return null;
        """,
            market_title,
        )
        if not button:
            break
        try:
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
            button.click()
            expanded += 1
            time.sleep(0.5)
        except (WebDriverException, StaleElementReferenceException):
            break
    return expanded


def _expand_football_market_cards(driver, market_names=None):
    """Expand football cards and alternative lines, optionally for named markets only."""
    try:
        titles = driver.execute_script(_JS_FOOTBALL_COLLAPSED_MARKET_TITLES) or []
    except WebDriverException as exc:
        logger.warning("football_market_card_discovery_failed", error=str(exc))
        return

    target_markets = list(
        dict.fromkeys(str(name).strip() for name in (market_names or []) if str(name).strip())
    )
    if target_markets:
        titles = [
            title
            for title in titles
            if any(football_market_names_match(title, target) for target in target_markets)
        ]

    unresolved = []
    unique_titles = list(dict.fromkeys(titles))
    for index, title in enumerate(unique_titles, 1):
        market_t0 = time.monotonic()
        logger.info(
            "football_market_card_expand_start",
            market=title,
            progress=f"{index}/{len(unique_titles)}",
        )
        if not _click_football_market_card(driver, title):
            unresolved.append(title)
            continue
        if not _wait_for_football_market_card(driver, title):
            unresolved.append(title)
            continue
        logger.info(
            "football_market_card_expanded",
            market=title,
            duration_ms=int((time.monotonic() - market_t0) * 1000),
        )

    if unresolved:
        raise FootballOddsCoverageError(
            "Collapsed football market cards did not render odds: " + ", ".join(unresolved)
        )
    try:
        all_titles = (
            driver.execute_script(
                """
            return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))
                .map(function(card) {
                    var header = card.querySelector('.matchup-odds-comparison-card__header');
                    return header ? header.textContent.replace(/\\s+/g, ' ').trim() : '';
                })
                .filter(Boolean);
        """
            )
            or []
        )
    except WebDriverException as exc:
        logger.warning("football_market_line_discovery_failed", error=str(exc))
        all_titles = []

    if target_markets:
        all_titles = [
            title
            for title in all_titles
            if any(football_market_names_match(title, target) for target in target_markets)
        ]

    expanded_lines = sum(
        _expand_football_market_card_lines(driver, title) for title in dict.fromkeys(all_titles)
    )
    if titles or all_titles:
        logger.info(
            "football_market_cards_expanded",
            count=len(all_titles),
            alternative_line_buttons=expanded_lines,
            targeted_markets=target_markets or None,
        )


# ── JavaScript extractors ─────────────────────────────────────────────────────

# Pull event metadata and score data from the Vuex 'event' store module.
_JS_EVENT_META = """
    var d = {
        home:'', away:'', date:'', league:'', round:'',
        event_id:'', home_slug:'', away_slug:'',
        home_rank:'', away_rank:'', category:'', status:'',
        winner:'', home_score:'', away_score:'', raw_status:'', score_payload:null,
        home_sets:'', away_sets:'', set_scores:null,
        result_unavailable: false
    };
    try {
        var ev = document.querySelector('#__nuxt').__vue__.$store.state['event'];
        if (ev && ev.event) {
            var e = ev.event;
            d.event_id  = (e.id !== undefined) ? String(e.id) : '';
            d.home      = e.ht || '';
            d.away      = e.at || '';
            d.home_slug = e.ht_slug || '';
            d.away_slug = e.at_slug || '';
            d.date      = e.md || '';
            d.league    = e.league_name || '';
            d.round     = e.round_name || '';
            d.home_rank = e.ht_rank || '';
            d.away_rank = e.at_rank || '';
            d.category  = e.category_slug || '';
            d.winner    = e.winner || e.result || '';
            d.home_score = (e.ht_score !== undefined) ? e.ht_score
                         : (e.hts !== undefined ? e.hts
                         : (e.home_score !== undefined ? e.home_score
                         : (e.homeScore !== undefined ? e.homeScore
                         : (e.hs !== undefined ? e.hs : ''))));
            d.away_score = (e.at_score !== undefined) ? e.at_score
                         : (e.ats !== undefined ? e.ats
                         : (e.away_score !== undefined ? e.away_score
                         : (e.awayScore !== undefined ? e.awayScore
                         : (e.as !== undefined ? e.as : ''))));
            d.raw_status = e.status || '';

            // --- Set scores ---
            // Try dedicated score fields first
            var periods = e.set_scores || e.sets || e.score_breakdown
                        || e.period_scores || e.periods || null;

            // e.status often holds the period-scores array as a JSON string
            if (!periods && e.status) {
                try {
                    var parsed = (typeof e.status === 'string')
                                    ? JSON.parse(e.status)
                                    : e.status;
                    if (Array.isArray(parsed) && parsed.length &&
                        parsed[0].period_type === 'set') {
                        periods = parsed;
                    }
                } catch(ex2) {}
            }

            if (periods && Array.isArray(periods) && periods.length) {
                d.score_payload = periods;
                d.set_scores = periods.map(function(p) {
                    var s = {home: p.home, away: p.away};
                    if (p.tiebreak) s.tiebreak = p.tiebreak;
                    return s;
                });
                d.home_sets = periods.filter(function(p) { return p.home > p.away; }).length;
                d.away_sets = periods.filter(function(p) { return p.away > p.home; }).length;
                d.status = 'finished';
            } else {
                // Fallback to per-player set-count fields
                d.home_sets = (e.hts !== undefined) ? e.hts
                            : (e.ht_score !== undefined ? e.ht_score : '');
                d.away_sets = (e.ats !== undefined) ? e.ats
                            : (e.at_score !== undefined ? e.at_score : '');

                // Map numeric status codes to readable strings
                var sc = parseInt(e.status);
                if      (!isNaN(sc) && sc >= 100) d.status = 'finished';
                else if (!isNaN(sc) && sc > 0)    d.status = 'live';
                else if (!isNaN(sc) && sc === 0)  d.status = 'upcoming';
                else                               d.status = String(e.status || '');
            }
        }
    } catch(ex) {}
    // Check DOM for post-match info status (Canceled, Walkover, Postponed, etc.)
    // This overrides the Vuex-derived status when the page shows a special result.
    try {
        var pm = document.querySelector('.matchup-header-postmatch-info');
        if (pm) {
            // Status text lives inside the .h5 heading, look there first
            var h5 = pm.querySelector('.h5, h5');
            if (h5) {
                // Look for a status-colored span inside the heading (danger/warning/success)
                var se = h5.querySelector('[class*="color-"]');
                if (se) {
                    var t = se.textContent.trim().toLowerCase();
                    if (t && t.length < 30) d.status = t;
                } else {
                    // No colored span — use the heading text itself if it looks like a status
                    var raw = h5.textContent.trim();
                    if (raw) {
                        var lc = raw.toLowerCase();
                        var statusHints = ['canceled','cancelled','postponed','walkover',
                            'walk over','abandoned','retired','suspended'];
                        for (var i = 0; i < statusHints.length; i++) {
                            if (lc.indexOf(statusHints[i]) >= 0) {
                                d.status = statusHints[i];
                                break;
                            }
                        }
                    }
                }
            }
        }
        // Check for "Result unavailable" span directly in the postmatch info
        try {
            var ru = pm.querySelector('span');
            if (ru && ru.textContent.trim().toLowerCase().indexOf('result unavailable') >= 0) {
                d.result_unavailable = true;
            }
        } catch(ex4) {}
    } catch(ex3) {}
    return d;
"""

# Extract odds from the comparison section.
#
# Page structure (per market card):
#   .matchup-odds-comparison-card
#     ├─ header/title  → market name ("MATCH WINNER", "TOTAL SETS/GAMES", …)
#     ├─ tabs          → "Full Time" | "1st Set"  (Full Time is active by default)
#     └─ tab content
#          ├─ label "MAIN LINE"
#          ├─ line-wrapper: [label "22.5 Games"] [flex-row: LEFT-btn | RIGHT-btn]
#          ├─ label "ALTERNATIVE LINES"
#          ├─ line-wrapper: [label "2.5 Sets"]   [flex-row …]
#          └─ …
#
# The flex-row class is:
#   flex-grow-1 flex align-items-center justify-content-between gap-100 md:gap-200 aside:gap-100
# Each button inside the row has text like "betsson OVER 1.89" or "betsson HOME 2.37".
_JS_EXTRACT_ODDS = """
    // ── helpers ──────────────────────────────────────────────────────────────

    // An odds button must include a direction keyword and an odds value
    // (decimal like 1.85, fractional like 6/7, or American like +105).
    function hasOddsText(text) {
        return /\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b|(?:^|\\s)[+-]\\d{2,5}\\b/.test(text);
    }
    function hasToken(text, token) {
        return new RegExp('(^|[^A-Z0-9.])' + token + '(?=$|[^A-Z0-9.])').test(text);
    }
    function isRendered(el) {
        if (!el || !el.isConnected) return false;
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 &&
               style.display !== 'none' && style.visibility !== 'hidden' &&
               style.opacity !== '0';
    }

    function isOddsButton(el) {
        var t = el.textContent.replace(/\\s+/g, ' ').trim().toUpperCase();
        var hasDir = t.indexOf('OVER')  >= 0 || t.indexOf('UNDER') >= 0 ||
                     t.indexOf('HOME')  >= 0 || t.indexOf('AWAY')  >= 0 ||
                     t.indexOf('DRAW')  >= 0 || hasToken(t, 'TIE') ||
                     t.indexOf('YES')   >= 0 ||
                     t.indexOf('NO')    >= 0 || hasToken(t, 'ODD') ||
                     hasToken(t, 'EVEN') || hasToken(t, '1X') ||
                     hasToken(t, 'X2') || hasToken(t, '12');
        var hasOdds = hasOddsText(t);
        if (!hasOdds) return false;
        if (hasDir) return true;

        // Football markets such as Draw No Bet and First Team to Score often
        // use team names as the button labels instead of HOME/AWAY tokens.
        if (el.querySelector('.odd-box-with-label__value, .odd-box-with-logo__value')) return true;
        return /odd-box/i.test(el.className || '');
    }

    function toDecimalOdds(raw) {
        if (!raw) return null;
        var s = String(raw).trim();
        if (!s) return null;

        // Fractional odds, e.g. 6/7 -> 1.857142857...
        if (/^\\d+\\s*\\/\\s*\\d+$/.test(s)) {
            var parts = s.split('/');
            var n = parseFloat(parts[0]);
            var d = parseFloat(parts[1]);
            if (!isNaN(n) && !isNaN(d) && d !== 0) return (n / d) + 1;
            return null;
        }

        // Decimal odds, e.g. 1.89
        if (/^\\d+(\\.\\d+)?$/.test(s)) {
            var dec = parseFloat(s);
            return isNaN(dec) ? null : dec;
        }

        // American odds, e.g. +105 -> 2.05, -120 -> 1.8333...
        if (/^[+-]\\d+$/.test(s)) {
            var american = parseInt(s, 10);
            if (isNaN(american) || american === 0) return null;
            return american > 0 ? (american / 100) + 1 : (100 / Math.abs(american)) + 1;
        }
        return null;
    }

    // Extract direction keyword + odds value from an odds button element.
    function parseButton(el) {
        var t = el.textContent.replace(/\\s+/g, ' ').trim().toUpperCase();
        var dir = null;
        var outcome = '';
        // Logo-backed football odds use the same semantic label/value pair as
        // regular odds boxes, but with the ``odd-box-with-logo`` prefix.
        // European Handicap commonly renders its third outcome as ``Tie`` in
        // this variant; ignoring the logo label leaves the bookmaker name in
        // the fallback outcome and the Python contract cannot map it to draw.
        var labelEl = el.querySelector(
            '.odd-box-with-label__label, .odd-box-with-logo__label'
        );
        var explicitLabel = labelEl ? labelEl.textContent.trim() : '';
        // Keep HT/FT labels such as "Draw / Home" intact rather than
        // collapsing them to a simple draw outcome below.
        var isCompositeOutcome = /[\\/→>]/.test(explicitLabel);
        if      (t.indexOf('OVER')  >= 0) dir = 'over';
        else if (t.indexOf('UNDER') >= 0) dir = 'under';
        // Check this before generic NO: it is a distinct third outcome.
        else if (t.indexOf('NO GOAL') >= 0) dir = 'no_goal';
        else if (t.indexOf('DRAW')  >= 0) dir = 'draw';
        else if (hasToken(t, 'TIE') || hasToken(t, 'X')) dir = 'draw';
        else if (t.indexOf('YES')   >= 0) dir = 'yes';
        else if (t.indexOf('NO')    >= 0) dir = 'no';
        else if (hasToken(t, 'ODD')) dir = 'odd';
        else if (hasToken(t, 'EVEN')) dir = 'even';
        else if (hasToken(t, '1X')) dir = 'home_draw';
        else if (hasToken(t, 'X2')) dir = 'draw_away';
        else if (hasToken(t, '12')) dir = 'home_away';
        else if (t.indexOf('AWAY')  >= 0) dir = 'away';
        else if (t.indexOf('HOME')  >= 0) dir = 'home';

        // Prefer explicit label/value nodes used by Oddspedia cards.
        if (!dir) {
            if (labelEl) {
                var lbl = labelEl.textContent.trim().toUpperCase();
                outcome = labelEl.textContent.trim();
                if      (lbl === 'OVER')  dir = 'over';
                else if (lbl === 'UNDER') dir = 'under';
                else if (lbl === 'NO GOAL') dir = 'no_goal';
                else if (lbl === 'DRAW' || lbl === 'TIE' || lbl === 'X') dir = 'draw';
                else if (lbl === 'YES')   dir = 'yes';
                else if (lbl === 'NO')    dir = 'no';
                else if (lbl === 'ODD')   dir = 'odd';
                else if (lbl === 'EVEN')  dir = 'even';
                else if (lbl === '1X')    dir = 'home_draw';
                else if (lbl === 'X2')    dir = 'draw_away';
                else if (lbl === '12')    dir = 'home_away';
                else if (lbl === 'AWAY')  dir = 'away';
                else if (lbl === 'HOME')  dir = 'home';
            }
        }

        var valueEl = el.querySelector('.odd-box-with-label__value, .odd-box-with-logo__value');
        var rawVal = valueEl ? valueEl.textContent.trim() : '';
        if (!rawVal) {
            var m = t.match(/[+-]\\d{2,5}\\b|\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b/);
            rawVal = m ? m[0] : '';
        }

        var val = toDecimalOdds(rawVal);
        if (isCompositeOutcome && explicitLabel && val !== null) {
            return {dir: 'outcome', outcome: explicitLabel, val: val};
        }
        if (dir && val !== null) return {dir: dir, val: val};
        if (!outcome) {
            var clone = el.cloneNode(true);
            var valueNode = clone.querySelector('.odd-box-with-label__value, .odd-box-with-logo__value');
            if (valueNode) valueNode.remove();
            outcome = clone.textContent.replace(/\\s+/g, ' ').trim()
                .replace(/[+-]\\d{2,5}\\b|\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b/g, '')
                .trim();
        }
        return (outcome && val !== null) ? {dir: 'outcome', outcome: outcome, val: val} : null;
    }

    // Walk up from the odds row (stopping at the card) checking preceding siblings
    // for a "MAIN LINE" or "ALTERNATIVE LINES" section marker.
    function findSectionType(row, card) {
        var el = row;
        while (el && el !== card) {
            var prev = el.previousElementSibling;
            while (prev) {
                var t = prev.textContent.trim();
                if (t.length < 30) {
                    var tu = t.toUpperCase();
                    if (tu.indexOf('ALTERNATIVE') >= 0) return 'alternative';
                    if (tu === 'MAIN LINE')              return 'main';
                }
                prev = prev.previousElementSibling;
            }
            el = el.parentElement;
        }
        return 'main';
    }

    function cleanLineLabel(text) {
        return String(text || '').replace(/\\s+/g, ' ').trim()
            .replace(/\\s*compare.*$/i, '').trim();
    }

    function looksLikeLineLabel(text) {
        // Threshold and handicap labels can be a number ("2.5"), a
        // signed number ("-1.5"), or paired values ("-1/+1"). Do not
        // accept arbitrary label elements: outcome labels such as OVER and
        // HOME live in the same component tree.
        return /^[+-]?\\d+(?:\\.\\d+)?(?:\\s*(?:\\/|:)\\s*[+-]?\\d+(?:\\.\\d+)?)?(?:\\s+(?:goals?|corners?|cards?|points?|sets?|games?))?$/i.test(text);
    }

    function findParameterizedLineLabel(root) {
        var selectors = [
            '.matchup-handicap-line-info > [class*="text-capitalize"]',
            '.matchup-handicap-line-info',
            '[class*="line-info"] > [class*="text-capitalize"]',
            '[class*="line-info"]',
            '[class*="handicap"] > [class*="text-capitalize"]'
        ];
        for (var i = 0; i < selectors.length; i++) {
            var nodes = root.querySelectorAll(selectors[i]);
            for (var n = 0; n < nodes.length; n++) {
                var candidate = cleanLineLabel(nodes[n].textContent);
                if (looksLikeLineLabel(candidate)) return candidate;
            }
        }
        return '';
    }

    function marketNeedsLineLabel(market) {
        var name = String(market || '').replace(/^\\s*(?:1st|2nd)\\s+half\\s*-\\s*/i, '')
            .replace(/\\s+/g, ' ').trim().toLowerCase();
        return ['total goals', 'total corners', 'asian handicap',
            'asian handicap corners', 'european handicap'].indexOf(name) >= 0;
    }

    // Process a single odds row:
    //   1. Separate odds buttons from the label container using isOddsButton().
    //   2. Extract label text via the text-capitalize descendant (the label span
    //      sits inside a plain wrapper div, so we can't rely on the wrapper's class).
    //   3. Parse direction + value from each button.
    function processRow(row, card) {
        var children = Array.from(row.children);
        var label   = '';
        var buttons = [];

        // Oddspedia puts the handicap in this wrapper alongside the Compare
        // odds button. Read its dedicated value span before generic traversal;
        // the generic path correctly excludes button-containing containers.
        var handicapNode = row.querySelector(
            '.matchup-handicap-line-info > [class*="text-capitalize"]'
        );
        if (handicapNode) {
            var handicapLabel = cleanLineLabel(handicapNode.textContent);
            if (looksLikeLineLabel(handicapLabel)) label = handicapLabel;
        }

        for (var i = 0; i < children.length; i++) {
            if (!label && !children[i].querySelector('button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo')) {
                // Prefer the inner text-capitalize span for a clean label string
                var span = children[i].querySelector('[class*="text-capitalize"]');
                if (span) {
                    label = span.textContent.trim().split('\\n')[0].trim();
                } else {
                    label = children[i].textContent.trim()
                                .split('\\n')[0].trim()
                                .replace(/\\s*compare.*$/i, '').trim();
                }
            }
        }

        // In the current comparison-card layout the line value is a sibling
        // immediately before the flex odds row (for example, "1:0 Compare
        // odds" for European Handicap), rather than a child of that row.
        // Check that sibling before falling back to descendant labels.
        if (!label) {
            // The odds controls can sit in one or more layout wrappers after
            // their line value. Walk those wrappers up to the card boundary,
            // checking only the immediately preceding sibling at each level.
            // This preserves row association and avoids taking a label from a
            // previous odds line.
            var node = row;
            while (node && node !== card && !label) {
                var previous = node.previousElementSibling;
                if (previous && !previous.querySelector(
                    'button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo'
                )) {
                    var previousLabel = cleanLineLabel(previous.textContent);
                    if (looksLikeLineLabel(previousLabel)) label = previousLabel;
                }
                node = node.parentElement;
            }
        }

        // Current football cards place the line label inside the same wrapper
        // as the odds controls.  The direct-child pass above intentionally
        // ignores that wrapper because it contains buttons, which previously
        // left every total/handicap line with an empty label.  Search the
        // labelled descendants, excluding the controls themselves, and accept
        // only values shaped like a threshold or handicap.
        if (!label) {
            var labelNodes = Array.from(row.querySelectorAll(
                '[class*="label"], [class*="line"], [class*="handicap"], [class*="text-capitalize"]'
            ));
            for (var n = 0; n < labelNodes.length; n++) {
                var node = labelNodes[n];
                if (node.querySelector('button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo')) continue;
                if (node.closest('button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo')) continue;
                var candidate = cleanLineLabel(node.textContent);
                if (looksLikeLineLabel(candidate)) {
                    label = candidate;
                    break;
                }
            }
        }

        // Markets do not share one DOM shape. Double Chance can nest its
        // three controls in a wrapper, while Correct Score frequently has one
        // named outcome button per row. Extract the leaf controls rather than
        // assuming direct row children are the buttons.
        var candidates = Array.from(row.querySelectorAll(
            'button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo'
        )).filter(function(el) { return isOddsButton(el); });
        candidates.forEach(function(el) {
            var containsOddsChild = candidates.some(function(other) {
                return other !== el && el.contains(other);
            });
            if (!containsOddsChild && buttons.indexOf(el) < 0) buttons.push(el);
        });
        if (!buttons.length) {
            buttons = children.filter(isOddsButton);
        }
        if (!buttons.length) return null;

        var entry = {type: findSectionType(row, card), label: label};
        var parsedCount = 0;
        // Correct score and half-time/full-time rows have many buttons. The
        // previous edge-only logic silently lost each middle outcome.
        buttons.forEach(function(button) {
            var s = parseButton(button);
            if (!s) return;
            parsedCount++;
            if      (s.dir === 'over')  entry.over  = s.val;
            else if (s.dir === 'under') entry.under = s.val;
            else if (s.dir === 'no_goal') entry.no_goal = s.val;
            else if (s.dir === 'draw')  entry.draw  = s.val;
            else if (s.dir === 'yes')   entry.yes   = s.val;
            else if (s.dir === 'no')    entry.no    = s.val;
            else if (s.dir === 'odd')   entry.odd   = s.val;
            else if (s.dir === 'even')  entry.even  = s.val;
            else if (s.dir === 'home_draw') entry.home_draw = s.val;
            else if (s.dir === 'draw_away') entry.draw_away = s.val;
            else if (s.dir === 'home_away') entry.home_away = s.val;
            else if (s.dir === 'outcome') {
                if (!entry.outcomes) entry.outcomes = {};
                entry.outcomes[s.outcome] = s.val;
            }
            else if (s.dir === 'away')  entry.away  = s.val;
            else                        entry.home  = s.val;
        });
        // A one-button row is valid only when it is a named outcome (for
        // example a Correct Score scoreline). Direction-only single buttons
        // lack enough information to form an odds line by themselves.
        return parsedCount >= 2 || entry.outcomes ? entry : null;
    }

    function parseTextOnlyCard(card, market) {
        var text = card.textContent.replace(/\\s+/g, ' ').trim();
        var entry = {
            type: 'main',
            label: marketNeedsLineLabel(market) ? findParameterizedLineLabel(card) : ''
        };
        var count = 0;
        var re = /\\b(Home|Draw|Tie|X|Away|Over|Under|Yes|No|Odd|Even|1X|X2|12)\\s+([+-]\\d{2,5}\\b|\\d+\\.\\d+|\\d+\\s*\\/\\s*\\d+)/gi;
        var match;
        while ((match = re.exec(text)) !== null) {
            var key = match[1].toLowerCase();
            if (key === 'draw' || key === 'tie' || key === 'x') key = 'draw';
            else if (key === '1x') key = 'home_draw';
            else if (key === 'x2') key = 'draw_away';
            else if (key === '12') key = 'home_away';
            if (entry[key] !== undefined) continue;
            var val = toDecimalOdds(match[2]);
            if (val === null) continue;
            entry[key] = val;
            count++;
        }
        return count >= 2 ? entry : null;
    }

    // Some football cards render one outcome per tile rather than a paired
    // row. Collecting all leaf controls from the card preserves these markets
    // (Correct Score, First/Next Team to Score, Clean Sheet, and team props).
    function parseLooseCard(card, market) {
        var controls = Array.from(card.querySelectorAll(
            'button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo'
        )).filter(function(el) { return isOddsButton(el); });
        controls = controls.filter(function(el) {
            return !controls.some(function(other) { return other !== el && el.contains(other); });
        });
        var entry = {
            type: 'main',
            label: marketNeedsLineLabel(market) ? findParameterizedLineLabel(card) : ''
        };
        var count = 0;
        controls.forEach(function(control) {
            var s = parseButton(control);
            if (!s) return;
            count++;
            if      (s.dir === 'over') entry.over = s.val;
            else if (s.dir === 'under') entry.under = s.val;
            else if (s.dir === 'no_goal') entry.no_goal = s.val;
            else if (s.dir === 'draw') entry.draw = s.val;
            else if (s.dir === 'yes') entry.yes = s.val;
            else if (s.dir === 'no') entry.no = s.val;
            else if (s.dir === 'odd') entry.odd = s.val;
            else if (s.dir === 'even') entry.even = s.val;
            else if (s.dir === 'home_draw') entry.home_draw = s.val;
            else if (s.dir === 'draw_away') entry.draw_away = s.val;
            else if (s.dir === 'home_away') entry.home_away = s.val;
            else if (s.dir === 'away') entry.away = s.val;
            else if (s.dir === 'outcome') {
                if (!entry.outcomes) entry.outcomes = {};
                entry.outcomes[s.outcome] = s.val;
            } else entry.home = s.val;
        });
        // A loose card can legitimately expose only one named outcome. This
        // occurs on sparse Correct Score markets (for example, one remaining
        // "4 : 4" price). Keep the same acceptance rule as processRow: one
        // direction-only control is ambiguous, but one named outcome is a
        // complete line.
        return count >= 2 || entry.outcomes ? entry : null;
    }

    function getMarketName(card) {
        var sel = '[class*="card-header"],[class*="market-header"],[class*="market-name"],' +
                  '[class*="header"],[class*="title"],[class*="heading"],h2,h3,h4';
        var el = card.querySelector(sel);
        return el ? el.textContent.trim().split('\\n')[0].trim() : '';
    }

    // ── main ─────────────────────────────────────────────────────────────────

    var markets  = [];
    var seenRows = [];

    var cards = document.querySelectorAll('.matchup-odds-comparison-card');
    for (var c = 0; c < cards.length; c++) {
        var market = getMarketName(cards[c]);
        if (!market) continue;

        var lines = [];
        // Parameterized football markets use .matchup-handicap-line for each
        // full line.  The older flex selector matches its nested responsive
        // columns instead; those columns are hidden at desktop width and lose
        // their association with labels such as 1.5 or -0.25/+0.25.
        var rows  = cards[c].querySelectorAll(
            '.matchup-handicap-line, '
            + '.flex-grow-1.flex.align-items-center.justify-content-between'
        );
        for (var r = 0; r < rows.length; r++) {
            // All Full Time, 1st Half, and 2nd Half panes can remain mounted.
            // Only the rendered pane belongs to the active period tab.
            if (!isRendered(rows[r])) continue;
            var entry = processRow(rows[r], cards[c]);
            if (entry) { lines.push(entry); seenRows.push(rows[r]); }
        }
        // Replace fragmented one-tile rows with one grouped line. This avoids
        // losing markets whose individual rows contain only a single outcome.
        var fragmented = lines.length && lines.every(function(line) {
            return line.outcomes && Object.keys(line.outcomes).length === 1;
        });
        if (!lines.length || fragmented) {
            var looseEntry = parseLooseCard(cards[c], market);
            if (looseEntry) lines = [looseEntry];
        }
        if (!lines.length) {
            var textEntry = parseTextOnlyCard(cards[c], market);
            if (textEntry) lines.push(textEntry);
        }
        if (lines.length) markets.push({market: market, lines: lines});
    }

    // Fallback: any odds rows not captured inside a recognised card
    var allRows = document.querySelectorAll(
        '.matchup-handicap-line, '
        + '.flex-grow-1.flex.align-items-center.justify-content-between'
    );
    var curMarket = null, curLines = [];
    for (var r = 0; r < allRows.length; r++) {
        if (seenRows.indexOf(allRows[r]) >= 0) continue;
        if (!isRendered(allRows[r])) continue;

        var el = allRows[r].parentElement, heading = '';
        for (var lvl = 0; lvl < 8 && el; lvl++) {
            var hdr = el.querySelector('h2,h3,h4,[class*="title"],[class*="header"]');
            if (hdr) { heading = hdr.textContent.trim().split('\\n')[0].trim(); break; }
            el = el.parentElement;
        }
        if (heading && heading !== curMarket) {
            if (curMarket && curLines.length) markets.push({market: curMarket, lines: curLines});
            curMarket = heading; curLines = [];
        }
        var entry = processRow(allRows[r], document.body);
        if (entry) curLines.push(entry);
    }
    if (curMarket && curLines.length) markets.push({market: curMarket, lines: curLines});

    return markets;
"""


# Extract full "Live Stats" details from the active stats module.
_JS_EXTRACT_ACTIVE_OVERALL_STATS_TAB = """
    function cleanText(v) {
        return (v || '').replace(/\\s+/g, ' ').trim();
    }
    function isValue(v) {
        return /^-?\\d+(?:\\.\\d+)?%?$/.test(cleanText(v));
    }
    function addMetric(metrics, seen, name, home, away, view) {
        name = cleanText(name);
        home = cleanText(home);
        away = cleanText(away);
        if (!name || !home || !away) return;
        var key = name.toLowerCase() + '|' + home + '|' + away;
        if (seen[key]) return;
        seen[key] = true;
        metrics.push({name: name, home: home, away: away, view: view});
    }

    var root = document.querySelector('[data-module-name="Stats"], [data-module-name="Matchup stats"]');
    if (!root) return null;

    var btns = root.querySelectorAll('.btn-group-item .btn-group-item__btn');
    for (var b = 0; b < btns.length; b++) {
        var btnTxt = cleanText(btns[b].textContent).toLowerCase();
        if (btnTxt === 'live stats') {
            try { btns[b].click(); } catch (e) {}
            break;
        }
    }

    var activeBtn = root.querySelector('.btn-group-item__btn--active');
    var tabName = cleanText(activeBtn ? activeBtn.textContent : '');

    var metrics = [];
    var seen = {};

    // Horizontal rows: "home value | metric name | away value"
    var rows = root.querySelectorAll('.text-center .flex.justify-space-between.align-center');
    for (var i = 0; i < rows.length; i++) {
        var spans = rows[i].querySelectorAll('span');
        if (spans.length < 3) continue;

        var home = cleanText(spans[0].textContent);
        var name = cleanText(spans[1].textContent);
        var away = cleanText(spans[2].textContent);

        if (!isValue(home) || !isValue(away)) continue;
        addMetric(metrics, seen, name, home, away, 'horizontal');
    }

    // Football shots block: top number is on target, bottom-dark is off target.
    var shotLabels = root.querySelectorAll('span');
    var hasShotsLabel = false;
    for (var sl = 0; sl < shotLabels.length; sl++) {
        if (cleanText(shotLabels[sl].textContent).toLowerCase() === 'shots on / off target') {
            hasShotsLabel = true;
            break;
        }
    }
    if (hasShotsLabel) {
        var shotItems = root.querySelectorAll('.stats-shots-item');
        if (shotItems.length >= 2) {
            var homeNums = shotItems[0].querySelectorAll('.stats-shots-item__number');
            var awayNums = shotItems[shotItems.length - 1].querySelectorAll('.stats-shots-item__number');
            if (homeNums.length >= 2 && awayNums.length >= 2) {
                addMetric(metrics, seen, 'Shots on target', homeNums[0].textContent, awayNums[0].textContent, 'shots');
                addMetric(metrics, seen, 'Shots off target', homeNums[1].textContent, awayNums[1].textContent, 'shots');
            }
        }
    }

    // Icon rows such as Corners / Yellow cards / Red cards.
    var iconRows = root.querySelectorAll('img[alt]');
    for (var ir = 0; ir < iconRows.length; ir++) {
        var img = iconRows[ir];
        var label = cleanText(img.getAttribute('alt'));
        if (!label) continue;
        var wrap = img.closest('.flex.justify-center.align-center.font-brand');
        if (!wrap) continue;
        var nums = Array.from(wrap.querySelectorAll('span'))
            .map(function(s) { return cleanText(s.textContent); })
            .filter(isValue);
        if (nums.length >= 2) {
            addMetric(metrics, seen, label, nums[0], nums[nums.length - 1], 'icon');
        }
    }

    // Vertical blocks (Aces / Double faults / Breakpoints won ...)
    var vertical = root.querySelectorAll('.progress-bar-vertical');
    for (var v = 0; v < vertical.length; v++) {
        var block = vertical[v];
        var container = block.querySelector('.progress-bar-vertical__container');
        if (!container) continue;

        var valSpans = container.querySelectorAll('span');
        if (valSpans.length < 2) continue;
        var homeV = cleanText(valSpans[0].textContent);
        var awayV = cleanText(valSpans[valSpans.length - 1].textContent);

        var labelNode = block.querySelector(':scope > span');
        var nameV = cleanText(labelNode ? labelNode.textContent : '');
        addMetric(metrics, seen, nameV, homeV, awayV, 'vertical');
    }

    return { tab: tabName, metrics: metrics };
"""


# ── Odds processing ───────────────────────────────────────────────────────────


_JS_FOOTBALL_MARKET_SELECTOR_TEXTS = """
    function cleanText(el) {
        return (el && el.textContent || '').replace(/\\s+/g, ' ').trim();
    }
    function isOddsButtonText(text) {
        var t = text.toUpperCase();
        var hasDir = /\\b(OVER|UNDER|HOME|AWAY|DRAW|TIE|YES|NO)\\b/.test(t);
        var hasOdds = /\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b|(?:^|\\s)[+-]\\d{2,5}\\b/.test(t);
        return hasDir && hasOdds;
    }
    function isVisible(el) {
        if (!el) return false;
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 &&
               style.display !== 'none' && style.visibility !== 'hidden';
    }
    function looksLikeMarketText(text) {
        if (!text || text.length < 3 || text.length > 80) return false;
        var lower = text.toLowerCase();
        if (/\\bmoney\\s+on\\b|\\bbetting\\s+data\\b/.test(lower)) return false;
        if (/show more|show all|view all|compare|betting stats|live stats|seasonal stats/.test(lower)) return false;
        if (isOddsButtonText(text)) return false;
        if (/^\\d+(?:\\.\\d+)?$/.test(text)) return false;
        return /result|goals?|handicap|score|cards?|corners?|half|team|both|draw|winner|total|asian|double|chance|clean sheet|offsides|bookings|penalt|fouls?|throw|free kick|goal kick|substitution|var|woodwork|booking|shot|save/.test(lower);
    }
    function oddsRoot() {
        var card = document.querySelector('.matchup-odds-comparison-card');
        var node = card;
        for (var depth = 0; depth < 8 && node; depth++) {
            if (node.getAttribute && (node.getAttribute('data-module-name') || '').toLowerCase().indexOf('odds') >= 0) return node;
            node = node.parentElement;
        }
        return document;
    }
    function controlFor(el) {
        return el.closest('button, a, [role="button"], .btn-group-item__btn, .btn-group-item, li, [tabindex]');
    }
    var root = oddsRoot();
    var elements = Array.from(root.querySelectorAll(
        'button, a, [role="button"], .btn-group-item__btn, .btn-group-item, '
        + '[class*="dropdown"] li, [class*="dropdown"] span, [tabindex]'
    ));
    var texts = [];
    var seen = {};
    elements.forEach(function(el) {
        var text = cleanText(el);
        var key = text.toLowerCase();
        var control = controlFor(el);
        if (/^(1st|2nd) half$/i.test(text)) return;
        if (control && control.classList && control.classList.contains('matchup-odds-comparison-card__header')) return;
        if (control && control.closest('.matchup-odds-comparison-card__header')) return;
        if (seen[key] || !control || !isVisible(control) || !looksLikeMarketText(text)) return;
        seen[key] = true;
        texts.push(text);
    });
    return texts;
"""


def _click_football_market_selector(driver, market_text):
    if str(market_text or "").strip().lower() in {"1st half", "2nd half"}:
        return False
    clickable = driver.execute_script(
        """
        function cleanText(el) {
            return (el && el.textContent || '').replace(/\\s+/g, ' ').trim();
        }
        function isVisible(el) {
            if (!el) return false;
            var rect = el.getBoundingClientRect();
            var style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 &&
                   style.display !== 'none' && style.visibility !== 'hidden';
        }
        function isOddsButtonText(text) {
            var t = text.toUpperCase();
            var hasDir = /\\b(OVER|UNDER|HOME|AWAY|DRAW|TIE|YES|NO)\\b/.test(t);
            var hasOdds = /\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b|(?:^|\\s)[+-]\\d{2,5}\\b/.test(t);
            return hasDir && hasOdds;
        }
        function looksLikeMarketText(text) {
            if (!text || text.length < 3 || text.length > 80) return false;
            var lower = text.toLowerCase();
            if (/\\bmoney\\s+on\\b|\\bbetting\\s+data\\b/.test(lower)) return false;
            if (/show more|show all|view all|compare|betting stats|live stats|seasonal stats/.test(lower)) return false;
            if (isOddsButtonText(text)) return false;
            if (/^\\d+(?:\\.\\d+)?$/.test(text)) return false;
            return /result|goals?|handicap|score|cards?|corners?|half|team|both|draw|winner|total|asian|double|chance|clean sheet|offsides|bookings|penalt|fouls?|throw|free kick|goal kick|substitution|var|woodwork|booking|shot|save/.test(lower);
        }
        function oddsRoot() {
            var card = document.querySelector('.matchup-odds-comparison-card');
            var node = card;
            for (var depth = 0; depth < 8 && node; depth++) {
                if (node.getAttribute && (node.getAttribute('data-module-name') || '').toLowerCase().indexOf('odds') >= 0) return node;
                node = node.parentElement;
            }
            return document;
        }
        function controlFor(el) {
            return el.closest('button, a, [role="button"], .btn-group-item__btn, .btn-group-item, li, [tabindex]');
        }
        var root = oddsRoot();
        var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
        var elements = Array.from(root.querySelectorAll(
            'button, a, [role="button"], .btn-group-item__btn, .btn-group-item, '
            + '[class*="dropdown"] li, [class*="dropdown"] span, [tabindex]'
        ));
        var seen = {};
        for (var idx = 0; idx < elements.length; idx++) {
            var el = elements[idx];
            var text = cleanText(el);
            var key = text.toLowerCase();
            if (!looksLikeMarketText(text)) continue;
            if (key !== target) continue;
            // Do not promote the label to a broad "market"/"filter" wrapper:
            // those wrappers often contain the entire selector menu, so their
            // click does not select this specific market. Prefer the actual
            // interactive control and let a dropdown <li> click itself.
            var clickable = controlFor(el);
            if (clickable && clickable.classList && clickable.classList.contains('matchup-odds-comparison-card__header')) continue;
            if (clickable && clickable.closest('.matchup-odds-comparison-card__header')) continue;
            // Responsive menus commonly retain a hidden desktop/mobile copy.
            // Do not let that copy prevent us from trying the visible control.
            if (!clickable || !isVisible(clickable)) continue;
            return clickable;
        }
        return null;
    """,
        market_text,
    )
    if not clickable:
        return False
    try:
        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", clickable)
        clickable.click()
        return True
    except (WebDriverException, StaleElementReferenceException):
        try:
            return bool(driver.execute_script("arguments[0].click(); return true;", clickable))
        except WebDriverException:
            return False


def _current_odds_dom_signature(driver):
    return (
        driver.execute_script(
            """
        return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))
            .map(function(card) { return (card.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 500); })
            .join('|');
    """
        )
        or ""
    )


def _wait_for_odds_dom_change(driver, previous_signature, timeout=2.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            current = _current_odds_dom_signature(driver)
        except WebDriverException:
            return
        if current and current != previous_signature:
            return
        time.sleep(0.15)


def _wait_for_football_market_odds(driver, previous_signature, timeout=8.0):
    """Return rendered odds after a football market switch finishes.

    Oddspedia clears the comparison card while it fetches the next market.
    A DOM change alone therefore means *loading*, not necessarily that the
    requested market is ready to parse.
    """
    deadline = time.time() + timeout
    changed_signature = None
    stable_polls = 0
    while time.time() < deadline:
        try:
            signature = _current_odds_dom_signature(driver)
            if signature and signature != previous_signature:
                if signature == changed_signature:
                    stable_polls += 1
                else:
                    changed_signature = signature
                    stable_polls = 0
            # A market switch can briefly show a clearing/stale card. Wait for
            # the newly changed card to settle across two polls before parsing.
            if changed_signature and stable_polls >= 2:
                raw = driver.execute_script(_JS_EXTRACT_ODDS) or []
                if raw:
                    return raw
        except WebDriverException:
            return []
        time.sleep(0.2)
    return []


def _extract_football_odds(
    driver,
    base_odds,
    home="",
    away="",
    target_markets=None,
    raise_on_unresolved=True,
    return_unresolved=False,
):
    """Click football market selectors and merge their rendered odds.

    ``target_markets`` is used by the retry path to limit DOM interaction to
    markets that were absent from an earlier extraction. The default keeps the
    original all-selector behavior for first attempts and direct callers.
    """

    def extraction_result(markets, unresolved):
        return (markets, unresolved) if return_unresolved else markets

    odds = normalize_football_odds(base_odds or [], home=home, away=away)
    target_markets = list(
        dict.fromkeys(str(name).strip() for name in (target_markets or []) if str(name).strip())
    )
    if _football_odds_not_yet_available(driver):
        logger.info("football_odds_not_yet_available", markets=len(odds))
        unresolved = football_missing_market_names(target_markets, odds)
        return extraction_result(odds, unresolved)
    try:
        selector_texts = driver.execute_script(_JS_FOOTBALL_MARKET_SELECTOR_TEXTS) or []
    except WebDriverException as exc:
        logger.warning("football_market_selector_count_failed", error=str(exc))
        unresolved = football_missing_market_names(target_markets, odds)
        return extraction_result(odds, unresolved)

    selector_texts = [
        text
        for text in selector_texts
        if is_football_market_selector_text(text)
        and str(text).strip().lower() not in {"1st half", "2nd half"}
    ]
    if target_markets:
        selector_texts = [
            text
            for text in selector_texts
            if any(football_market_names_match(text, target) for target in target_markets)
            and not has_football_market(odds, text)
        ]
    if not selector_texts:
        odds = validate_european_handicap_coverage(odds)
        unresolved = football_missing_market_names(target_markets, odds)
        return extraction_result(odds, unresolved)

    logger.info(
        "football_market_selectors_found", count=len(selector_texts), selectors=selector_texts[:50]
    )
    unresolved_markets = []
    for market_text in selector_texts:
        try:
            markets = []
            # The UI can briefly expose the previously selected card after a
            # click. Only merge a card once its title confirms the requested
            # market; retry once for delayed market requests such as corners.
            for attempt in range(2):
                before = _current_odds_dom_signature(driver)
                if not _click_football_market_selector(driver, market_text):
                    break
                raw = _wait_for_football_market_odds(driver, before)
                # A selector switch renders only the main line initially.
                # Expand the newly rendered card before extracting it so
                # European Handicap (and other selector-only markets) keeps
                # its alternative handicap lines as well.
                _expand_football_market_card_lines(driver, market_text)
                # Re-read even when no expander was clicked. The card may have
                # already been expanded by the initial page pass, or its delayed
                # render may have added alternatives after the first read.
                raw = driver.execute_script(_JS_EXTRACT_ODDS) or raw
                candidate = apply_football_selector_context(build_odds(raw or []), market_text)
                candidate = normalize_football_odds(candidate, home=home, away=away)
                if football_selector_rendered(candidate, market_text):
                    markets = candidate
                    break
                logger.debug(
                    "football_market_selector_stale_render",
                    market=market_text,
                    attempt=attempt + 1,
                    rendered_markets=[m.get("market", "") for m in candidate],
                )
                time.sleep(0.4)
            if not markets:
                logger.warning("football_market_selector_no_lines", market=market_text)
                unresolved_markets.append(market_text)
            odds = merge_odds_markets(odds, markets)
        except WebDriverException as exc:
            logger.warning(
                "football_market_selector_extract_failed", market=market_text, error=str(exc)
            )
            if not has_football_market(odds, market_text):
                unresolved_markets.append(market_text)

    if unresolved_markets and not odds:
        if raise_on_unresolved:
            raise FootballOddsUnavailableError(
                "All football odds are unavailable: " + ", ".join(unresolved_markets)
            )
    if unresolved_markets and raise_on_unresolved:
        raise FootballOddsCoverageError(
            "Unresolved football odds markets: " + ", ".join(unresolved_markets)
        )
    if target_markets:
        unresolved_markets = football_missing_market_names(target_markets, odds)
    logger.info("football_odds_after_market_iteration", markets=len(odds))
    odds = validate_european_handicap_coverage(odds)
    return extraction_result(odds, unresolved_markets)


# ── Score parsing ─────────────────────────────────────────────────────────────


def _parse_football_score_payload(value):
    """Return aggregate football score from Oddspedia period-score payloads."""
    if not value:
        return None
    payload = value
    if isinstance(value, str):
        try:
            payload = json.loads(value)
        except (TypeError, ValueError):
            return None
    if not isinstance(payload, list):
        return None

    home_total = 0
    away_total = 0
    found = False
    for period in payload:
        if not isinstance(period, dict):
            continue
        period_type = str(period.get("period_type", "")).lower()
        if period_type and period_type not in {"regular_period", "extra_time"}:
            continue
        home = period.get("home")
        away = period.get("away")
        if home is None or away is None:
            continue
        try:
            home_total += int(home)
            away_total += int(away)
            found = True
        except (TypeError, ValueError):
            continue

    if not found:
        return None
    return {"home": home_total, "away": away_total}


def _football_score_from_dom(driver):
    """Read the final score rendered in the match header as a Vuex fallback."""
    try:
        result = driver.execute_script(
            """
            function text(el) {
                return el ? (el.textContent || '').replace(/\\s+/g, ' ').trim() : '';
            }
            var root = document.querySelector('.game-score')
                || document.querySelector('.matchup-header-postmatch-info')
                || document.querySelector('[class*="matchup-header"]');
            if (!root) return null;
            var home = root.querySelector('.game-score__team--home .game-score-result span, [class*="home"] .game-score-result span');
            var away = root.querySelector('.game-score__team--away .game-score-result span, [class*="away"] .game-score-result span');
            if (text(home) !== '' && text(away) !== '') return {home: text(home), away: text(away)};
            var score = text(root).match(/(?:^|\\s)(\\d+)\\s*[-:]\\s*(\\d+)(?:\\s|$)/);
            return score ? {home: score[1], away: score[2]} : null;
        """
        )
    except WebDriverException:
        return None
    if not isinstance(result, dict):
        return None
    home, away = result.get("home", ""), result.get("away", "")
    return {"home": home, "away": away} if home != "" and away != "" else None


def _football_score_from_meta(meta):
    """Build the football score object from direct fields or period payloads."""
    home = meta.get("home_score", "")
    away = meta.get("away_score", "")

    if home == "" or away == "":
        parsed = _parse_football_score_payload(
            meta.get("score_payload") or meta.get("raw_status") or meta.get("status")
        )
        if parsed:
            home = parsed["home"]
            away = parsed["away"]

    winner = meta.get("winner", "")
    if winner in (1, "1"):
        winner = "home"
    elif winner in (2, "2"):
        winner = "away"
    elif winner in (0, "0"):
        winner = "draw"
    elif home != "" and away != "":
        try:
            home_i = int(home)
            away_i = int(away)
            if home_i > away_i:
                winner = "home"
            elif away_i > home_i:
                winner = "away"
            else:
                winner = "draw"
        except (TypeError, ValueError):
            pass

    return {"home": home, "away": away, "winner": winner}


# ── Live odds extraction ──────────────────────────────────────────────────────


# ── Stats extraction ──────────────────────────────────────────────────────────


def _extract_overall_stats(driver):
    """Extract full details from the Oddspedia stats module (Live Stats only)."""
    has_module = driver.execute_script(
        """
        return !!document.querySelector('[data-module-name="Stats"], [data-module-name="Matchup stats"]');
    """
    )
    if not has_module:
        return {"tabs": []}

    # Keep only "Live Stats" (user-requested); ignore Betting/Seasonal/So Far tabs.
    driver.execute_script(
        """
        var root = document.querySelector('[data-module-name="Stats"], [data-module-name="Matchup stats"]');
        if (!root) return false;
        var btns = root.querySelectorAll('.btn-group-item .btn-group-item__btn');
        for (var i = 0; i < btns.length; i++) {
            var txt = (btns[i].textContent || '').replace(/\\s+/g, ' ').trim().toLowerCase();
            if (txt === 'live stats') {
                btns[i].click();
                return true;
            }
        }
        return false;
    """
    )
    time.sleep(0.5)

    tabs = []
    parsed = driver.execute_script(_JS_EXTRACT_ACTIVE_OVERALL_STATS_TAB)
    if parsed:
        tab_name = (parsed.get("tab") or "").strip().lower()
        if tab_name == "live stats":
            tabs.append(parsed)
        else:
            # If label is missing/variant but only one active tab is shown, still keep it.
            parsed["tab"] = "Live Stats"
            tabs.append(parsed)

    logger.info("overall_stats_extracted", tabs=len(tabs))
    return {"tabs": tabs}


# ── Public API ────────────────────────────────────────────────────────────────


def scrape_match(
    driver,
    match_info,
    sport=None,
    odds_attempt=FOOTBALL_ODDS_MAX_ATTEMPTS,
    odds_max_attempts=FOOTBALL_ODDS_MAX_ATTEMPTS,
    previous_empty_odds_attempts=None,
    previous_odds=None,
    retry_market_names=None,
):
    """Visit a single match page and extract all available data.

    The phase-two orchestrator passes the current odds attempt so an empty
    football odds render can be retried without accepting a false empty
    result. Direct callers default to the terminal attempt for backwards
    compatibility; the orchestrator owns the page-level retry loop.

    ``previous_odds`` and ``retry_market_names`` are supplied by the phase-two
    retry loop after a partial football extraction. The page still has to be
    loaded again, but only the named missing markets are expanded and selected;
    already saved markets are carried forward in memory.
    """
    metrics = get_metrics()
    sport = normalize_sport(sport or match_info.get("sport", "football"))
    try:
        odds_max_attempts = max(1, int(odds_max_attempts))
    except (TypeError, ValueError):
        odds_max_attempts = FOOTBALL_ODDS_MAX_ATTEMPTS
    try:
        odds_attempt = int(odds_attempt)
    except (TypeError, ValueError):
        odds_attempt = odds_max_attempts
    odds_attempt = max(1, min(odds_attempt, odds_max_attempts))
    if previous_empty_odds_attempts is None:
        # Direct callers historically received a terminal empty result. Treat
        # omitted state as the earlier attempts having already been empty,
        # while the orchestrator passes the real per-match counter.
        previous_empty_odds_attempts = max(0, odds_attempt - 1)
    else:
        try:
            previous_empty_odds_attempts = max(0, int(previous_empty_odds_attempts))
        except (TypeError, ValueError):
            previous_empty_odds_attempts = 0
    t0 = time.time()
    match_id = match_info["id"]
    url = match_info.get("full_url") or match_info.get("url", "")
    retry_market_names = list(
        dict.fromkeys(str(name).strip() for name in (retry_market_names or []) if str(name).strip())
    )

    if not url:
        logger.warning("no_url_for_match", match_id=match_id)
        return _build_result_from_listing(match_info, sport=sport)

    if not url.startswith("http"):
        url = base_url() + url
    if sport == "football":
        # Older discovery artifacts contain only the reusable matchup slug.
        # Pin it at navigation time so they remain safe without migration.
        url = pin_oddspedia_event_url(url, match_id)

    logger.info("match_scrape_start", sport=sport, match_id=match_id, url=url)

    archived_url = _archived_match_url(url, match_info, sport=sport)
    if archived_url and sport == "football":
        archived_url = pin_oddspedia_event_url(archived_url, match_id)
    candidate_urls = [url]
    if archived_url and archived_url != url:
        candidate_urls.append(archived_url)

    meta = {}
    loaded_url = None
    for candidate_index, candidate_url in enumerate(candidate_urls):
        if not safe_get(driver, candidate_url):
            if (
                candidate_index == 0
                and archived_url
                and _is_detail_url(candidate_url)
                and _listing_shell_is_current(driver, sport=sport)
            ):
                logger.warning(
                    "match_detail_url_fallback",
                    match_id=match_id,
                    requested_url=candidate_url,
                    fallback_url=archived_url,
                    reason="listing_shell_redirect",
                )
                continue
            try:
                page_title = driver.title or ""
            except WebDriverException:
                page_title = ""
            if _is_detail_url(candidate_url) and _is_listing_page_title(page_title):
                raise MatchPageNotRenderedError(
                    f"Match detail URL rendered the listing shell (match_id={match_id}, url={candidate_url})"
                )
            logger.error("match_load_failed", match_id=match_id, url=candidate_url)
            metrics.record_scrape_error("load_failed")
            return _build_result_from_listing(match_info, sport=sport)

        if _is_error_page(driver.title or ""):
            if candidate_index == 0 and archived_url:
                logger.warning(
                    "match_detail_url_fallback",
                    match_id=match_id,
                    requested_url=candidate_url,
                    fallback_url=archived_url,
                    reason="detail_page_not_found",
                )
                continue
            logger.warning("match_not_found", match_id=match_id)
            result = _build_result_from_listing(match_info, sport=sport)
            result["status"] = "page_not_found"
            return result

        # Proceed immediately when the page state is available instead of
        # waiting a fixed three seconds on every match.
        meta = _wait_for_event_metadata(driver, sport=sport)
        if not meta.get("home") or not meta.get("away"):
            if candidate_index == 0 and archived_url:
                logger.warning(
                    "match_detail_url_fallback",
                    match_id=match_id,
                    requested_url=candidate_url,
                    fallback_url=archived_url,
                    reason="event_metadata_missing",
                )
                continue
            raise MatchPageNotRenderedError(
                f"Match detail page did not expose event metadata (match_id={match_id}, url={candidate_url})"
            )

        identity_reasons = _event_identity_mismatch_reasons(match_info, meta)
        if identity_reasons:
            if candidate_index == 0 and archived_url and archived_url != candidate_url:
                logger.warning(
                    "match_detail_url_fallback",
                    match_id=match_id,
                    requested_url=candidate_url,
                    fallback_url=archived_url,
                    reason="identity_mismatch",
                    reasons=identity_reasons,
                )
                continue
            raise MatchIdentityMismatchError(
                "Match detail page does not match listing "
                f"(match_id={match_id}, url={candidate_url}, reasons={identity_reasons})"
            )
        loaded_url = candidate_url
        break

    if loaded_url is None:
        raise MatchPageNotRenderedError(
            f"No usable match detail route (match_id={match_id}, url={url})"
        )
    url = loaded_url
    _scroll_page(driver)
    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="page_ready",
        elapsed_seconds=round(time.time() - t0, 1),
    )

    # Event metadata from Vuex

    home = meta.get("home") or match_info.get("home", "")
    away = meta.get("away") or match_info.get("away", "")
    league = (
        meta.get("league")
        or match_info.get("league_name")
        or match_info.get("tournament")
        or match_info.get("league", "")
    )
    date = meta.get("date") or match_info.get("date", "")
    carried_odds = normalize_football_odds(previous_odds or [], home=home, away=away)
    targeted_market_retry = sport == "football" and bool(carried_odds) and bool(retry_market_names)

    # Set-based score fields stay in the payload contract but are always empty:
    # this scraper handles football only.
    home_sets = ""
    away_sets = ""
    set_scores = None

    # Fallback: try DOM-level status extraction when Vuex/post-match returns empty.
    # If the detail page still has no status, retain the listing status collected
    # in phase 1 so we can decide
    # later which statuses should be scraped without losing the source value.
    if not meta.get("status"):
        dom_status = (
            driver.execute_script(
                """
            var pm = document.querySelector('.matchup-header-postmatch-info');
            if (pm) {
                var txt = pm.textContent.trim().toLowerCase();
                var statusKeywords = ['canceled','cancelled','postponed','walkover',
                    'abandoned','retired','suspended','finished','walk over'];
                for (var i = 0; i < statusKeywords.length; i++) {
                    if (txt.indexOf(statusKeywords[i]) >= 0) return statusKeywords[i];
                }
            }
            // Try page title or error banner
            var t = document.title.toLowerCase();
            if (t.indexOf('404') >= 0 || t.indexOf('not found') >= 0) return 'page_not_found';
            return '';
        """
            )
            or ""
        )
        if dom_status:
            meta["status"] = dom_status
        elif match_info.get("status"):
            meta["status"] = match_info["status"]

    odds_unavailable = False
    odds_unavailable_reason = ""
    total_markets = None
    market_names = []
    if sport == "football":
        odds_unavailable = _football_odds_not_yet_available(driver)
        if odds_unavailable:
            odds_unavailable_reason = "source_notice"
            logger.info(
                "football_odds_not_yet_available",
                match_id=match_id,
                source_message=_ODDS_NOT_YET_AVAILABLE_MESSAGE,
            )
        else:
            logger.info("match_scrape_progress", match_id=match_id, stage="expanding_market_list")
            _expand_football_market_list(driver)
            logger.info("match_scrape_progress", match_id=match_id, stage="expanding_market_cards")
            _expand_football_market_cards(
                driver,
                market_names=retry_market_names if targeted_market_retry else None,
            )
            inventory = _football_market_inventory(driver)
            total_markets = inventory.get("total_markets")
            market_names = inventory.get("market_names", [])
            logger.info(
                "football_market_inventory",
                match_id=match_id,
                total_markets=total_markets,
                market_names=market_names,
                targeted_markets=retry_market_names if targeted_market_retry else None,
            )
    else:
        _expand_all_odds_lines(driver)

    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="extracting_odds",
        elapsed_seconds=round(time.time() - t0, 1),
    )

    # Odds. On a targeted retry, preserve the already extracted markets and
    # only use the current DOM's base read for the named missing markets.
    raw_markets = [] if odds_unavailable else driver.execute_script(_JS_EXTRACT_ODDS)
    current_odds = normalize_football_odds(build_odds(raw_markets or []), home=home, away=away)
    if targeted_market_retry:
        current_odds = football_filter_markets(current_odds, retry_market_names)
        odds = merge_odds_markets(list(carried_odds), current_odds)
    else:
        odds = current_odds
    extraction_error = None
    unresolved_markets = []
    if sport == "football":
        # The first rendered cards do not include every selector-only market.
        # Iterate those selectors after the base extraction, expanding each
        # card's hidden alternative lines before it is merged.
        try:
            extracted = _extract_football_odds(
                driver,
                odds,
                home=home,
                away=away,
                target_markets=retry_market_names if targeted_market_retry else None,
                raise_on_unresolved=False,
                return_unresolved=True,
            )
            if isinstance(extracted, tuple) and len(extracted) == 2:
                odds, unresolved_markets = extracted
            else:
                # Keep compatibility with test doubles and older direct
                # implementations that returned only the market list.
                odds = extracted
        except FootballOddsUnavailableError as exc:
            # An empty selector render is often a transient page state. Keep
            # it retryable until the configured terminal odds attempt.
            extraction_error = exc
            odds = []
        source_notice_detected = not odds and _football_odds_not_yet_available(driver)
        odds_unavailable = odds_unavailable or source_notice_detected
        if source_notice_detected:
            odds_unavailable_reason = "source_notice"
        if odds:
            odds_unavailable = False
            odds_unavailable_reason = ""

    # A listing row can carry a small 1X2 fallback. Use it before deciding
    # that a detail-page empty render needs another attempt.
    if sport == "football" and not odds:
        ho = match_info.get("home_odds", "")
        do = match_info.get("draw_odds", "")
        ao = match_info.get("away_odds", "")
        if ho and ao:
            line = {
                "type": "main",
                "label": FOOTBALL_DEFAULT_LINE_LABEL,
                "home": float(ho),
                "away": float(ao),
            }
            if do:
                line["draw"] = float(do)
            odds.append(
                {
                    "market": "Match Winner",
                    "lines": [line],
                }
            )
            odds_unavailable = False
            odds_unavailable_reason = ""
            extraction_error = None

    if sport == "football":
        if not odds:
            empty_odds_attempts = previous_empty_odds_attempts + 1
            if odds_unavailable_reason == "source_notice":
                logger.info(
                    "football_odds_unavailable_terminal",
                    match_id=match_id,
                    reason=odds_unavailable_reason,
                    odds_attempt=odds_attempt,
                    odds_max_attempts=odds_max_attempts,
                    empty_odds_attempts=empty_odds_attempts,
                )
            elif odds_attempt < odds_max_attempts:
                metrics.record_odds_extraction(success=False)
                logger.warning(
                    "football_odds_empty_retry",
                    match_id=match_id,
                    odds_attempt=odds_attempt,
                    odds_max_attempts=odds_max_attempts,
                    empty_odds_attempts=empty_odds_attempts,
                    total_markets=total_markets,
                    error=str(extraction_error) if extraction_error else "no odds extracted",
                )
                raise FootballOddsRetryableError(
                    "Football odds were empty on attempt "
                    f"{odds_attempt}/{odds_max_attempts}; retry required"
                ) from extraction_error

            elif empty_odds_attempts < odds_max_attempts:
                logger.warning(
                    "football_odds_empty_attempts_mixed",
                    match_id=match_id,
                    odds_attempt=odds_attempt,
                    odds_max_attempts=odds_max_attempts,
                    empty_odds_attempts=empty_odds_attempts,
                    total_markets=total_markets,
                )
                raise FootballOddsCoverageError(
                    "Football odds remained empty after the final attempt, but "
                    f"only {empty_odds_attempts}/{odds_max_attempts} attempts were empty"
                ) from extraction_error

            else:
                odds_unavailable = True
                odds_unavailable_reason = "empty_attempts_exhausted"
                logger.warning(
                    "football_odds_unavailable_after_retries",
                    match_id=match_id,
                    odds_attempt=odds_attempt,
                    odds_max_attempts=odds_max_attempts,
                    empty_odds_attempts=empty_odds_attempts,
                    total_markets=total_markets,
                )
        else:
            coverage_error = football_odds_coverage_error(
                odds,
                total_markets=total_markets,
                odds_unavailable=odds_unavailable,
            )
            if coverage_error:
                missing_market_names = list(
                    dict.fromkeys(
                        football_missing_market_names(market_names, odds) + list(unresolved_markets)
                    )
                )
                logger.warning(
                    "football_odds_markets_incomplete",
                    match_id=match_id,
                    total_markets=total_markets,
                    extracted_markets=len(odds),
                    market_names=market_names,
                    missing_markets=missing_market_names,
                    retryable=True,
                )
                raise FootballOddsCoverageError(
                    coverage_error,
                    missing_markets=missing_market_names,
                    partial_odds=odds,
                )
            logger.info(
                "football_odds_market_coverage",
                match_id=match_id,
                total_markets=total_markets,
                extracted_markets=len(odds),
                complete=(total_markets is None or len(odds) >= total_markets),
            )

    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="odds_extracted",
        markets=len(odds),
        total_markets=total_markets,
        odds_attempt=odds_attempt,
        odds_max_attempts=odds_max_attempts,
        elapsed_seconds=round(time.time() - t0, 1),
    )

    if odds:
        metrics.record_odds_extraction(success=True)
        for mkt in odds:
            metrics.record_odds_market(mkt.get("market", "unknown"))
    else:
        metrics.record_odds_extraction(success=False)

    # Football pages can expose in-play tabs, but live odds, set statistics and
    # point-by-point data are not scraped; the keys stay empty for the contract.
    live_odds = []
    stats = []
    point_by_point = []
    overall_stats = _extract_overall_stats(driver)
    if sport == "football":
        live_stats = []
        for tab in (overall_stats or {}).get("tabs", []):
            if (tab.get("tab") or "").strip().lower() == "live stats":
                live_stats = tab.get("metrics", []) or []
                break
        if not live_stats and (overall_stats or {}).get("tabs"):
            live_stats = overall_stats["tabs"][0].get("metrics", []) or []
        stats = live_stats

    if sport == "football":
        football_score = _football_score_from_meta(meta)
        if football_score["home"] == "" or football_score["away"] == "":
            dom_score = _football_score_from_dom(driver)
            if dom_score:
                meta.update(home_score=dom_score["home"], away_score=dom_score["away"])
                football_score = _football_score_from_meta(meta)
        football_status = meta.get("status", "")
        if _parse_football_score_payload(football_status):
            football_status = "finished"
        if _is_finished_football_status(football_status) and (
            football_score["home"] == "" or football_score["away"] == ""
        ):
            raise FootballScoreUnavailableError(
                f"Finished football match has no score (match_id={match_id})"
            )
        result = {
            "sport": sport,
            "id": match_id,
            "source_event_id": meta.get("event_id", ""),
            "home": home,
            "away": away,
            "tournament": league,
            "date": date,
            "url": url,
            "status": football_status,
            "score": football_score,
            "odds": odds,
            "odds_unavailable": odds_unavailable,
            "odds_total_markets": total_markets,
            "odds_extracted_markets": len(odds),
            "odds_attempt": odds_attempt,
            "odds_max_attempts": odds_max_attempts,
            "odds_empty_attempts": (previous_empty_odds_attempts + (0 if odds else 1)),
            "stats": stats,
            "stats_source": "Live Stats" if stats else "",
            "scraped_at": now_iso(),
        }
        if odds_unavailable_reason:
            result["odds_unavailable_reason"] = odds_unavailable_reason

        duration_seconds = int(time.time() - t0)
        logger.info(
            "match_scraped",
            sport=sport,
            match_id=match_id,
            home=home,
            away=away,
            odds_markets=len(odds),
            odds_total_markets=total_markets,
            odds_attempt=odds_attempt,
            odds_empty_attempts=(previous_empty_odds_attempts + (0 if odds else 1)),
            stats_count=len(stats),
            duration_seconds=duration_seconds,
        )
        return result

    result = {
        "sport": sport,
        "id": match_id,
        "home": home,
        "away": away,
        "tournament": league,
        "round": meta.get("round", ""),
        "date": date,
        "url": url,
        "home_rank": meta.get("home_rank", ""),
        "away_rank": meta.get("away_rank", ""),
        "category": meta.get("category", ""),
        "status": meta.get("status", ""),
        "winner": meta.get("winner", ""),
        "result_unavailable": meta.get("result_unavailable", False),
        "home_sets": home_sets,
        "away_sets": away_sets,
        "set_scores": set_scores,
        "odds": odds,
        "live_odds": live_odds,
        "stats": stats,
        "point_by_point": point_by_point,
        "overall_stats": overall_stats,
        "scraped_at": now_iso(),
    }

    duration_seconds = int(time.time() - t0)
    logger.info(
        "match_scraped",
        sport=sport,
        match_id=match_id,
        home=home,
        away=away,
        odds_markets=len(odds),
        live_odds_markets=len(live_odds),
        stats_count=len(stats),
        point_by_point_sets=len(point_by_point),
        overall_stats_tabs=len((overall_stats or {}).get("tabs", [])),
        duration_seconds=duration_seconds,
    )
    return result


def _build_result_from_listing(match_info, sport=None):
    """Build a minimal result when the match page cannot be loaded."""
    sport = normalize_sport(sport or match_info.get("sport", "football"))
    odds = []
    ho = match_info.get("home_odds", "")
    do = match_info.get("draw_odds", "")
    ao = match_info.get("away_odds", "")
    if ho and ao:
        line = {
            "type": "main",
            "label": FOOTBALL_DEFAULT_LINE_LABEL,
            "home": float(ho),
            "away": float(ao),
        }
        if do:
            line["draw"] = float(do)
        odds.append(
            {
                "market": "Match Winner",
                "lines": [line],
            }
        )

    if sport == "football":
        return {
            "sport": sport,
            "id": match_info["id"],
            "home": match_info.get("home", ""),
            "away": match_info.get("away", ""),
            "tournament": match_info.get(
                "league_name", match_info.get("tournament", match_info.get("league", ""))
            ),
            "date": match_info.get("date", ""),
            "url": match_info.get("full_url", match_info.get("url", "")),
            "status": match_info.get("status", ""),
            "score": {
                "home": match_info.get("home_score", ""),
                "away": match_info.get("away_score", ""),
                "winner": "",
            },
            "odds": odds,
            "stats": [],
            "stats_source": "",
            "scraped_at": now_iso(),
        }

    return {
        "sport": sport,
        "id": match_info["id"],
        "home": match_info.get("home", ""),
        "away": match_info.get("away", ""),
        "tournament": match_info.get(
            "league_name", match_info.get("tournament", match_info.get("league", ""))
        ),
        "round": "",
        "date": match_info.get("date", ""),
        "url": match_info.get("full_url", match_info.get("url", "")),
        "home_rank": "",
        "away_rank": "",
        "category": "",
        "status": match_info.get("status", ""),
        "winner": "",
        "result_unavailable": False,
        "home_sets": "",
        "away_sets": "",
        "set_scores": None,
        "odds": odds,
        "live_odds": [],
        "stats": [],
        "point_by_point": [],
        "overall_stats": {"tabs": []},
        "scraped_at": now_iso(),
    }
