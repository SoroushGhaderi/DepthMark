"""Event discovery – collect all match links from Oddspedia listing pages.

Strategy:
  1. Navigate to the sport listing page and wait for Cloudflare.
  2. Dismiss the cookie popup.
  3. Navigate to the target date using the calendar date picker.
  4. Fall back to arrow buttons (← / →) if calendar selection fails.
  5. Read all match pages via the Sport Vue component's loadNextPage().
  6. Fall back to match-poll Vuex extraction if the API call fails.
"""

import re
import time
from dataclasses import dataclass, field
from datetime import datetime

from src.oddspedia.config import BASE_URL, get_sport_listing_url, normalize_sport
from src.oddspedia.utils import safe_get
from src.oddspedia.logging import get_logger
from src.oddspedia.metrics import get_metrics
from selenium.common.exceptions import WebDriverException

logger = get_logger(__name__)

DOM_RECONCILIATION_MIN_COVERAGE = 0.80


@dataclass
class DiscoveryResult:
    """The accepted-or-recoverable outcome of one football listing read."""

    matches: dict = field(default_factory=dict)
    expected_pages: int = 0
    observed_pages: int = 0
    anomalies: list = field(default_factory=list)
    dom_count: int = 0

    @property
    def complete(self) -> bool:
        return bool(self.matches) and not self.anomalies and self.observed_pages >= self.expected_pages

    def to_dict(self) -> dict:
        return {
            "complete": self.complete,
            "expected_pages": self.expected_pages,
            "observed_pages": self.observed_pages,
            "match_count": len(self.matches),
            "dom_count": self.dom_count,
            "anomalies": list(self.anomalies),
        }


# These are navigation labels rendered inside every match card, not competition
# names.  Treating them as league data silently corrupts otherwise usable match
# links (for example, hundreds of records labelled simply "Odds").
_NON_LEAGUE_LABELS = {"odds", "prediction", "predictions", "tips", "stats"}


def _is_league_name(value):
    """Return whether *value* is a plausible competition label."""
    if not isinstance(value, str):
        return False
    value = " ".join(value.split())
    if not value or value.casefold() in _NON_LEAGUE_LABELS:
        return False
    # A status followed by a score and both teams is card content, not a title.
    return not re.match(r"^(?:FT|HT|AET|PEN)\b.*\b\d+\s+\d+\b", value, re.IGNORECASE)


def _match_league_name(match):
    """Return a league name from the variants used by Oddspedia listing data."""
    if not isinstance(match, dict):
        return ""

    keys = (
        "league_name", "league", "tournament", "competition",
        "leagueName", "tournament_name", "competition_name",
    )
    name_keys = ("name", "title", "league_name", "league", "tournament", "competition")
    for key in keys:
        value = match.get(key)
        if _is_league_name(value):
            return value.strip()
        if isinstance(value, dict):
            for name_key in name_keys:
                name = value.get(name_key)
                if _is_league_name(name):
                    return name.strip()
    return ""


def _match_country(match):
    """Return the country/category label carried by Oddspedia match data."""
    if not isinstance(match, dict):
        return ""

    keys = ("country_name", "country", "category_name", "category", "region_name")
    for key in keys:
        value = match.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
        if isinstance(value, dict):
            for name_key in ("name", "title", "country_name", "category_name"):
                name = value.get(name_key)
                if isinstance(name, str) and name.strip():
                    return name.strip()
    return ""


def _match_country_slug(match):
    """Return Oddspedia's country/category slug, if its display name is absent."""
    if not isinstance(match, dict):
        return ""
    for key in ("country_slug", "category_slug", "region_slug"):
        value = match.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _normalize_match_status(value):
    """Normalize a scraped match status to a compact uppercase token."""
    if value is None:
        return ""
    if isinstance(value, (dict, list, tuple)):
        return ""
    text = str(value).strip()
    if not text:
        return ""
    if text[0] in "[{":
        return ""
    if "://" in text:
        text = text.rstrip("/").rsplit("/", 1)[-1]
    return re.sub(r"[^A-Za-z0-9]+", "", text).upper()


_ALLOWED_FINAL_STATUSES = {"FT", "OT", "PEN", "AET"}
_BLOCKED_STATUSES = {"POSTPONED", "CANCELLED", "CANCELED", "ABANDONED", "SUSPENDED", "DELAYED"}


def _is_full_time_match(match):
    """Return True when a match record is explicitly marked as full time."""
    if not isinstance(match, dict):
        return False
    status = _listing_status_token(match)
    return status in _ALLOWED_FINAL_STATUSES


def _listing_status_token(match):
    """Return the best available listing status token for a raw match item."""
    if not isinstance(match, dict):
        return ""

    raw_status = _normalize_match_status(match.get("status"))
    if raw_status:
        return raw_status

    candidates = [
        match.get("match_status"),
        match.get("match_status_code"),
        match.get("inplay_status"),
        match.get("postmatch_status"),
        match.get("special_status"),
        match.get("status_reason"),
        match.get("matchStatus"),
        match.get("eventStatus"),
        match.get("raw_status"),
    ]
    for candidate in candidates:
        status = _normalize_match_status(candidate)
        if status:
            return status

    try:
        if int(match.get("matchstatus")) == 8:
            return "PEN"
    except (TypeError, ValueError):
        pass

    # The raw `status` field on listing data is often a score payload, not a
    # terminal state. Ignore it for status classification.
    return ""


def _clean_player_name(name):
    """Clean player name - remove extra spaces, special chars."""
    if not name:
        return ""
    name = re.sub(r'\s+', ' ', name.strip())
    name = re.sub(r'[^\w\s\.\-\']', '', name)
    return name.strip()


def _clean_match_data(matches):
    """Clean home/away names and normalize data."""
    if not isinstance(matches, dict):
        return matches
    for key, m in matches.items():
        if not isinstance(m, dict):
            continue
        if m.get("home"):
            m["home"] = _clean_player_name(m["home"])
        if m.get("away"):
            m["away"] = _clean_player_name(m["away"])
        if m.get("homeSlug"):
            m["homeSlug"] = m["homeSlug"].strip()
        if m.get("awaySlug"):
            m["awaySlug"] = m["awaySlug"].strip()
    return matches


def listing_source_dates(matches):
    """Return calendar dates evidenced by listing records, in YYYYMMDD form."""
    values = matches.values() if isinstance(matches, dict) else matches or []
    dates = set()
    for match in values:
        if not isinstance(match, dict):
            continue
        raw = str(match.get("date") or match.get("md") or "").strip()
        if len(raw) >= 10 and raw[:10].count("-") == 2:
            dates.add(raw[:10].replace("-", ""))
        elif len(raw) >= 8 and raw[:8].isdigit():
            dates.add(raw[:8])
    return dates


def listing_matches_target_date(matches, target_date):
    """Whether the rendered listing contains at least one event for its target date."""
    target = str(target_date).replace("-", "")[:8]
    return target in listing_source_dates(matches)


def _dismiss_cookie_popup(driver):
    driver.execute_script("""
        var btns = document.querySelectorAll('button');
        for (var i = 0; i < btns.length; i++) {
            if (btns[i].textContent.trim().indexOf('Accept All') >= 0) {
                btns[i].click(); return;
            }
        }
    """)
    time.sleep(0.5)


