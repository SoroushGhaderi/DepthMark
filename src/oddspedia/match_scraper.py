"""Match detail extraction – visit each match page and extract all data.

Extracts from each match page:
  - Event metadata (players, tournament, round, rankings, date)
  - Match result (winner, sets, set-by-set scores)
  - Odds from all bookmakers (Match Winner, Totals, Handicap, etc.)
  - Match statistics (aces, double faults, serve percentages, etc.)
"""

import time
import re
import json

from src.oddspedia.config import BASE_URL, SCROLL_PAUSE, normalize_sport
from src.oddspedia.utils import safe_get, now_iso, _is_error_page
from src.oddspedia.logging import get_logger
from src.oddspedia.metrics import get_metrics
from selenium.common.exceptions import WebDriverException, StaleElementReferenceException
from selenium.webdriver.common.by import By

logger = get_logger(__name__)


class FootballOddsCoverageError(RuntimeError):
    """Raised when Oddspedia exposes a football market that was not saved."""


class FootballOddsUnavailableError(RuntimeError):
    """Raised when a valid football page publishes no betting lines."""


class FootballScoreUnavailableError(RuntimeError):
    """Raised when a completed football event has no final score."""


# ── Helpers ───────────────────────────────────────────────────────────────────

def _scroll_page(driver, pause=SCROLL_PAUSE, max_scrolls=10):
    """Scroll incrementally to trigger lazy-loaded content."""
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
        if isinstance(meta, dict) and any(meta.get(field) for field in ("home", "away", "date", "status")):
            # Final football scores are occasionally populated after the rest
            # of Vuex event metadata. Do not snapshot a known-final event
            # before either the direct score or a period-score payload exists.
            score_ready = (
                meta.get("home_score", "") != ""
                and meta.get("away_score", "") != ""
            ) or _parse_football_score_payload(meta.get("score_payload") or meta.get("raw_status"))
            if sport != "football" or not _is_finished_football_status(meta.get("status")) or score_ready:
                return meta
        if attempt < max_attempts - 1:
            time.sleep(poll_interval)
    logger.warning("event_metadata_score_not_ready", attempts=max_attempts, sport=sport)
    return last_meta


def _click_tab(driver, name):
    """Click a named tab (e.g. 'Statistics') and wait for it to render.

    Returns True if a matching tab was found and clicked.
    """
    clicked = driver.execute_script("""
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
    """, name)
    if clicked:
        time.sleep(1.5)
    return bool(clicked)


def _click_btn_group_item(driver, label):
    """Click a .btn-group-item button whose text matches *label* (case-insensitive).

    These buttons appear on match pages (e.g. "Live Odds", "Pre-match Odds").
    Returns True if the button was found and clicked.
    """
    clicked = driver.execute_script("""
        var target = arguments[0].toLowerCase();
        var btns = document.querySelectorAll('.btn-group-item');
        for (var i = 0; i < btns.length; i++) {
            if (btns[i].textContent.trim().toLowerCase() === target) {
                btns[i].click();
                return true;
            }
        }
        return false;
    """, label)
    if clicked:
        time.sleep(2)
    return bool(clicked)


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
            page_height = driver.execute_script(
                "return Math.max(document.body.scrollHeight || 0, document.documentElement.scrollHeight || 0);"
            ) or 0
            viewport = driver.execute_script("return window.innerHeight || 900;") or 900
        except WebDriverException:
            break

        positions = list(range(0, int(page_height) + int(viewport), max(350, int(viewport * 0.65))))
        positions.append(int(page_height))

        for y in positions:
            try:
                driver.execute_script("window.scrollTo(0, arguments[0]);", y)
                time.sleep(0.15)
                elements = driver.find_elements(By.XPATH, xpath)
            except WebDriverException:
                continue

            for element in elements:
                try:
                    if not element.is_displayed():
                        continue
                    clickable = driver.execute_script("""
                        var el = arguments[0];
                        if (!el) return null;
                        return el.closest('button, a, [role="button"], .btn-pagination') || el;
                    """, element)
                    if not clickable:
                        continue
                    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", clickable)
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
        state = driver.execute_script("""
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
        """)
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


def _expand_football_market_list(driver, timeout=10.0):
    """Reveal collapsed full-time market cards with one scoped click."""
    state = driver.execute_script("""
        var root = document.querySelector('[data-module-name="Odds Comparison"]');
        if (!root) return {button: null, cards: 0};
        var button = Array.from(root.querySelectorAll('button.btn-pagination')).find(function(candidate) {
            var text = (candidate.textContent || '').replace(/\\s+/g, ' ').trim().toLowerCase();
            return text === 'show more' && !candidate.closest('.matchup-odds-comparison-card');
        }) || null;
        return {button: button, cards: root.querySelectorAll('.matchup-odds-comparison-card').length};
    """) or {}
    if not isinstance(state, dict):
        logger.warning("football_market_list_state_invalid", value_type=type(state).__name__)
        return 0
    button = state.get("button")
    before = int(state.get("cards") or 0)
    if not button:
        logger.info("football_market_list_already_expanded", cards=before)
        return 0

    try:
        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
        button.click()
    except (WebDriverException, StaleElementReferenceException) as exc:
        logger.warning("football_market_list_expand_failed", error=str(exc))
        return 0

    deadline = time.monotonic() + timeout
    current = before
    while time.monotonic() < deadline:
        current = int(driver.execute_script("""
            var root = document.querySelector('[data-module-name="Odds Comparison"]');
            return root ? root.querySelectorAll('.matchup-odds-comparison-card').length : 0;
        """) or 0)
        if current > before:
            break
        time.sleep(0.1)
    added = max(0, current - before)
    logger.info("football_market_list_expanded", before=before, after=current, added=added)
    return added