_JS_DATE_NAV_DEBUG = """
    var dateBtn = document.querySelector('.flex.align-items-center.p-0');
    if (!dateBtn) return {found: false, error: 'no .flex.align-items-center.p-0 element'};

    function describeEl(el) {
        if (!el) return null;
        var childInfo = Array.from(el.children || []).map(function(c) {
            return c.tagName + '[' + c.className.substring(0, 80) + ']';
        });
        return {tag: el.tagName, cls: el.className.substring(0, 120), children: childInfo};
    }

    var ancestors = [];
    var el = dateBtn;
    for (var i = 0; i < 5; i++) {
        el = el.parentElement;
        if (!el) break;
        var btns = el.querySelectorAll('button');
        var links = el.querySelectorAll('a');
        ancestors.push({
            level: i + 1,
            el: describeEl(el),
            btnCount: btns.length,
            linkCount: links.length
        });
        if (btns.length >= 2 || links.length >= 2) break;
    }
    return {found: true, dateBtn: describeEl(dateBtn), ancestors: ancestors};
"""


def _debug_date_nav(driver):
    """Log the DOM structure around the date navigation bar."""
    import json
    result = driver.execute_script(_JS_DATE_NAV_DEBUG)
    logger.warning("date_nav_dom_dump", dom_structure=json.dumps(result, indent=2))
    return result


# Fallback: extract from match-poll Vuex store (only covers ~5 featured matches)
_JS_EXTRACT_VUEX_FALLBACK = """
    var results = [];
    var seen = {};
    var origin = window.location.origin;
    var sportSlug = arguments[0] || 'tennis';
    function toSlug(name) {
        return (name || '').toLowerCase()
            .replace(/[éèêë]/g,'e').replace(/[àâä]/g,'a').replace(/[ùûü]/g,'u')
            .replace(/[óôö]/g,'o').replace(/[íî]/g,'i').replace(/[ç]/g,'c')
            .replace(/[ñ]/g,'n').replace(/[ý]/g,'y')
            .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    }
    try {
        var mp = document.querySelector('#__nuxt').__vue__.$store.state['match-poll'];
        var ov = (mp.pollData || mp.data || mp).overview || [];
        ov.forEach(function(entry) {
            var m = (entry && entry.match) ? entry.match : entry;
            if (!m || !m.id || seen[m.id]) return;
            seen[m.id] = true;
            var hs = m.ht_slug || toSlug(m.ht || '');
            var as = m.at_slug || toSlug(m.at || '');
            var urlId = m.sr_id || m.id;
            var slug = (hs && as) ? (hs + '-' + as + '-' + urlId) : String(urlId);
            var path = '/' + sportSlug + '/' + slug;
            results.push({matchId: String(m.id), matchKey: slug,
                home: m.ht||'', away: m.at||'', league: m.league_name||'',
                date: m.md||'', url: path, full_url: origin+path});
        });
    } catch(e) {}
    return results;
"""

_MONTH_ABBR = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}


def _read_displayed_date(driver):
    """Return the date currently shown in the page's date picker, or None."""
    text = driver.execute_script("""
        var el = document.querySelector('.flex.align-items-center.p-0');
        return el ? el.innerText.trim() : null;
    """)
    if not text:
        return None
    m = re.search(r'(\d{1,2})\s+([A-Za-z]+)|([A-Za-z]+)\s+(\d{1,2})', text)
    if not m:
        return None
    if m.group(1):
        day, mon_str = int(m.group(1)), m.group(2).lower()[:3]
    else:
        day, mon_str = int(m.group(4)), m.group(3).lower()[:3]
    month = _MONTH_ABBR.get(mon_str)
    if not month:
        return None
    year = datetime.now().year
    try:
        return datetime(year, month, day).date()
    except ValueError:
        return None