def _click_football_market_card(driver, market_title):
    """Return whether a collapsed football market card was expanded."""
    header = driver.execute_script("""
        var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
        var cards = Array.from(document.querySelectorAll('.matchup-odds-comparison-card'));
        for (var i = 0; i < cards.length; i++) {
            var card = cards[i];
            var button = card.querySelector('.matchup-odds-comparison-card__header');
            var title = button ? button.textContent.replace(/\\s+/g, ' ').trim().toLowerCase() : '';
            if (title === target) return button;
        }
        return null;
    """, market_title)
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
            state = driver.execute_script("""
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
            """, market_title) or {}
            if state.get("hasOdds") and not state.get("loading"):
                return True
        except WebDriverException:
            return False
        time.sleep(0.2)
    return False


def _expand_football_market_card_lines(driver, market_title, max_rounds=3):
    """Expand only the alternative-lines controls in one rendered card."""
    expanded = 0
    for _ in range(max_rounds):
        button = driver.execute_script("""
            var target = String(arguments[0] || '').replace(/\\s+/g, ' ').trim().toLowerCase();
            var cards = Array.from(document.querySelectorAll('.matchup-odds-comparison-card'));
            for (var i = 0; i < cards.length; i++) {
                var card = cards[i];
                var header = card.querySelector('.matchup-odds-comparison-card__header');
                var title = header ? header.textContent.replace(/\\s+/g, ' ').trim().toLowerCase() : '';
                if (title !== target) continue;
                return Array.from(card.querySelectorAll('button')).find(function(candidate) {
                    return /show all lines/i.test((candidate.textContent || '').replace(/\\s+/g, ' ').trim());
                }) || null;
            }
            return null;
        """, market_title)
        if not button:
            break
        try:
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
            button.click()
            expanded += 1
            time.sleep(0.25)
        except (WebDriverException, StaleElementReferenceException):
            break
    return expanded


def _expand_football_market_cards(driver):
    """Expand football cards and every visible card's alternative lines."""
    try:
        titles = driver.execute_script(_JS_FOOTBALL_COLLAPSED_MARKET_TITLES) or []
    except WebDriverException as exc:
        logger.warning("football_market_card_discovery_failed", error=str(exc))
        return

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
        all_titles = driver.execute_script("""
            return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))
                .map(function(card) {
                    var header = card.querySelector('.matchup-odds-comparison-card__header');
                    return header ? header.textContent.replace(/\\s+/g, ' ').trim() : '';
                })
                .filter(Boolean);
        """) or []
    except WebDriverException as exc:
        logger.warning("football_market_line_discovery_failed", error=str(exc))
        all_titles = []

    expanded_lines = sum(
        _expand_football_market_card_lines(driver, title)
        for title in dict.fromkeys(all_titles)
    )
    if titles or all_titles:
        logger.info(
            "football_market_cards_expanded",
            count=len(all_titles),
            alternative_line_buttons=expanded_lines,
        )


# ── JavaScript extractors ─────────────────────────────────────────────────────