def _navigate_to_date(driver, target_date_str):
    """Navigate to target_date_str (YYYYMMDD).

    Tries the calendar date picker first (active calendar container class:
    `match-list-date-picker__calendar-active my-0 sm:mx-200`), then falls back
    to arrow-based navigation with correction clicks.
    """
    target = datetime.strptime(target_date_str, "%Y%m%d").date()

    selected_by_calendar = driver.execute_script("""
        var targetIso = arguments[0];
        var d = Number(targetIso.slice(8, 10));
        var pretty = targetIso.replace(/-/g, '/');

        function isVisible(el) {
            if (!el) return false;
            var s = window.getComputedStyle(el);
            if (!s || s.display === 'none' || s.visibility === 'hidden') return false;
            var r = el.getBoundingClientRect();
            return r.width > 0 && r.height > 0;
        }

        function clickDateTrigger() {
            var trigger = document.querySelector('.flex.align-items-center.p-0')
                || document.querySelector('[class*=\"match-list-date-picker\"] button')
                || document.querySelector('[class*=\"date-picker\"] button')
                || document.querySelector('[class*=\"calendar\"] button');
            if (!trigger) return false;
            try { trigger.click(); return true; } catch (e) { return false; }
        }

        function getCalendarRoot() {
            return document.querySelector('.match-list-date-picker__calendar-active.my-0.sm\\\\:mx-200')
                || document.querySelector('[class*=\"match-list-date-picker__calendar-active\"]')
                || document.querySelector('[class*=\"calendar-active\"]')
                || document.querySelector('[class*=\"match-list-date-picker__calendar\"]');
        }

        function isEnabledDay(el) {
            if (!el || !isVisible(el)) return false;
            if (el.disabled) return false;
            var cls = (el.className || '').toString().toLowerCase();
            if (/disabled|inactive|outside|other-month|unavailable/.test(cls)) return false;
            return true;
        }

        function clickMatchingDay(root) {
            if (!root) return 'no-calendar';
            var selectors = [
                '[data-date=\"' + targetIso + '\"]',
                '[data-day=\"' + d + '\"]',
                '[datetime^=\"' + targetIso + '\"]',
                '[aria-label*=\"' + targetIso + '\"]',
                '[aria-label*=\"' + pretty + '\"]'
            ];
            for (var i = 0; i < selectors.length; i++) {
                var exact = root.querySelectorAll(selectors[i]);
                for (var j = 0; j < exact.length; j++) {
                    if (!isEnabledDay(exact[j])) continue;
                    exact[j].click();
                    return 'picked-exact';
                }
            }

            var candidates = root.querySelectorAll('button, a, td, div, span');
            for (var k = 0; k < candidates.length; k++) {
                var txt = (candidates[k].textContent || '').trim();
                if (txt !== String(d)) continue;
                if (!isEnabledDay(candidates[k])) continue;
                candidates[k].click();
                return 'picked-by-day';
            }
            return 'no-day-match';
        }

        function setInputDateDirectly() {
            var container = document.querySelector('.match-list-date-picker__calendar-active')
                || document.querySelector('[class*="match-list-date-picker__calendar-active"]')
                || document.querySelector('[class*="match-list-date-picker"]');
            if (!container) return 'no-container';

            var input = container.querySelector('input[type="text"], input');
            if (!input) return 'no-input';

            try {
                input.removeAttribute('readonly');
                input.value = targetIso;
                input.setAttribute('value', targetIso);
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
                input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', bubbles: true }));
                return 'input-set';
            } catch (e) {
                return 'input-set-error:' + e.message;
            }
        }

        function setDateViaVue() {
            function findVm(vm, depth, matcher) {
                if (!vm || depth <= 0) return null;
                if (matcher(vm)) return vm;
                for (var i = 0; i < (vm.$children || []).length; i++) {
                    var hit = findVm(vm.$children[i], depth - 1, matcher);
                    if (hit) return hit;
                }
                return null;
            }
            try {
                var rootEl = document.querySelector('#__nuxt');
                if (!rootEl || !rootEl.__vue__) return 'vue-root-missing';
                var vm = findVm(rootEl.__vue__, 18, function(v) {
                    var n = (v.$options && v.$options.name) ? v.$options.name.toLowerCase() : '';
                    return n.indexOf('date') >= 0 || n.indexOf('picker') >= 0;
                });
                if (!vm) return 'vue-picker-missing';

                var dt = new Date(targetIso + 'T12:00:00');
                if (vm.setDate) { vm.setDate(dt); return 'vue-setDate'; }
                if (vm.onDateChange) { vm.onDateChange(dt); return 'vue-onDateChange'; }
                if (vm.selectDate) { vm.selectDate(dt); return 'vue-selectDate'; }
                if (vm.updateDate) { vm.updateDate(dt); return 'vue-updateDate'; }
                if (vm.$emit) {
                    vm.$emit('input', targetIso);
                    vm.$emit('change', targetIso);
                    return 'vue-emit-change';
                }
                return 'vue-no-supported-method';
            } catch (e) {
                return 'vue-error:' + e.message;
            }
        }

        if (!clickDateTrigger()) return 'no-trigger';
        var picked = 'no-calendar';
        for (var attempt = 0; attempt < 8; attempt++) {
            var root = getCalendarRoot();
            if (root && isVisible(root)) {
                picked = clickMatchingDay(root);
                if (picked.indexOf('picked-') === 0) return picked;
            }
            if (attempt === 0) {
                // Sometimes first click only focuses. Retry opening.
                clickDateTrigger();
            }
        }
        // last-resort: search globally for the day in visible "calendar-like" overlays
        var overlays = document.querySelectorAll('[class*=\"calendar\"], [class*=\"date-picker\"], [role=\"dialog\"]');
        for (var o = 0; o < overlays.length; o++) {
            if (!isVisible(overlays[o])) continue;
            var result = clickMatchingDay(overlays[o]);
            if (result.indexOf('picked-') === 0) return result + '-global';
        }

        // No clickable day found in DOM calendar; try controlled input / Vue API.
        var inputRes = setInputDateDirectly();
        if (inputRes === 'input-set') return inputRes;

        var vueRes = setDateViaVue();
        if (vueRes.indexOf('vue-') === 0 && vueRes !== 'vue-no-supported-method' && vueRes !== 'vue-picker-missing' && vueRes !== 'vue-root-missing') {
            return vueRes;
        }
        return picked + '|' + inputRes + '|' + vueRes;
    """, target.isoformat())

    if (
        str(selected_by_calendar).startswith("picked-")
        or str(selected_by_calendar).startswith("input-set")
        or str(selected_by_calendar).startswith("vue-")
    ):
        time.sleep(2)
        current = _read_displayed_date(driver)
        if current == target:
            logger.info("date_navigation_success_calendar", target_date=target_date_str, mode=str(selected_by_calendar))
            return True
        logger.warning(
            "calendar_pick_done_but_verification_failed",
            target_date=target_date_str,
            mode=str(selected_by_calendar),
            displayed_date=str(current) if current else None,
        )
    else:
        logger.warning(
            "calendar_pick_failed_falling_back_to_arrows",
            target_date=target_date_str,
            result=str(selected_by_calendar),
        )

    # Use the page's displayed date as the base — more reliable than datetime.now()
    page_date = _read_displayed_date(driver)
    today = page_date or datetime.now().date()
    if page_date:
        logger.info("current_date_displayed", date=str(page_date))
    else:
        logger.warning("could_not_read_page_date")

    offset = (target - today).days

    if offset == 0:
        logger.info("target_date_already_displayed", date=target_date_str)
        return True

    direction = "next" if offset > 0 else "prev"
    steps = abs(offset)
    logger.info("navigating_to_target_date", steps=steps, direction=direction, target_date=target_date_str)

    for step in range(steps):
        clicked = driver.execute_script("""
            var dir = arguments[0];

            // Find the date display element
            var dateBtn = document.querySelector('.flex.align-items-center.p-0');
            if (!dateBtn) return 'no-date-btn';

            // Walk up ancestors looking for the row that contains the arrow buttons
            var container = dateBtn.parentElement;
            var arrowEls = null;
            for (var lvl = 0; lvl < 6 && container; lvl++) {
                var btns = Array.from(container.querySelectorAll('button'));
                if (btns.length >= 2) { arrowEls = btns; break; }
                var links = Array.from(container.querySelectorAll('a'));
                if (links.length >= 2) { arrowEls = links; break; }
                // Also check for any element with an SVG child (icon buttons)
                var svgParents = Array.from(container.children).filter(function(c) {
                    return c.querySelector && c.querySelector('svg');
                });
                if (svgParents.length >= 2) { arrowEls = svgParents; break; }
                container = container.parentElement;
            }

            if (!arrowEls || arrowEls.length < 2) {
                // Last resort: try Vue component's date method
                try {
                    function findVm(vm, name, depth) {
                        if (depth <= 0) return null;
                        if (vm.$options && vm.$options.name === name) return vm;
                        for (var i = 0; i < (vm.$children || []).length; i++) {
                            var r = findVm(vm.$children[i], name, depth - 1);
                            if (r) return r;
                        }
                        return null;
                    }
                    var root = document.querySelector('#__nuxt').__vue__;
                    // Try generic names for the date-picker component
                    var vm = findVm(root, 'SportDatePicker', 15)
                           || findVm(root, 'DatePicker', 15)
                           || findVm(root, 'Sport', 15);
                    if (vm) {
                        if (dir === 'prev' && vm.prevDay) { vm.prevDay(); return 'vue-prevDay'; }
                        if (dir === 'next' && vm.nextDay) { vm.nextDay(); return 'vue-nextDay'; }
                        if (dir === 'prev' && vm.goToPrevDay) { vm.goToPrevDay(); return 'vue-goToPrevDay'; }
                        if (dir === 'next' && vm.goToNextDay) { vm.goToNextDay(); return 'vue-goToNextDay'; }
                        // Dump method names for debugging
                        return 'vue-no-day-method:' + Object.keys(vm).filter(function(k){ return /day|date|prev|next/i.test(k); }).join(',');
                    }
                } catch(e) { return 'vue-error:' + e.message; }
                return 'no-arrows-found';
            }

            // Click the first element for prev, last for next
            // Filter out the date display button itself
            var candidates = arrowEls.filter(function(el) {
                return !el.classList.contains('p-0') || !el.classList.contains('flex');
            });
            if (candidates.length < 2) candidates = arrowEls;

            if (dir === 'prev') {
                candidates[0].click();
            } else {
                candidates[candidates.length - 1].click();
            }
            return 'ok:' + candidates[0].tagName + 'x' + candidates.length;
        """, direction)

        if not str(clicked).startswith("ok") and not str(clicked).startswith("vue-"):
            logger.warning("date_navigation_click_failed", step=step + 1, total_steps=steps, result=str(clicked))
            if step == 0:
                _debug_date_nav(driver)
            if clicked == "no-date-btn":
                logger.error("date_button_not_found")
                break
        else:
            logger.debug("date_navigation_click", step=step + 1, total_steps=steps, result=str(clicked))
        time.sleep(1.5)

    time.sleep(2)

    target_day = str(target.day)
    for correction in range(3):
        displayed = driver.execute_script("""
            var el = document.querySelector('.flex.align-items-center.p-0');
            return el ? el.innerText.trim() : null;
        """)
        current = _read_displayed_date(driver)
        logger.info(
            "date_navigation_check",
            displayed_text=displayed,
            target_date=target_date_str,
        )
        if current == target:
            logger.info("date_navigation_success")
            return True
        if current is None:
            if target_day in (displayed or ""):
                logger.info("date_navigation_success_by_day_number")
                return True
            logger.warning("date_verification_failed")
            return False
        delta = (target - current).days
        direction = "next" if delta > 0 else "prev"
        logger.warning(
            "date_correction_needed",
            offset_days=abs(delta),
            direction=direction,
            attempt=correction + 1,
        )
        driver.execute_script("""
            var dir = arguments[0];
            var dateBtn = document.querySelector('.flex.align-items-center.p-0');
            if (!dateBtn) return;
            var container = dateBtn.parentElement;
            for (var lvl = 0; lvl < 6 && container; lvl++) {
                var btns = Array.from(container.querySelectorAll('button'));
                if (btns.length >= 2) {
                    (dir === 'prev' ? btns[0] : btns[btns.length-1]).click();
                    return;
                }
                container = container.parentElement;
            }
        """, direction)
        time.sleep(1.5)

    logger.warning("date_navigation_failed", target_date=target_date_str)
    return False