# Pull event metadata and score data from the Vuex 'event' store module.
_JS_EVENT_META = """
    var d = {
        home:'', away:'', date:'', league:'', round:'',
        home_rank:'', away_rank:'', category:'', status:'',
        winner:'', home_score:'', away_score:'', raw_status:'', score_payload:null,
        home_sets:'', away_sets:'', set_scores:null,
        result_unavailable: false
    };
    try {
        var ev = document.querySelector('#__nuxt').__vue__.$store.state['event'];
        if (ev && ev.event) {
            var e = ev.event;
            d.home      = e.ht || '';
            d.away      = e.at || '';
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
                     t.indexOf('DRAW')  >= 0 || t.indexOf('YES')   >= 0 ||
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
        var labelEl = el.querySelector('.odd-box-with-label__label');
        var explicitLabel = labelEl ? labelEl.textContent.trim() : '';
        // Keep HT/FT labels such as "Draw / Home" intact rather than
        // collapsing them to a simple draw outcome below.
        var isCompositeOutcome = /[\\/→>]/.test(explicitLabel);
        if      (t.indexOf('OVER')  >= 0) dir = 'over';
        else if (t.indexOf('UNDER') >= 0) dir = 'under';
        // Check this before generic NO: it is a distinct third outcome.
        else if (t.indexOf('NO GOAL') >= 0) dir = 'no_goal';
        else if (t.indexOf('DRAW')  >= 0) dir = 'draw';
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
                else if (lbl === 'DRAW')  dir = 'draw';
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

    // Process a single odds row:
    //   1. Separate odds buttons from the label container using isOddsButton().
    //   2. Extract label text via the text-capitalize descendant (the label span
    //      sits inside a plain wrapper div, so we can't rely on the wrapper's class).
    //   3. Parse direction + value from each button.
    function processRow(row, card) {
        var children = Array.from(row.children);
        var label   = '';
        var buttons = [];

        function cleanLineLabel(text) {
            return String(text || '').replace(/\\s+/g, ' ').trim()
                .replace(/\\s*compare.*$/i, '').trim();
        }

        function looksLikeLineLabel(text) {
            // Threshold and handicap labels can be a number ("2.5"), a
            // signed number ("-1.5"), or paired values ("-1/+1").  Do not
            // accept arbitrary label elements: outcome labels such as OVER and
            // HOME live in the same component tree.
            return /^[+-]?\\d+(?:\\.\\d+)?(?:\\s*(?:\\/|:)\\s*[+-]?\\d+(?:\\.\\d+)?)?(?:\\s+(?:goals?|corners?|cards?|points?|sets?|games?))?$/i.test(text);
        }

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

    function parseTextOnlyCard(card) {
        var text = card.textContent.replace(/\\s+/g, ' ').trim();
        var entry = {type: 'main', label: ''};
        var count = 0;
        var re = /\\b(Home|Draw|Away|Over|Under|Yes|No|Odd|Even|1X|X2|12)\\s+([+-]\\d{2,5}\\b|\\d+\\.\\d+|\\d+\\s*\\/\\s*\\d+)/gi;
        var match;
        while ((match = re.exec(text)) !== null) {
            var key = match[1].toLowerCase();
            if (key === '1x') key = 'home_draw';
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
    function parseLooseCard(card) {
        var controls = Array.from(card.querySelectorAll(
            'button, a, [role="button"], .odd-box-with-label, .odd-box-with-logo'
        )).filter(function(el) { return isOddsButton(el); });
        controls = controls.filter(function(el) {
            return !controls.some(function(other) { return other !== el && el.contains(other); });
        });
        var entry = {type: 'main', label: ''};
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
        return count >= 2 ? entry : null;
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
        var rows  = cards[c].querySelectorAll(
            '.flex-grow-1.flex.align-items-center.justify-content-between'
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
            var looseEntry = parseLooseCard(cards[c]);
            if (looseEntry) lines = [looseEntry];
        }
        if (!lines.length) {
            var textEntry = parseTextOnlyCard(cards[c]);
            if (textEntry) lines.push(textEntry);
        }
        if (lines.length) markets.push({market: market, lines: lines});
    }

    // Fallback: any odds rows not captured inside a recognised card
    var allRows = document.querySelectorAll(
        '.flex-grow-1.flex.align-items-center.justify-content-between'
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

# Extract match statistics.
# Tries the Vuex store first, then falls back to DOM parsing.
_JS_EXTRACT_STATS = """
    // 1. Vuex store
    try {
        var store = document.querySelector('#__nuxt').__vue__.$store.state;
        var modules = ['event-statistics', 'statistics', 'match-statistics'];
        for (var i = 0; i < modules.length; i++) {
            var mod = store[modules[i]];
            if (!mod) continue;
            var data = mod.statistics || mod.stats || mod.data;
            if (data && (Array.isArray(data) ? data.length : Object.keys(data).length))
                return {source: 'vuex', stats: data};
        }
    } catch(ex) {}

    // 2. DOM: stat rows follow a (home_value | label | away_value) pattern
    var rows = [];
    var candidates = document.querySelectorAll(
        '[class*="statistic"], [class*="stat-row"], [class*="match-stat"]'
    );
    for (var j = 0; j < candidates.length; j++) {
        var ch = candidates[j].children;
        if (ch.length >= 3) {
            var mid = Math.floor(ch.length / 2);
            rows.push({
                name: ch[mid].textContent.trim(),
                home: ch[0].textContent.trim(),
                away: ch[ch.length - 1].textContent.trim()
            });
        }
    }
    if (rows.length) return {source: 'dom', stats: rows};

    // 3. Find the statistics section by text content and parse line-by-line
    var sections = document.querySelectorAll(
        '[class*="section"], [class*="panel"], [class*="content"], [class*="tab"]'
    );
    for (var k = 0; k < sections.length; k++) {
        var txt = sections[k].textContent;
        if (txt.indexOf('Aces') < 0 || txt.indexOf('Double Faults') < 0) continue;

        var stats = [];
        var lines = txt.split('\\n')
            .map(function(l) { return l.trim(); })
            .filter(Boolean);
        for (var l = 0; l + 2 < lines.length; l++) {
            if (/^\\d/.test(lines[l]) && !/^\\d/.test(lines[l + 1]) && /^\\d/.test(lines[l + 2])) {
                stats.push({name: lines[l + 1], home: lines[l], away: lines[l + 2]});
                l += 2;
            }
        }
        if (stats.length) return {source: 'text', stats: stats};
    }

    return {source: 'none', stats: []};
"""

# Extract point-by-point data for a specific tennis set dropdown index.
_JS_EXTRACT_POINT_BY_POINT_SET_BY_INDEX = """
    function txt(el) {
        return el ? el.textContent.replace(/\\s+/g, ' ').trim() : '';
    }

    function extractGame(gameEl) {
        var homeMeta = gameEl.querySelector('.highlights-tennis-set-game__meta--home');
        var awayMeta = gameEl.querySelector('.highlights-tennis-set-game__meta--away');
        var homeServing = !!(homeMeta && homeMeta.querySelector('img[alt*="Serving player"]'));
        var awayServing = !!(awayMeta && awayMeta.querySelector('img[alt*="Serving player"]'));

        var scoreSpans = gameEl.querySelectorAll('.highlights-tennis-set-game__score');
        var homeScore = scoreSpans.length > 0 ? txt(scoreSpans[0]) : '';
        var awayScore = scoreSpans.length > 1 ? txt(scoreSpans[1]) : '';

        var winner = '';
        if (scoreSpans.length > 1) {
            if (scoreSpans[0].classList.contains('is-winner')) winner = 'home';
            else if (scoreSpans[1].classList.contains('is-winner')) winner = 'away';
        }

        var gameLabels = [];
        var metaLabels = gameEl.querySelectorAll('.highlights-tennis-set-game__meta .highlights-tennis-set-game__label');
        for (var i = 0; i < metaLabels.length; i++) {
            var ltxt = txt(metaLabels[i]);
            if (ltxt) gameLabels.push(ltxt);
        }

        var points = [];
        var pointLis = gameEl.querySelectorAll('.highlights-tennis-set-game__points li');
        for (var p = 0; p < pointLis.length; p++) {
            var li = pointLis[p];
            var raw = txt(li);
            var score = '';
            var m = raw.match(/[0-9A]+:[0-9A]+/);
            if (m) score = m[0];

            var pointLabels = [];
            var spans = li.querySelectorAll('.highlights-tennis-set-game__label');
            for (var s = 0; s < spans.length; s++) {
                var stxt = txt(spans[s]);
                if (stxt) pointLabels.push(stxt);
            }
            points.push({
                score: score,
                labels: pointLabels,
                text: raw
            });
        }

        return {
            server: homeServing ? 'home' : (awayServing ? 'away' : ''),
            home_game_score: homeScore,
            away_game_score: awayScore,
            winner: winner,
            labels: gameLabels,
            points: points
        };
    }

    var idx = arguments[0];
    var root = document.querySelector('.highlights-tennis');
    if (!root) return null;

    var dropdowns = root.querySelectorAll('.event-timeline-dropdown');
    if (!dropdowns || idx < 0 || idx >= dropdowns.length) return null;
    var dropdown = dropdowns[idx];
    if (!dropdown) return null;
    var trigger = dropdown.querySelector('.event-timeline-dropdown__trigger');
    if (!trigger) return null;

    var content = dropdown.querySelector('.event-timeline-dropdown__content');
    if (!content) return null;

    var metaEl = trigger.querySelector('.event-timeline-dropdown__trigger__meta');
    var titleEl = trigger.querySelector('.event-timeline-dropdown__trigger__title');

    var games = [];
    var gameNodes = content.querySelectorAll('.highlights-tennis-set-game');
    for (var g = 0; g < gameNodes.length; g++) {
        games.push(extractGame(gameNodes[g]));
    }

    return {
        set: txt(metaEl),
        set_score: txt(titleEl),
        games: games
    };
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

def _build_odds(raw_markets):
    """Pass through raw markets from the JS extractor.

    Each market is already structured as::

        {"market": "Total Sets/Games", "lines": [
            {"type": "main",        "label": "22.5 Games", "over": 1.89, "under": 1.82},
            {"type": "alternative", "label": "2.5 Sets",   "over": 2.25, "under": 1.57},
            …
        ]}

    We just drop empty markets here.
    """
    return [m for m in (raw_markets or []) if m.get("lines")]


def _market_signature(market):
    return (
        str(market.get("market", "")).strip().lower(),
        json.dumps(market.get("lines", []), sort_keys=True, default=str),
    )


def _merge_odds_markets(existing, new_markets):
    def line_signature(line):
        # A fallback-only schema_status must not create a second copy of an
        # otherwise identical line once a later extraction normalizes it.
        return json.dumps(
            {key: value for key, value in line.items() if key != "schema_status"},
            sort_keys=True,
            default=str,
        )

    seen = {_market_signature(market) for market in existing}
    by_name = {
        str(market.get("market", "")).strip().lower(): market
        for market in existing
        if str(market.get("market", "")).strip()
    }
    for market in new_markets or []:
        if not market.get("lines"):
            continue
        sig = _market_signature(market)
        if sig in seen:
            continue
        market_name = str(market.get("market", "")).strip().lower()
        current = by_name.get(market_name)
        if current is not None:
            line_signatures = {line_signature(line) for line in current.get("lines", [])}
            for line in market.get("lines", []):
                signature = line_signature(line)
                if signature not in line_signatures:
                    current.setdefault("lines", []).append(line)
                    line_signatures.add(signature)
                elif line.get("schema_status") != "unmatched":
                    for current_line in current.get("lines", []):
                        if line_signature(current_line) == signature:
                            current_line.pop("schema_status", None)
                            break
            # A complete selector render supersedes an earlier fallback
            # classification for the same market.
            if market.get("schema_status") != "unmatched":
                current.pop("schema_status", None)
            seen.add(_market_signature(current))
            continue
        seen.add(sig)
        existing.append(market)
        if market_name:
            by_name[market_name] = market
    return existing


def _has_football_market(odds, market_name):
    target = _football_market_family(market_name)
    return any(
        _football_market_family(market.get("market", "")) == target
        and _football_market_has_coverage(market)
        for market in odds or []
    )


def _football_market_has_coverage(market):
    """Return whether a saved market contains the fields needed to trust it."""
    lines = [line for line in market.get("lines") or [] if isinstance(line, dict)]
    if not lines:
        return False
    if _football_market_family(market.get("market", "")) == "european handicap":
        return all(
            str(line.get("label", "")).strip()
            and all(line.get(field) is not None for field in ("home", "draw", "away"))
            for line in lines
        )
    return True


def _validate_european_handicap_coverage(odds):
    complete = []
    for market in odds or []:
        if (
            _football_market_family(market.get("market", "")) == "european handicap"
            and not _football_market_has_coverage(market)
        ):
            logger.warning(
                "european_handicap_incomplete_lines_skipped",
                market=market.get("market", "European Handicap"),
                lines=market.get("lines", []),
            )
            continue
        complete.append(market)
    return complete


def _football_label_key(value):
    return re.sub(r"[^a-z0-9]+", "", str(value or "").lower())


def _football_outcome_field(label, home, away):
    key = _football_label_key(label)
    home_key = _football_label_key(home)
    away_key = _football_label_key(away)

    if key in {"1", "home", "team1"}:
        return "home"
    if key in {"2", "away", "team2"}:
        return "away"
    if key and home_key and (key == home_key or key in home_key or home_key in key):
        return "home"
    if key and away_key and (key == away_key or key in away_key or away_key in key):
        return "away"
    if key in {"draw", "tie", "x"}:
        return "draw"
    if key in {"nogoal", "nogoals", "none", "neither", "nogol"}:
        return "no_goal"
    if key == "odd":
        return "odd"
    if key == "even":
        return "even"
    if key == "1x":
        return "home_draw"
    if key == "x2":
        return "draw_away"
    if key == "12":
        return "home_away"
    return ""


_FOOTBALL_COMMON_LINE_FIELDS = {"type", "label"}


def _football_market_family(market_name):
    name = re.sub(r"^\s*(?:1st|2nd)\s+half\s*-\s*", "", str(market_name or ""), flags=re.I)
    return re.sub(r"\s+", " ", name).strip().lower()


def _football_expected_shape(market_name):
    family = _football_market_family(market_name)
    if family in {"full time result", "match winner"}:
        return "home_draw_away"
    if family in {"total goals", "total corners"}:
        return "over_under"
    if family in {"asian handicap", "asian handicap corners"}:
        return "home_away"
    if family == "both teams to score":
        return "yes_no"
    if family == "double chance":
        return "double_chance"
    if family in {
        "draw no bet",
        "first team to score",
        "next goal",
        "clean sheet",
        "to win both halves",
        "to score in both halves",
        "to score a penalty",
    }:
        return "home_away_optional_no_goal"
    if family == "correct score":
        return "scores"
    if family == "european handicap":
        return "home_draw_away"
    if family == "half time / full time":
        return "combinations"
    if family == "corners odd or even":
        return "odd_even"
    return "generic"