_JS_SPORT_STATE = """
    function findSport(vm, depth) {
        if (depth <= 0 || !vm) return null;
        if (vm.$options && vm.$options.name === 'Sport') return vm;
        for (var i = 0; i < (vm.$children || []).length; i++) {
            var r = findSport(vm.$children[i], depth - 1);
            if (r) return r;
        }
        return null;
    }
    var rootEl = document.querySelector('#__nuxt');
    var sport = rootEl && rootEl.__vue__ ? findSport(rootEl.__vue__, 10) : null;
    if (!sport) return null;
    var list = sport.$data.matchList || [];
    var samples = list.slice(0, 3).map(function(m) {
        try { return JSON.parse(JSON.stringify(m)); } catch(e) { return {}; }
    });
    return {
        matchList:         list,
        currentPage:       sport.$data.currentPage,
        totalPages:        sport.$data.totalPages,
        nextPage:          sport.$data.nextPage,
        isLoadingNextPage: sport.$data.isLoadingNextPage,
        sampleMatches:     samples
    };
"""


def _fetch_all_matches(driver, sport="football", return_result=False):
    """Load all match pages via the Sport component's loadNextPage() method."""
    sport = normalize_sport(sport)
    metrics = get_metrics()
    state = driver.execute_script(_JS_SPORT_STATE)
    if not state or not state.get("matchList"):
        logger.warning("sport_component_not_found")
        result = DiscoveryResult(anomalies=["sport_component_not_found"])
        return result if return_result else result.matches

    try:
        total_pages = int(state.get("totalPages") or 1)
        current_page = int(state.get("currentPage") or 1)
    except (TypeError, ValueError):
        logger.warning(
            "invalid_listing_pagination_state",
            total_pages=state.get("totalPages"),
            current_page=state.get("currentPage"),
        )
        total_pages = current_page = 1
    observed_pages = current_page
    anomalies = []
    logger.info("page_loaded", page=1, matches=len(state["matchList"]), total_pages=total_pages)

    previous_len = len(state["matchList"])
    for page_num in range(current_page + 1, min(total_pages + 1, 41)):
        try:
            driver.execute_script("""
                function findSport(vm, depth) {
                    if (depth <= 0 || !vm) return null;
                    if (vm.$options && vm.$options.name === 'Sport') return vm;
                    for (var i = 0; i < (vm.$children||[]).length; i++) {
                        var r = findSport(vm.$children[i], depth-1); if (r) return r;
                    }
                    return null;
                }
                var sport = findSport(document.querySelector('#__nuxt').__vue__, 10);
                if (sport && sport.loadNextPage) sport.loadNextPage();
            """)
            new_state = None
            for _ in range(30):
                time.sleep(0.2)
                candidate = driver.execute_script(_JS_SPORT_STATE) or {}
                candidate_len = len(candidate.get("matchList") or [])
                if candidate_len > previous_len:
                    new_state = candidate
                    break
                try:
                    candidate_page = int(candidate.get("currentPage") or 0)
                except (TypeError, ValueError):
                    candidate_page = 0
                if not candidate.get("isLoadingNextPage") and candidate_page >= page_num:
                    new_state = candidate
                    break
            new_state = new_state or driver.execute_script(_JS_SPORT_STATE)
            new_len = len(new_state.get("matchList", [])) if new_state else 0
            try:
                observed_page = int((new_state or {}).get("currentPage") or 0)
            except (TypeError, ValueError):
                observed_page = 0
            logger.info("page_loaded", page=page_num, matches=new_len)
            if new_len <= previous_len:
                logger.warning(
                    "load_next_page_no_growth",
                    page=page_num,
                    previous_matches=previous_len,
                    current_matches=new_len,
                    current_page=observed_page,
                )
                if observed_page < page_num:
                    anomalies.append("pagination_stalled")
                    break
                continue
            previous_len = new_len
            observed_pages = max(observed_pages, observed_page)
        except WebDriverException as e:
            logger.warning("load_next_page_failed", page=page_num, error=str(e))
            metrics.record_scrape_error(f"page_load_failed_{page_num}")
            anomalies.append("page_load_failed")
            break

    # Read final matchList
    final_state = driver.execute_script(_JS_SPORT_STATE)
    all_raw = (final_state or {}).get("matchList", [])

    # Log sample match fields to help identify the correct URL-id field
    samples = (final_state or {}).get("sampleMatches", [])
    if samples:
        import json as _json
        first = samples[0]
        logger.debug("sample_match_keys", keys=list(first.keys()))
        url_like = {k: v for k, v in first.items()
                    if any(kw in k.lower() for kw in ('id', 'url', 'path', 'slug', 'key', 'link'))}
        logger.debug("sample_match_url_fields", fields=_json.dumps(url_like))

    matches = {}
    for m in all_raw:
        mid = str(m.get("id", ""))
        if not mid or mid in matches:
            continue
        hs = m.get("ht_slug") or m.get("ht_slug_en") or m.get("hs") or ""
        as_ = m.get("at_slug") or m.get("at_slug_en") or m.get("as") or ""

        is_archived = bool(m.get("is_match_archived"))

        # match_key is the ID Oddspedia uses in its URL paths (different from the
        # internal 'id'). Archived matches use /a/{sport}/ with away-home slug order.
        match_key = m.get("match_key")
        url_id = match_key or (
            m.get("sr_id") or
            m.get("eid") or
            m.get("external_id") or
            m.get("event_id") or
            m.get("url_id") or
            m.get("sid") or
            m.get("match_id") or
            m.get("id", mid)
        )

        # If a direct URL or path is stored on the match item, prefer that
        direct_path = m.get("url") or m.get("path") or m.get("match_url") or m.get("link") or ""
        sport_path = f"/{sport}/"
        archived_sport_path = f"/a/{sport}/"
        if direct_path and (direct_path.startswith(sport_path) or direct_path.startswith(archived_sport_path)):
            path = direct_path
            slug = re.sub(rf'^/(?:a/)?{re.escape(sport)}/', '', direct_path)
        elif is_archived:
            # Archived completed matches: /a/{sport}/{at_slug}-{ht_slug}-{match_key}
            slug = f"{as_}-{hs}-{url_id}" if hs and as_ else str(url_id)
            path = f"/a/{sport}/{slug}"
        else:
            # Live / upcoming matches: /{sport}/{ht_slug}-{at_slug}-{id}
            slug = f"{hs}-{as_}-{url_id}" if hs and as_ else str(url_id)
            path = f"/{sport}/{slug}"

        matches[mid] = {
            "matchId":  mid,
            "matchKey": slug,
            "home":     m.get("ht", ""),
            "away":     m.get("at", ""),
            "league_name": _match_league_name(m),
            "league_slug": (m.get("league_slug") or m.get("tournament_slug") or "").strip(),
            "country":  _match_country(m),
            "country_slug": _match_country_slug(m),
            "date":     m.get("md", ""),
            "status":   _listing_status_token(m),
            "url":      path,
            "full_url": BASE_URL + path,
        }

    # --- Enrich URLs from rendered DOM <a href> links ---
    # The DOM <a href="/{sport}/slug-SRID"> links carry the correct Sportradar ID
    # in the URL, unlike the Vuex matchList which only has the internal match ID.
    dom_links = _extract_dom_links(driver, sport=sport)

    dom_count = len(dom_links)
    dom_coverage = dom_count / len(matches) if matches else 0.0
    if dom_links and dom_coverage >= DOM_RECONCILIATION_MIN_COVERAGE:
        sample_ids = [int(info["numericId"]) for info in list(dom_links.values())[:5]]
        archived_count = sum(1 for info in dom_links.values() if info.get("archived"))
        logger.info(
            "dom_links_extracted",
            total=len(dom_links),
            archived=archived_count,
            sample_ids=sample_ids,
        )

        slug_to_info = {info["slug"]: info for info in dom_links.values()}
        slug_to_path = {slug: info["path"] for slug, info in slug_to_info.items()}
        slug_to_status = {info["slug"]: _normalize_match_status(info.get("status")) for info in dom_links.values() if info.get("status")}
        path_to_status = {info["path"]: _normalize_match_status(info.get("status")) for info in dom_links.values() if info.get("status")}

        dom_wordsets = {}
        for dom_slug, dom_path in slug_to_path.items():
            prefix = re.sub(r'-\d+$', '', dom_slug)
            words = frozenset(prefix.split('-')) if prefix else None
            if words:
                dom_wordsets[words] = (dom_slug, dom_path)

        corrected = 0
        unmatched = 0
        for mid, m in matches.items():
            old_slug = m.get("matchKey", "")
            if old_slug in slug_to_path:
                if not m.get("status"):
                    m["status"] = slug_to_status.get(old_slug, "")
                continue

            prefix = re.sub(r'-\d+$', '', old_slug)

            matched_slug, matched_path = None, None
            for dom_slug, dom_path in slug_to_path.items():
                if re.sub(r'-\d+$', '', dom_slug) == prefix:
                    matched_slug, matched_path = dom_slug, dom_path
                    break

            if matched_slug is None and prefix:
                words = frozenset(prefix.split('-'))
                if words in dom_wordsets:
                    matched_slug, matched_path = dom_wordsets[words]

            if matched_slug is not None:
                m["matchKey"] = matched_slug
                m["url"] = matched_path
                m["full_url"] = BASE_URL + matched_path
                if not m.get("status"):
                    m["status"] = slug_to_status.get(matched_slug, "") or path_to_status.get(matched_path, "")
                corrected += 1
            else:
                unmatched += 1

        for m in matches.values():
            if m.get("status"):
                continue
            dom_status = path_to_status.get(m.get("url", "")) or slug_to_status.get(m.get("matchKey", ""))
            if dom_status:
                m["status"] = dom_status

        _merge_league_names(matches, dom_links)

        if corrected:
            logger.info(
                "urls_corrected",
                corrected=corrected,
                total=len(matches),
                unmatched=unmatched,
            )
        elif unmatched:
            logger.warning(
                "dom_cross_reference_no_match",
                unmatched=unmatched,
            )
        else:
            logger.info(
                "dom_cross_reference_all_matched",
                total=len(matches),
            )
    else:
        logger.info(
            "dom_validation_sampled",
            dom_count=dom_count,
            listing_count=len(matches),
            coverage=round(dom_coverage, 3),
            reconciliation_skipped=True,
        )

    final_state = final_state or {}
    try:
        observed_pages = max(observed_pages, int(final_state.get("currentPage") or 0))
    except (TypeError, ValueError):
        pass
    if observed_pages < total_pages and "pagination_stalled" not in anomalies:
        anomalies.append("pagination_incomplete")
    result = DiscoveryResult(
        matches=matches,
        expected_pages=total_pages,
        observed_pages=observed_pages,
        anomalies=anomalies,
        dom_count=dom_count,
    )
    logger.info("matches_collected", count=len(matches), expected_pages=total_pages, observed_pages=observed_pages, complete=result.complete)
    return result if return_result else result.matches