def _football_allowed_fields(shape):
    fields = {
        "home_draw_away": {"home", "draw", "away"},
        "over_under": {"over", "under"},
        "home_away": {"home", "away"},
        "yes_no": {"yes", "no"},
        "double_chance": {"home_draw", "draw_away", "home_away"},
        "home_away_optional_no_goal": {"home", "away", "no_goal"},
        "scores": {"scores"},
        "combinations": {"combinations"},
        "odd_even": {"odd", "even"},
        "generic": {
            "home", "draw", "away", "over", "under", "yes", "no", "odd", "even",
            "home_draw", "draw_away", "home_away", "no_goal", "scores",
            "combinations", "outcomes",
        },
    }
    return fields.get(shape, fields["generic"])


def _football_line_matches_shape(line, shape):
    if shape == "home_draw_away":
        return all(line.get(key) is not None for key in ("home", "draw", "away"))
    if shape == "over_under":
        return all(line.get(key) is not None for key in ("over", "under"))
    if shape == "home_away":
        return all(line.get(key) is not None for key in ("home", "away"))
    if shape == "yes_no":
        return all(line.get(key) is not None for key in ("yes", "no"))
    if shape == "double_chance":
        return all(line.get(key) is not None for key in ("home_draw", "draw_away", "home_away"))
    if shape == "home_away_optional_no_goal":
        return all(line.get(key) is not None for key in ("home", "away"))
    if shape == "scores":
        return bool(line.get("scores"))
    if shape == "combinations":
        return bool(line.get("combinations"))
    if shape == "odd_even":
        return all(line.get(key) is not None for key in ("odd", "even"))
    return any(
        key not in _FOOTBALL_COMMON_LINE_FIELDS and line.get(key) is not None
        for key in line
    )


def _football_combo_key(label, home, away):
    text = str(label or "").strip()
    if not text:
        return ""
    # Oddspedia renders HT/FT outcomes as either team names, 1/X/2, or
    # Home - Draw. A spaced hyphen is an outcome separator here, unlike the
    # unspaced hyphen in scorelines (which belong to Correct Score).
    parts = re.split(r"\s*(?:/|→|>|\s+-\s+)\s*", text)
    if len(parts) != 2:
        return ""

    mapped = []
    for part in parts:
        field = _football_outcome_field(part, home, away)
        if field == "home":
            mapped.append("home")
        elif field == "away":
            mapped.append("away")
        elif field == "draw":
            mapped.append("draw")
        else:
            return ""
    return "_".join(mapped)


def _football_score_key(label):
    text = str(label or "").strip()
    return text if re.fullmatch(r"\d+\s*-\s*\d+", text) else ""


def _football_apply_market_contract(market, home="", away=""):
    market_name = str(market.get("market", "")).strip()
    family = _football_market_family(market_name)
    shape = _football_expected_shape(market_name)
    allowed = _football_allowed_fields(shape)
    contracted_lines = []

    for line in market.get("lines") or []:
        if not isinstance(line, dict):
            continue
        next_line = {key: line[key] for key in _FOOTBALL_COMMON_LINE_FIELDS if key in line}
        next_line.setdefault("type", "main")
        next_line.setdefault("label", "")

        for key in allowed:
            if key in line:
                next_line[key] = line[key]

        if shape == "scores":
            scores = dict(next_line.get("scores") or {})
            for label, value in (line.get("outcomes") or {}).items():
                key = _football_score_key(label)
                if key:
                    scores[key] = value
            if scores:
                next_line["scores"] = scores

        if shape == "combinations":
            next_line.pop("combinations", None)
            combinations = {}
            for label, value in (line.get("combinations") or {}).items():
                key = _football_combo_key(label, home, away)
                if key:
                    combinations[key] = value
            for label, value in (line.get("outcomes") or {}).items():
                key = _football_combo_key(label, home, away)
                if key:
                    combinations[key] = value
            if combinations:
                next_line["combinations"] = combinations

        if family == "european handicap":
            missing = []
            if not str(next_line.get("label", "")).strip():
                missing.append("label")
            missing.extend(
                field for field in ("home", "draw", "away")
                if next_line.get(field) is None
            )
            if missing:
                logger.warning(
                    "european_handicap_line_skipped",
                    market=market_name,
                    label=next_line.get("label", ""),
                    missing=missing,
                )
                continue
        if _football_line_matches_shape(next_line, shape):
            contracted_lines.append(next_line)

    next_market = dict(market)
    next_market["market"] = market_name
    if contracted_lines:
        # A Full Time Result card represents one 1X2 price. Some Oddspedia
        # cards keep additional period panes mounted after switching tabs;
        # those rows must never be serialized as extra full-time lines.
        if _football_market_family(market_name) in {"full time result", "match winner"}:
            contracted_lines = contracted_lines[:1]
        next_market["lines"] = contracted_lines
    else:
        fallback_lines = []
        for line in market.get("lines") or []:
            if not isinstance(line, dict):
                continue
            fallback = {key: line[key] for key in _FOOTBALL_COMMON_LINE_FIELDS if key in line}
            fallback.setdefault("type", "main")
            fallback.setdefault("label", "")
            for key, value in line.items():
                if key in _FOOTBALL_COMMON_LINE_FIELDS:
                    continue
                if value is not None:
                    fallback[key] = value
            if len(fallback) > len(_FOOTBALL_COMMON_LINE_FIELDS):
                fallback["schema_status"] = "unmatched"
                fallback_lines.append(fallback)
        if family == "european handicap":
            return None
        if not fallback_lines:
            return None
        next_market["schema_status"] = "unmatched"
        next_market["lines"] = fallback_lines
    return next_market


def _normalize_football_odds(odds, home="", away=""):
    """Map football named-outcome markets onto stable saved line fields."""
    normalized = []
    for market in odds or []:
        if not isinstance(market, dict):
            continue
        if re.match(r"^\s*(?:1st|2nd)\s+half\s*-", str(market.get("market", "")), flags=re.I):
            continue
        next_market = dict(market)
        next_lines = []
        for line in market.get("lines") or []:
            if not isinstance(line, dict):
                continue
            next_line = dict(line)
            outcomes = next_line.pop("outcomes", None)
            remaining = {}
            if isinstance(outcomes, dict):
                shape = _football_expected_shape(market.get("market", ""))
                for label, value in outcomes.items():
                    field = "" if shape in {"scores", "combinations"} else _football_outcome_field(label, home, away)
                    if field and field not in next_line:
                        next_line[field] = value
                    else:
                        remaining[str(label)] = value
            if remaining:
                shape = _football_expected_shape(market.get("market", ""))
                if shape == "scores":
                    next_line["scores"] = remaining
                elif shape == "combinations":
                    next_line["combinations"] = remaining
                else:
                    next_line["outcomes"] = remaining
            next_lines.append(next_line)
        next_market["lines"] = next_lines
        contracted = _football_apply_market_contract(next_market, home=home, away=away)
        if contracted:
            normalized.append(contracted)
    # Card and fallback extraction can describe the same market. Consolidate
    # them here so callers never persist a fallback ``unmatched`` duplicate
    # alongside its successfully normalized equivalent.
    return _merge_odds_markets([], normalized)


def _apply_football_selector_context(markets, selector_text):
    selector = (selector_text or "").strip()
    if not selector:
        return markets

    contextual = []
    period_selector = selector.lower() in {"1st half", "2nd half"}
    for market in markets or []:
        market = dict(market)
        name = str(market.get("market", "")).strip()
        if period_selector:
            if name and not name.lower().startswith(selector.lower()):
                market["market"] = f"{selector} - {name}"
        elif (
            len(markets) == 1
            and selector.lower() != name.lower()
            and _football_expected_shape(name) == "generic"
        ):
            market["market"] = selector
        contextual.append(market)
    return contextual