_JS_EXTRACT_DOM_LINKS = """
    // Extract all sport match links rendered in the DOM.
    // Live matches use /<sport>/<slug>-<id>
    // Past/archived matches use /a/<sport>/<slug>-<id>
    var links = {};
    var sportSlug = arguments[0] || 'tennis';
    var livePrefix = '/' + sportSlug + '/';
    var archivedPrefix = '/a/' + sportSlug + '/';
    var anchors = document.querySelectorAll(
        'a[href^="' + livePrefix + '"], a[href^="' + archivedPrefix + '"]'
    );

    function isVisible(el) {
        if (!el) return false;
        var s = window.getComputedStyle(el);
        if (!s || s.display === 'none' || s.visibility === 'hidden') return false;
        var r = el.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
    }

    function getCardRoot(anchor) {
        var root = null;
        try {
            root = anchor.closest('.game-list-item.relative.bg-white');
        } catch (e) {}
        if (!root) {
            var node = anchor;
            for (var depth = 0; depth < 8 && node; depth++) {
                if (node.classList && node.classList.contains('game-list-item')) {
                    root = node;
                    break;
                }
                node = node.parentElement;
            }
        }
        return root;
    }

    function findStatusText(root) {
        if (!root) return '';
        var statusEls = root.querySelectorAll('.match-state .match-status, .match-status');
        for (var s = 0; s < statusEls.length; s++) {
            var statusEl = statusEls[s];
            if (statusEl && isVisible(statusEl)) {
                var text = (statusEl.textContent || '').replace(/\\s+/g, ' ').trim();
                if (text) return text;
            }
        }
        return '';
    }

    function extractScores(root) {
        var scoreWrap = root ? root.querySelector('.game-score') : null;
        if (!scoreWrap) return {};

        function pull(teamWrap) {
            if (!teamWrap) return {score: '', penalties: ''};
            var scoreEl = teamWrap.querySelector('.game-score-result span');
            var penaltyEl = teamWrap.querySelector('.game-score-result sup');
            return {
                score: scoreEl ? (scoreEl.textContent || '').replace(/\\s+/g, ' ').trim() : '',
                penalties: penaltyEl ? (penaltyEl.textContent || '').replace(/\\s+/g, ' ').trim() : ''
            };
        }

        var home = pull(scoreWrap.querySelector('.game-score__team--home'));
        var away = pull(scoreWrap.querySelector('.game-score__team--away'));
        var meta = {};
        if (home.score) meta.home_score = home.score;
        if (away.score) meta.away_score = away.score;
        if (home.penalties) meta.home_penalties = home.penalties;
        if (away.penalties) meta.away_penalties = away.penalties;
        return meta;
    }

    function extractOdds(root) {
        var oddsWrap = root ? root.querySelector('.game-list-odds-with-waynames') : null;
        if (!oddsWrap) return {};
        var values = oddsWrap.querySelectorAll('.odd-box__value');
        if (!values || values.length < 2) return {};

        function txt(el) {
            return el ? (el.textContent || '').replace(/\\s+/g, ' ').trim() : '';
        }

        var meta = {};
        if (values.length >= 3) {
            meta.home_odds = txt(values[0]);
            meta.draw_odds = txt(values[1]);
            meta.away_odds = txt(values[2]);
        } else if (values.length === 2) {
            meta.home_odds = txt(values[0]);
            meta.away_odds = txt(values[1]);
        }
        return meta;
    }

    function extractWinner(root) {
        var label = root ? root.querySelector('.match-list-winner-label') : null;
        if (!label) return {};

        var meta = {
            winner_label: (label.textContent || '').replace(/\\s+/g, ' ').trim()
        };

        var row = null;
        try {
            row = label.closest('.team-names-stack__row');
        } catch (e) {}
        if (!row && root) {
            var rows = root.querySelectorAll('.team-names-stack__row');
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].contains(label)) {
                    row = rows[i];
                    break;
                }
            }
        }
        if (row && root) {
            var rows = Array.from(root.querySelectorAll('.team-names-stack__row'));
            var idx = rows.indexOf(row);
            if (idx === 0) meta.winner_side = 'home';
            else if (idx === 1) meta.winner_side = 'away';
        }
        return meta;
    }

    function extractLogos(root) {
        var meta = {};
        if (!root) return meta;
        var rows = root.querySelectorAll('.team-names-stack__row');
        if (rows.length > 0) {
            var homeImg = rows[0].querySelector('img');
            if (homeImg && homeImg.src) meta.home_logo_url = homeImg.src;
        }
        if (rows.length > 1) {
            var awayImg = rows[1].querySelector('img');
            if (awayImg && awayImg.src) meta.away_logo_url = awayImg.src;
        }
        return meta;
    }

    function extractListingMeta(root) {
        var meta = {};
        if (!root) return meta;

        var statusEl = root.querySelector('.match-state[match-status]');
        var statusCode = statusEl ? (statusEl.getAttribute('match-status') || '').replace(/\\s+/g, ' ').trim() : '';
        var statusText = findStatusText(root);
        if (statusText) meta.status = statusText;
        if (statusCode) meta.match_status_code = statusCode;

        [extractScores(root), extractOdds(root), extractWinner(root), extractLogos(root)].forEach(function(part) {
            Object.keys(part).forEach(function(key) {
                if (part[key] !== '' && part[key] !== null && part[key] !== undefined) {
                    meta[key] = part[key];
                }
            });
        });

        return meta;
    }

    function textOf(el) {
        return el ? (el.textContent || '').replace(/\\s+/g, ' ').trim() : '';
    }

    function looksLikeMatchPath(path) {
        // Detail-page routes may have an extra /odds, /predictions, or /tips
        // segment.  They are still match links, never league headers.
        return new RegExp('^/(?:a/)?' + sportSlug + '/[a-z0-9-]+-\\d+(?:/|$)').test(path || '');
    }

    function isLeagueName(value) {
        var text = String(value || '').replace(/\\s+/g, ' ').trim();
        if (!text || /^(odds|prediction|predictions|tips|stats)$/i.test(text)) return false;
        return !/^(FT|HT|AET|PEN)\\b.*\\b\\d+\\s+\\d+\\b/i.test(text);
    }

    // League titles are rendered as a section header above a group of cards.
    // Archived cards often lack league_name in Vuex and JSON-LD, so collect
    // that header while the listing DOM is available.
    function findLeagueName(root) {
        if (!root) return '';
        var selectors = [
            '[data-league-name]', '[data-tournament-name]', '[data-competition-name]',
            '[class*="league-name"]', '[class*="league-title"]',
            '[class*="tournament-name"]', '[class*="tournament-title"]',
            '[class*="competition-name"]', '[class*="competition-title"]'
        ].join(',');
        var node = root;
        for (var depth = 0; depth < 7 && node; depth++, node = node.parentElement) {
            var labelled = node.querySelector ? node.querySelector(selectors) : null;
            var labelledText = textOf(labelled);
            if (isLeagueName(labelledText)) return labelledText;

            var sibling = node.previousElementSibling;
            for (var siblingDepth = 0; siblingDepth < 4 && sibling; sibling = sibling.previousElementSibling, siblingDepth++) {
                var header = sibling.matches && sibling.matches(selectors) ? sibling :
                    (sibling.querySelector ? sibling.querySelector(selectors) : null);
                var headerText = textOf(header);
                if (isLeagueName(headerText)) return headerText;

                // Some listing versions use an unclassed league link as the
                // section heading. Exclude links that themselves are matches.
                var links = sibling.querySelectorAll ? sibling.querySelectorAll('a[href]') : [];
                for (var i = 0; i < links.length; i++) {
                    var href = links[i].getAttribute('href') || '';
                    if (href.indexOf('/' + sportSlug + '/') >= 0 && !looksLikeMatchPath(href)) {
                        var linkText = textOf(links[i]);
                        if (isLeagueName(linkText)) return linkText;
                    }
                }
            }
        }
        return '';
    }

    function competitionContext(root) {
        if (!root) return {};
        // A .game-list-headline precedes each competition's group of match
        // cards. Its breadcrumb is [country/category, competition]. This is
        // available on the date listing, including historical/archive cards.
        var node = root;
        var headline = null;
        for (var ancestorDepth = 0; ancestorDepth < 8 && node && !headline; ancestorDepth++) {
            var sibling = node;
            for (var siblingDepth = 0; siblingDepth < 100 && sibling; siblingDepth++, sibling = sibling.previousElementSibling) {
                if (sibling.classList && sibling.classList.contains('game-list-headline')) {
                    headline = sibling;
                    break;
                }
            }
            node = node.parentElement;
        }
        if (!headline) return {};

        var items = headline.querySelectorAll('[aria-label="Breadcrumbs"] .breadcrumbs__item');
        if (!items || items.length < 2) return {};
        var country = textOf(items[0]);
        var leagueLink = items[1].querySelector('a[title]');
        var league = leagueLink ? (leagueLink.getAttribute('title') || '') : textOf(items[1]);
        var href = leagueLink ? (leagueLink.getAttribute('href') || '') : '';
        var context = {};
        if (isLeagueName(league)) context.league = league;
        if (country) context.country = country;
        if (href) {
            var parts = href.replace(/^\\/+|\\/+$/g, '').split('/');
            if (parts.length >= 3 && parts[0] === sportSlug) {
                context.country_slug = parts[1];
                context.league_slug = parts.slice(2).join('/');
            }
        }
        return context;
    }

    for (var i = 0; i < anchors.length; i++) {
        var href = anchors[i].getAttribute('href');
        if (!href) continue;
        // Strip query string, hash fragment, and trailing slash
        var clean = href.split('?')[0].split('#')[0].replace(/\\/+$/, '');
        if (clean.indexOf(livePrefix) !== 0 && clean.indexOf(archivedPrefix) !== 0) continue;
        // Extract the trailing numeric ID from the slug
        var isArchived = clean.indexOf(archivedPrefix) === 0;
        var slug = isArchived
            ? clean.replace(archivedPrefix, '')
            : clean.replace(livePrefix, '');
        if (!/^[a-z0-9-]+-\\d+$/.test(slug)) continue;
        var parts = slug.split('-');
        var numericId = parts[parts.length - 1];
        if (!/^\\d+$/.test(numericId)) continue;
        var root = getCardRoot(anchors[i]) || anchors[i];
        var meta = extractListingMeta(root);
        var league = findLeagueName(root);
        if (league) meta.league = league;
        var context = competitionContext(root);
        Object.keys(context).forEach(function(key) {
            if (context[key]) meta[key] = context[key];
        });
        var base = links[numericId] || {path: clean, slug: slug, numericId: numericId, archived: isArchived};
        base.path = clean;
        base.slug = slug;
        base.numericId = numericId;
        base.archived = isArchived;
        Object.keys(meta).forEach(function(key) {
            if (meta[key] !== '' && meta[key] !== null && meta[key] !== undefined) {
                base[key] = meta[key];
            }
        });
        links[numericId] = base;
    }
    return links;
"""

_JS_EXTRACT_SPORTS_EVENT_LINKS = """
    var sportSlug = arguments[0] || 'football';
    var origin = window.location.origin;
    var matchRe = new RegExp('^/(?:a/)?' + sportSlug + '/([a-z0-9-]+-\\\\d+)$');
    var matches = {};

    function cleanText(value) {
        return (value || '').replace(/\\s+/g, ' ').trim();
    }

    function teamName(value) {
        if (!value) return '';
        if (typeof value === 'string') return cleanText(value);
        return cleanText(value.name || value.alternateName || '');
    }

    function isVisible(el) {
        if (!el) return false;
        var s = window.getComputedStyle(el);
        if (!s || s.display === 'none' || s.visibility === 'hidden') return false;
        var r = el.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
    }

    function findStatusText(anchor) {
        var node = anchor;
        for (var depth = 0; depth < 8 && node; depth++) {
            if (node.querySelector) {
                var statusEls = node.querySelectorAll('.match-status');
                for (var i = 0; i < statusEls.length; i++) {
                    var statusEl = statusEls[i];
                    if (statusEl && isVisible(statusEl)) {
                        var text = (statusEl.textContent || '').replace(/\\s+/g, ' ').trim();
                        if (text) return text;
                    }
                }
            }
            node = node.parentElement;
        }
        return '';
    }

    function addMatch(path, data, status) {
        if (!path) return;
        var clean = path.replace(origin, '').split('?')[0].split('#')[0].replace(/\\/+$/, '');
        var m = clean.match(matchRe);
        if (!m) return;
        var slug = m[1];
        if (slug.indexOf('/predictions') >= 0 || slug.indexOf('/tips') >= 0 || slug.indexOf('/odds') >= 0) return;
        var id = slug.split('-').pop();
        if (!/^\\d+$/.test(id)) return;
        var base = matches[id] || {
            matchId: id,
            matchKey: slug,
            home: '',
            away: '',
            league: '',
            date: '',
            url: clean,
            full_url: origin + clean
        };
        var incoming = data || {};
        Object.keys(incoming).forEach(function(key) {
            if (incoming[key] !== '' && incoming[key] !== null && incoming[key] !== undefined) {
                base[key] = incoming[key];
            }
        });
        if (status) base.status = status;
        matches[id] = base;
    }

    function addEvent(event) {
        if (!event || event['@type'] !== 'SportsEvent') return;
        var path = event.url || '';
        var home = teamName(event.homeTeam);
        var away = teamName(event.awayTeam);
        var name = cleanText(event.name || '');
        if ((!home || !away) && name.indexOf(' - ') > 0) {
            var parts = name.split(' - ');
            home = home || cleanText(parts[0]);
            away = away || cleanText(parts.slice(1).join(' - '));
        }
        addMatch(path, {
            home: home,
            away: away,
            league: teamName(event.superEvent) || teamName(event.organizer),
            date: event.startDate || '',
            status: cleanText(event.eventStatus || '')
        });
    }

    document.querySelectorAll('script[type="application/ld+json"]').forEach(function(script) {
        try {
            var parsed = JSON.parse(script.textContent || 'null');
            var queue = Array.isArray(parsed) ? parsed.slice() : [parsed];
            while (queue.length) {
                var item = queue.shift();
                if (!item) continue;
                if (Array.isArray(item)) {
                    queue = queue.concat(item);
                } else if (item['@graph']) {
                    queue = queue.concat(item['@graph']);
                } else {
                    addEvent(item);
                }
            }
        } catch (e) {}
    });

    document.querySelectorAll('a[href^="/' + sportSlug + '/"], a[href^="/a/' + sportSlug + '/"]').forEach(function(anchor) {
        var href = anchor.getAttribute('href') || '';
        var text = cleanText(anchor.textContent || '');
        if (!text || text.toLowerCase() === 'odds' || text.toLowerCase() === 'predictions') return;
        addMatch(href, {raw_text: text}, findStatusText(anchor));
    });

    return matches;
"""