_JS_FOOTBALL_MARKET_SELECTOR_TEXTS = """
    function cleanText(el) {
        return (el && el.textContent || '').replace(/\\s+/g, ' ').trim();
    }
    function isOddsButtonText(text) {
        var t = text.toUpperCase();
        var hasDir = /\\b(OVER|UNDER|HOME|AWAY|DRAW|YES|NO)\\b/.test(t);
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
    clickable = driver.execute_script("""
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
            var hasDir = /\\b(OVER|UNDER|HOME|AWAY|DRAW|YES|NO)\\b/.test(t);
            var hasOdds = /\\d+\\.\\d+|\\b\\d+\\s*\\/\\s*\\d+\\b|(?:^|\\s)[+-]\\d{2,5}\\b/.test(t);
            return hasDir && hasOdds;
        }
        function looksLikeMarketText(text) {
            if (!text || text.length < 3 || text.length > 80) return false;
            var lower = text.toLowerCase();
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
    """, market_text)
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
    return driver.execute_script("""
        return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))
            .map(function(card) { return (card.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 500); })
            .join('|');
    """) or ""


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


def _football_selector_rendered(markets, selector_text):
    """Whether a selector produced the market it was asked to display."""
    selector = str(selector_text or "").strip().lower()
    if selector in {"1st half", "2nd half"}:
        period_markets = [
            market for market in markets or []
            if str(market.get("market", "")).strip().lower().startswith(f"{selector} -")
        ]
        return bool(period_markets) and all(_football_market_has_coverage(market) for market in period_markets)
    return any(
        str(market.get("market", "")).strip().lower() == selector
        and _football_market_has_coverage(market)
        for market in markets or []
    )


def _extract_football_odds(driver, base_odds, home="", away=""):
    """Click each visible football market selector and merge its rendered odds."""
    odds = _normalize_football_odds(base_odds or [], home=home, away=away)
    try:
        selector_texts = driver.execute_script(_JS_FOOTBALL_MARKET_SELECTOR_TEXTS) or []
    except WebDriverException as exc:
        logger.warning("football_market_selector_count_failed", error=str(exc))
        return odds

    selector_texts = [
        text for text in selector_texts
        if str(text).strip().lower() not in {"1st half", "2nd half"}
        and not _has_football_market(odds, text)
    ]
    if not selector_texts:
        return _validate_european_handicap_coverage(odds)

    logger.info("football_market_selectors_found", count=len(selector_texts), selectors=selector_texts[:50])
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
                candidate = _apply_football_selector_context(_build_odds(raw or []), market_text)
                candidate = _normalize_football_odds(candidate, home=home, away=away)
                if _football_selector_rendered(candidate, market_text):
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
                if _has_football_market(odds, market_text):
                    logger.debug("football_market_selector_already_captured", market=market_text)
                else:
                    logger.warning("football_market_selector_no_lines", market=market_text)
                    unresolved_markets.append(market_text)
            odds = _merge_odds_markets(odds, markets)
        except WebDriverException as exc:
            logger.warning("football_market_selector_extract_failed", market=market_text, error=str(exc))
            if not _has_football_market(odds, market_text):
                unresolved_markets.append(market_text)

    if unresolved_markets and not odds:
        raise FootballOddsUnavailableError(
            "All football odds are unavailable: " + ", ".join(unresolved_markets)
        )
    if unresolved_markets:
        raise FootballOddsCoverageError(
            "Unresolved football odds markets: " + ", ".join(unresolved_markets)
        )
    logger.info("football_odds_after_market_iteration", markets=len(odds))
    return _validate_european_handicap_coverage(odds)


# ── Score parsing ─────────────────────────────────────────────────────────────

def _parse_set_scores(text):
    """Extract set-by-set scores from a text string (e.g. '6-4 6-2').

    Returns (set_scores, home_sets, away_sets).
    """
    pattern = re.findall(r'\b([0-7])-([0-7])\b', text[:500])
    if not pattern:
        return None, "", ""
    set_scores = [{"home": int(a), "away": int(b)} for a, b in pattern[:5]]
    home_sets = sum(1 for a, b in pattern if int(a) > int(b))
    away_sets = sum(1 for a, b in pattern if int(b) > int(a))
    return set_scores, home_sets, away_sets


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
        result = driver.execute_script("""
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
        """)
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

def _extract_live_odds(driver):
    """Click the 'Live Odds' btn-group-item button and extract the odds shown.

    These are in-play odds recorded at the time of scraping (different from
    pre-match odds which are shown by default).  Returns an empty list when
    the button is not present (finished or pre-match-only events).
    """
    if not _click_btn_group_item(driver, "live odds"):
        return []
    # Expand hidden alternative lines in the live-odds view as well
    _expand_all_odds_lines(driver)
    raw = driver.execute_script(_JS_EXTRACT_ODDS)
    live = _build_odds(raw or [])
    metrics = get_metrics()
    if live:
        metrics.record_odds_extraction(success=True, is_live=True)
        for mkt in live:
            metrics.record_odds_market(mkt.get("market", "unknown"))
    else:
        metrics.record_odds_extraction(success=False, is_live=True)
    logger.info("live_odds_extracted", markets=len(live))
    # Restore the default pre-match view so further extractions are unaffected
    _click_btn_group_item(driver, "pre-match odds")
    return live


# ── Stats extraction ──────────────────────────────────────────────────────────

def _extract_stats(driver):
    """Click the Statistics tab (if present) and extract match stats.

    Returns a list of dicts with keys ``name``, ``home``, ``away``.
    """
    _click_tab(driver, "statistics")
    raw = driver.execute_script(_JS_EXTRACT_STATS) or {}

    source = raw.get("source", "none")
    data = raw.get("stats", [])

    if source == "none" or not data:
        return []

    logger.info("stats_extracted", source=source, count=len(data) if isinstance(data, list) else "unknown")

    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [{"name": k, "home": v, "away": ""} for k, v in data.items()]
    return []


def _extract_point_by_point(driver):
    """Extract tennis point-by-point timeline by iterating set dropdowns."""
    has_tennis_timeline = driver.execute_script("""
        return !!document.querySelector('.event-timeline .highlights-tennis');
    """)
    if not has_tennis_timeline:
        return []

    triggers_count = driver.execute_script("""
        return document.querySelectorAll(
            '.highlights-tennis .event-timeline-dropdown__trigger'
        ).length;
    """) or 0

    sets = []
    seen = set()

    for idx in range(int(triggers_count)):
        # Some pages use accordion behavior where clicking an already-open set
        # collapses it. We therefore allow a second toggle attempt if no games
        # are visible after the first click.
        set_data = None
        for attempt in range(2):
            driver.execute_script("""
                var i = arguments[0];
                var btns = document.querySelectorAll('.highlights-tennis .event-timeline-dropdown__trigger');
                if (!btns || i >= btns.length) return false;
                btns[i].click();
                return true;
            """, idx)
            time.sleep(0.25)

            # Poll briefly for async dropdown content rendering.
            for _ in range(7):
                set_data = driver.execute_script(_JS_EXTRACT_POINT_BY_POINT_SET_BY_INDEX, idx)
                if set_data and set_data.get("games"):
                    break
                time.sleep(0.2)
            if set_data and set_data.get("games"):
                break

        if not set_data:
            continue

        key = f"{set_data.get('set','')}|{set_data.get('set_score','')}"
        if key in seen:
            continue
        seen.add(key)
        sets.append(set_data)

    logger.info("point_by_point_extracted", sets=len(sets))
    return sets


def _extract_overall_stats(driver):
    """Extract full details from the Oddspedia stats module (Live Stats only)."""
    has_module = driver.execute_script("""
        return !!document.querySelector('[data-module-name="Stats"], [data-module-name="Matchup stats"]');
    """)
    if not has_module:
        return {"tabs": []}

    # Keep only "Live Stats" (user-requested); ignore Betting/Seasonal/So Far tabs.
    driver.execute_script("""
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
    """)
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

def scrape_match(driver, match_info, sport=None):
    """Visit a single match page and extract all available data."""
    metrics = get_metrics()
    sport = normalize_sport(sport or match_info.get("sport", "football"))
    t0 = time.time()
    match_id = match_info["id"]
    url = match_info.get("full_url") or match_info.get("url", "")

    if not url:
        logger.warning("no_url_for_match", match_id=match_id)
        return _build_result_from_listing(match_info, sport=sport)

    if not url.startswith("http"):
        url = BASE_URL + url

    logger.info("match_scrape_start", sport=sport, match_id=match_id, url=url)

    if not safe_get(driver, url):
        logger.error("match_load_failed", match_id=match_id, url=url)
        metrics.record_scrape_error("load_failed")
        return _build_result_from_listing(match_info, sport=sport)

    if _is_error_page(driver.title or ""):
        logger.warning("match_not_found", match_id=match_id)
        result = _build_result_from_listing(match_info, sport=sport)
        result["status"] = "page_not_found"
        return result

    # Proceed immediately when the page state is available instead of waiting a
    # fixed three seconds on every match.
    meta = _wait_for_event_metadata(driver, sport=sport)
    _scroll_page(driver)
    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="page_ready",
        elapsed_seconds=round(time.time() - t0, 1),
    )

    # Event metadata from Vuex

    home   = meta.get("home")   or match_info.get("home", "")
    away   = meta.get("away")   or match_info.get("away", "")
    league = (
        meta.get("league")
        or match_info.get("league_name")
        or match_info.get("tournament")
        or match_info.get("league", "")
    )
    date   = meta.get("date")   or match_info.get("date", "")

    # Tennis score fields are sport-specific. Football should rely on shared
    # metadata/status/odds/stats rather than fake set data.
    home_sets = ""
    away_sets = ""
    set_scores = None
    if sport == "tennis":
        home_sets = meta.get("home_sets", "")
        away_sets = meta.get("away_sets", "")
        set_scores = meta.get("set_scores")

    if sport == "tennis" and not home_sets and not away_sets:
        header_text = driver.execute_script("""
            var h = document.querySelector(
                '.match-header, [class*="match-header"], header, [class*="event-header"]'
            );
            return h ? h.textContent.trim().replace(/\\s+/g, ' ').substring(0, 500) : '';
        """) or ""
        set_scores, home_sets, away_sets = _parse_set_scores(header_text)

    # Fallback: try DOM-level status extraction when Vuex/post-match returns empty.
    # If the detail page still has no status, retain the listing status collected
    # in phase 1. This keeps tennis aligned with football and lets us decide
    # later which statuses should be scraped without losing the source value.
    if not meta.get("status"):
        dom_status = driver.execute_script("""
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
        """) or ""
        if dom_status:
            meta["status"] = dom_status
        elif match_info.get("status"):
            meta["status"] = match_info["status"]

    if sport == "football":
        logger.info("match_scrape_progress", match_id=match_id, stage="expanding_market_list")
        _expand_football_market_list(driver)
        logger.info("match_scrape_progress", match_id=match_id, stage="expanding_market_cards")
        _expand_football_market_cards(driver)
    else:
        _expand_all_odds_lines(driver)

    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="extracting_odds",
        elapsed_seconds=round(time.time() - t0, 1),
    )

    # Odds
    raw_markets = driver.execute_script(_JS_EXTRACT_ODDS)
    odds = _build_odds(raw_markets or [])
    if sport == "football":
        odds = _normalize_football_odds(odds, home=home, away=away)
        # The first rendered cards do not include every selector-only market.
        # Iterate those selectors after the base extraction, expanding each
        # card's hidden alternative lines before it is merged.
        odds = _extract_football_odds(driver, odds, home=home, away=away)

    logger.info(
        "match_scrape_progress",
        match_id=match_id,
        stage="odds_extracted",
        markets=len(odds),
        elapsed_seconds=round(time.time() - t0, 1),
    )

    if odds:
        metrics.record_odds_extraction(success=True)
        for mkt in odds:
            metrics.record_odds_market(mkt.get("market", "unknown"))
    else:
        metrics.record_odds_extraction(success=False)

    if sport == "football" and 0 < len(odds) <= 4:
        logger.warning(
            "football_odds_markets_may_be_truncated",
            match_id=match_id,
            markets=len(odds),
            market_names=[m.get("market", "") for m in odds],
        )

    if not odds:
        ho = match_info.get("home_odds", "")
        do = match_info.get("draw_odds", "")
        ao = match_info.get("away_odds", "")
        if ho and ao:
            line = {"type": "main", "label": "", "home": float(ho), "away": float(ao)}
            if do:
                line["draw"] = float(do)
            odds.append({
                "market": "Match Winner",
                "lines": [line],
            })

    # Live odds are tennis-only for this scraper. Football pages can expose
    # in-play tabs, but we intentionally do not scrape them.
    live_odds = _extract_live_odds(driver) if sport == "tennis" else []

    # Statistics
    stats = _extract_stats(driver) if sport == "tennis" else []
    point_by_point = _extract_point_by_point(driver) if sport == "tennis" else []
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
            "sport":      sport,
            "id":         match_id,
            "home":       home,
            "away":       away,
            "tournament": league,
            "date":       date,
            "url":        url,
            "status":              football_status,
            "score":      football_score,
            "odds":       odds,
            "stats":      stats,
            "stats_source": "Live Stats" if stats else "",
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
            stats_count=len(stats),
            duration_seconds=duration_seconds,
        )
        return result

    result = {
        "sport":      sport,
        "id":         match_id,
        "home":       home,
        "away":       away,
        "tournament": league,
        "round":      meta.get("round", ""),
        "date":       date,
        "url":        url,
        "home_rank":  meta.get("home_rank", ""),
        "away_rank":  meta.get("away_rank", ""),
        "category":   meta.get("category", ""),
        "status":              meta.get("status", ""),
        "winner":              meta.get("winner", ""),
        "result_unavailable":  meta.get("result_unavailable", False),
        "home_sets":           home_sets,
        "away_sets":           away_sets,
        "set_scores":          set_scores,
        "odds":                odds,
        "live_odds":  live_odds,
        "stats":      stats,
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
        line = {"type": "main", "label": "", "home": float(ho), "away": float(ao)}
        if do:
            line["draw"] = float(do)
        odds.append({
            "market": "Match Winner",
            "lines": [line],
        })

    if sport == "football":
        return {
            "sport":      sport,
            "id":         match_info["id"],
            "home":       match_info.get("home", ""),
            "away":       match_info.get("away", ""),
            "tournament": match_info.get("league_name", match_info.get("tournament", match_info.get("league", ""))),
            "date":       match_info.get("date", ""),
            "url":        match_info.get("full_url", match_info.get("url", "")),
            "status":              match_info.get("status", ""),
            "score": {
                "home": match_info.get("home_score", ""),
                "away": match_info.get("away_score", ""),
                "winner": "",
            },
            "odds":       odds,
            "stats":      [],
            "stats_source": "",
            "scraped_at": now_iso(),
        }

    return {
        "sport":      sport,
        "id":         match_info["id"],
        "home":       match_info.get("home", ""),
        "away":       match_info.get("away", ""),
        "tournament": match_info.get("league_name", match_info.get("tournament", match_info.get("league", ""))),
        "round":      "",
        "date":       match_info.get("date", ""),
        "url":        match_info.get("full_url", match_info.get("url", "")),
        "home_rank":  "",
        "away_rank":  "",
        "category":   "",
        "status":              match_info.get("status", ""),
        "winner":              "",
        "result_unavailable":  False,
        "home_sets":           "",
        "away_sets":           "",
        "set_scores":          None,
        "odds":                odds,
        "live_odds":  [],
        "stats":      [],
        "point_by_point": [],
        "overall_stats": {"tabs": []},
        "scraped_at": now_iso(),
    }