def _extract_dom_links(driver, sport="football"):
    """Scrape all match <a href> links from the rendered page.

    Returns a dict keyed by the trailing numeric id in the URL (which is the sr_id
    for current-day matches, or the internal id for past matches).
    """
    try:
        links = driver.execute_script(_JS_EXTRACT_DOM_LINKS, normalize_sport(sport))
        logger.info("dom_links_extracted", sport=sport, count=len(links or {}))
        return links or {}
    except WebDriverException as exc:
        logger.warning("dom_links_extraction_failed", sport=sport, error=str(exc))
        return {}


def _extract_matches_from_sports_events(driver, sport="football"):
    """Extract listing matches from JSON-LD SportsEvent data and DOM links."""
    sport = normalize_sport(sport)
    try:
        matches = driver.execute_script(_JS_EXTRACT_SPORTS_EVENT_LINKS, sport) or {}
        logger.info("sports_event_matches_extracted", sport=sport, count=len(matches))
        return matches
    except WebDriverException as exc:
        logger.warning("sports_event_extraction_failed", sport=sport, error=str(exc))
        return {}


def _extract_matches_vuex(driver, sport="football"):
    """Fallback: read from match-poll Vuex store (limited to ~5 featured matches)."""
    sport = normalize_sport(sport)
    raw = driver.execute_script(_JS_EXTRACT_VUEX_FALLBACK, sport)
    logger.info("vuex_fallback_matches", sport=sport, count=len(raw))
    return {str(m["matchId"]): m for m in raw if m.get("matchId")}


def _build_urls(matches, sport="football"):
    sport = normalize_sport(sport)
    for m in matches.values():
        if m.get("url") and m.get("full_url"):
            if not m["full_url"].startswith("http"):
                m["full_url"] = BASE_URL + m["full_url"]
            continue
        match_key = m.get("matchKey", "")
        match_id = str(m.get("matchId", ""))
        if match_key and match_id:
            path = f"/{sport}/{match_key}-{match_id}"
        elif match_key:
            path = f"/{sport}/{match_key}"
        else:
            m["url"] = ""
            m["full_url"] = ""
            continue
        m["url"] = path
        m["full_url"] = BASE_URL + path


def _merge_league_names(matches, league_matches, overwrite=False):
    """Merge league names from an auxiliary extractor into listing matches.

    Structured SportsEvent metadata is authoritative and may replace a value
    inferred from the rendered card.  DOM-derived values only fill blanks.
    """
    if not isinstance(matches, dict) or not league_matches:
        return

    by_id = {}
    by_path = {}
    by_slug = {}
    by_event_identity = {}

    def event_identity(info):
        if not isinstance(info, dict):
            return None
        home = info.get("home") or info.get("ht") or ""
        away = info.get("away") or info.get("at") or ""
        date = str(info.get("date") or info.get("md") or "").strip()[:10]
        teams = sorted(
            re.sub(r"[^a-z0-9]+", "", str(team).casefold())
            for team in (home, away)
        )
        if not all(teams) or not date:
            return None
        return teams[0], teams[1], date
    for info in league_matches.values():
        if not isinstance(info, dict):
            continue
        league_name = _match_league_name(info)
        country = _match_country(info)
        country_slug = _match_country_slug(info)
        league_slug = (info.get("league_slug") or "").strip() if isinstance(info, dict) else ""
        if not league_name and not country and not country_slug and not league_slug:
            continue
        match_id = str(info.get("id") or info.get("matchId") or "").strip()
        path = (info.get("url") or info.get("path") or info.get("full_url") or "").strip()
        slug = (info.get("matchKey") or info.get("slug") or "").strip()
        context = {
            "league_name": league_name,
            "league_slug": league_slug,
            "country": country,
            "country_slug": country_slug,
        }
        if match_id:
            by_id[match_id] = context
        if path:
            by_path[path] = context
            if path.startswith(BASE_URL):
                by_path[path[len(BASE_URL):]] = context
        if slug:
            by_slug[slug] = context
        identity = event_identity(info)
        if identity:
            by_event_identity[identity] = context

    identity_matches = 0
    for match in matches.values():
        if not isinstance(match, dict):
            continue
        candidates = [
            str(match.get("id", "")),
            str(match.get("matchId", "")),
            match.get("url", ""),
            match.get("full_url", ""),
            match.get("matchKey", ""),
        ]
        context = {}
        for candidate in candidates:
            context = by_id.get(candidate) or by_path.get(candidate) or by_slug.get(candidate, {})
            if context:
                break
        if not context:
            context = by_event_identity.get(event_identity(match), {})
            if context:
                identity_matches += 1
        if not context:
            continue
        if context.get("league_name") and (overwrite or not match.get("league_name")):
            match["league_name"] = context["league_name"]
        for key in ("league_slug", "country", "country_slug"):
            if context.get(key) and not match.get(key):
                match[key] = context[key]
    if identity_matches:
        logger.info("league_names_merged_by_event_identity", count=identity_matches)


def collect_match_links(driver, target_date=None, sport="football", reuse_listing=False, return_result=False):
    """Navigate to a sport listing page and collect all match links.

    Args:
        driver: Selenium WebDriver instance.
        target_date: Date identifier in YYYYMMDD format. Defaults to today.
        sport: Supported sport slug. Defaults to tennis.
        reuse_listing: Change the date on the currently rendered listing page.
            If that navigation fails, reload the listing page and retry once.

    Returns a list of dicts with match info including constructed URLs.
    """
    metrics = get_metrics()
    sport = normalize_sport(sport)
    metrics.phase1_start()
    t0 = time.time()

    if target_date is None:
        target_date = datetime.now().strftime("%Y%m%d")

    url = get_sport_listing_url(sport)
    logger.info("collecting_matches", sport=sport, url=url, target_date=target_date)

    if reuse_listing:
        logger.info("listing_page_reused", sport=sport, target_date=target_date)
    else:
        if not safe_get(driver, url):
            logger.error("initial_page_load_failed", url=url)
            metrics.record_scrape_error("initial_load_failed")
            result = DiscoveryResult(anomalies=["initial_page_load_failed"])
            return result if return_result else []
        time.sleep(5)
        _dismiss_cookie_popup(driver)
        time.sleep(3)

    date_navigation_succeeded = _navigate_to_date(driver, target_date)
    if not date_navigation_succeeded and reuse_listing:
        logger.warning("reused_listing_navigation_failed_reloading", sport=sport, target_date=target_date)
        if not safe_get(driver, url):
            logger.error("listing_reload_failed", url=url)
            metrics.record_scrape_error("listing_reload_failed")
            result = DiscoveryResult(anomalies=["listing_reload_failed"])
            return result if return_result else []
        time.sleep(5)
        _dismiss_cookie_popup(driver)
        time.sleep(3)
        date_navigation_succeeded = _navigate_to_date(driver, target_date)

    if not date_navigation_succeeded:
        logger.error("target_date_navigation_failed", target_date=target_date, sport=sport)
        metrics.record_scrape_error("date_navigation_failed")
        result = DiscoveryResult(anomalies=["date_navigation_failed"])
        return result if return_result else []
    time.sleep(3)

    fetched = _fetch_all_matches(driver, sport=sport, return_result=True)
    # Preserve compatibility with tests and third-party patches that return a dict.
    discovery = fetched if isinstance(fetched, DiscoveryResult) else DiscoveryResult(
        matches=fetched or {}, expected_pages=1, observed_pages=1,
    )
    matches = discovery.matches

    if not matches and sport == "football":
        logger.warning("sport_component_empty_trying_sports_events")
        matches = _extract_matches_from_sports_events(driver, sport=sport)
        if matches:
            discovery = DiscoveryResult(matches=matches, expected_pages=1, observed_pages=1)

    if not matches:
        logger.warning("api_returns_empty_trying_vuex")
        matches = _extract_matches_vuex(driver, sport=sport)
        if matches:
            discovery = DiscoveryResult(matches=matches, expected_pages=1, observed_pages=1)

    _clean_match_data(matches)

    status_counts = {}
    for match in matches.values():
        token = _listing_status_token(match) or "UNKNOWN"
        status_counts[token] = status_counts.get(token, 0) + 1
    logger.info("listing_status_counts", sport=sport, target_date=target_date, counts=status_counts)

    _build_urls(matches, sport=sport)

    if sport == "football" or any(not _match_league_name(match) for match in matches.values()):
        league_matches = _extract_matches_from_sports_events(driver, sport=sport)
        if league_matches:
            # JSON-LD SportsEvent.superEvent is the competition title.  It is
            # more reliable than a nearby DOM heading, which can be an Odds
            # navigation link or an adjacent card's text.
            _merge_league_names(matches, league_matches, overwrite=True)

    result = list(matches.values())
    for m in result:
        m["id"] = str(m.pop("matchId", m.get("id", "")))
        m.setdefault("date", target_date)
        m.setdefault("matchKey", "")
        m.setdefault("home", "")
        m.setdefault("away", "")
        m.setdefault("country", "")
        m.setdefault("country_slug", "")
        m.setdefault("league_slug", "")
        m["league_name"] = _match_league_name(m)
        m["sport"] = sport
        m.pop("homeSlug", None)
        m.pop("awaySlug", None)
        m.pop("matchStatus", None)
        m.pop("_src", None)
        m.pop("league", None)
        m.pop("tournament", None)

    source_dates = listing_source_dates(result)
    target_date_id = str(target_date).replace("-", "")[:8]
    if result and target_date_id not in source_dates:
        discovery.anomalies.append("listing_target_date_missing")
        logger.warning(
            "listing_target_date_missing",
            target_date=target_date_id,
            source_dates=sorted(source_dates),
            count=len(result),
        )

    missing_leagues = [m.get("id", "") for m in result if not m.get("league_name")]
    if missing_leagues:
        archived_missing = sum(
            1 for m in result
            if not m.get("league_name") and str(m.get("url", "")).startswith("/a/")
        )
        logger.warning(
            "league_source_missing",
            sport=sport,
            target_date=target_date,
            count=len(missing_leagues),
            match_ids=missing_leagues[:25],
            fallback="empty_string",
            archived=archived_missing,
            source="listing_dom_and_structured_events",
        )

    duration_seconds = int(time.time() - t0)
    metrics.phase1_complete(total=len(result), success=len(result), duration_seconds=duration_seconds)

    logger.info(
        "event_discovery_complete",
        total=len(result),
        links_saved=len(result),
        duration_seconds=duration_seconds,
    )
    discovery.matches = {str(m.get("id", index)): m for index, m in enumerate(result)}
    return discovery if return_result else result
