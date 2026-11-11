"""Football pre-match odds from Oddspedia's JSON API, one bookmaker per market.

Ported from the OddsHarvest tennis collector (its ADRs 0011, 0013, 0015 and
0022) and adapted to football (DepthMark ADR 0035).

A match page preloads odds for the visitor's country only, and the DOM path
has to click every market card open. This module reads the event identity and
market-group list from the page store, then requests each group the way the
page does when "All bookmakers" is selected:

- ``getOddsAvailableMarkets`` lists groups beyond the default ones;
- ``getMatchOdds`` returns every bookmaker's prices for every line of one
  group and, once settled, the winning outcome.

Each saved market holds the lines of a single bookmaker: the one that prices
the most Full Time lines of that market. Only the Full Time period is saved,
because the football contract drops half-time markets; the raw reads keep
every period.

Requests run with ``fetch`` inside the rendered page, one at a time and spaced
apart, and always carry ``matchId``. A refused request (``403``, ``429``,
``5xx`` or a network error) stops the remaining requests; only the refused
reads are asked again after a back-off on the same page.

The translation from reads to markets is pure, so it is tested on recorded
fixtures without a browser. Its output feeds ``normalize_football_odds``,
which applies the same football contract as the DOM path.
"""

from __future__ import annotations

import re
import time
from collections.abc import Mapping
from dataclasses import dataclass, field, replace
from typing import Any

from selenium.common.exceptions import WebDriverException

from src.oddspedia.scraping.logging import get_logger

logger = get_logger(__name__)

# Groups a football match page always requests: Full Time Result, Total
# Goals, Asian Handicap, Both Teams to Score. The page store normally names
# them; this is only the fallback.
DEFAULT_FOOTBALL_MARKET_GROUP_IDS = (1, 4, 3, 11)
# The only period the football contract saves.
SAVED_PERIOD = "Full Time"
FETCH_SCRIPT_TIMEOUT_SECONDS = 120
# A burst of API requests is what Cloudflare's check reacts to: space them.
ODDS_REQUEST_SPACING_SECONDS = 1.0
ODDS_REQUEST_JITTER_SECONDS = 0.5
# Back-off before asking refused reads again on the same page. A longer
# Retry-After from the API wins.
ODDS_REFUSAL_BACKOFF_SECONDS = (30,)
_REFUSAL_STATUSES = (0, 403, 429)
# The empty geo code is the page's "All bookmakers" selection.
ALL_BOOKMAKERS_GEO_CODE = ""
ODDS_GEO_ALL_BOOKMAKERS = "ALL"
ODDS_SOURCE_API = "api"
# Names the rule that turns raw reads into saved markets. Bump the version
# whenever ``build_api_odds`` would build different markets from the same
# reads, so stored payloads say which rule built them.
ODDS_DERIVATION = {
    "policy": "one_bookmaker_most_lines",
    "periods": [SAVED_PERIOD],
    "adr": "0035",
    "version": 1,
}

# Outcome names saved as named line fields. Every other name (``1X``, ``Tie``,
# ``No Goal``, a correct score, ``Home / Draw``) goes into ``outcomes``, which
# ``normalize_football_odds`` maps onto the football contract.
_OUTCOME_FIELDS = {
    "home": "home",
    "away": "away",
    "draw": "draw",
    "over": "over",
    "under": "under",
    "odd": "odd",
    "even": "even",
    "yes": "yes",
    "no": "no",
}

# Bookmaker rows also carry tracking links, bonus offers and colours; only
# these keys are returned from the page.
_BOOKMAKER_KEYS_PATTERN = r"^(bid|bookie_name|o\d+|status)$"
_PRICE_KEY = re.compile(r"^o(\d+)$")
# The API writes correct scores as ``2 : 1``; the DOM contract uses ``2-1``.
_SCORE_LABEL = re.compile(r"^\s*(\d+)\s*:\s*(\d+)\s*$")

_JS_READ_EVENT_STATE = """
    var root = document.querySelector('#__nuxt');
    var vm = root && root.__vue__;
    var state = (vm && vm.$store && vm.$store.state)
        || (window.__NUXT__ && window.__NUXT__.state);
    var store = state && state.event;
    if (!store || !store.event) return null;
    var stage = store.eventStage || {};
    var country = state.geolocation && state.geolocation.country;
    var hasOdds = stage.has_odds;
    if (hasOdds === undefined || hasOdds === null) hasOdds = store.eventHasOdds;
    return JSON.parse(JSON.stringify({
        match_id: store.event.id,
        has_odds: hasOdds,
        default_groups: stage.default_market_groups || null,
        page_geo_code: (country && country.code) || ''
    }));
"""

_JS_FETCH_ALL_BOOKMAKER_ODDS = """
    var done = arguments[arguments.length - 1];
    var matchId = String(arguments[0]);
    var defaultGroups = arguments[1];
    var geoCode = arguments[2];
    var bookmakerKeys = new RegExp(arguments[3]);
    var readAvailable = arguments[4];
    var knownGroups = arguments[5];
    var spacingMs = arguments[6];
    var jitterMs = arguments[7];
    function query(extra) {
        var params = new URLSearchParams({
            matchId: matchId,
            inplay: '0',
            geoCode: geoCode,
            language: 'en'
        });
        Object.keys(extra).forEach(function (key) { params.set(key, String(extra[key])); });
        return params.toString();
    }
    function read(path) {
        return fetch('/api/v1/' + path, {
            credentials: 'same-origin',
            headers: {Accept: 'application/json'}
        }).then(function (response) {
            return response.text().then(function (text) {
                var body = null;
                try { body = JSON.parse(text); } catch (e) { body = null; }
                var answer = {status: response.status, body: body};
                if (response.status !== 200) {
                    answer.cf_mitigated = response.headers.get('cf-mitigated');
                    answer.retry_after = response.headers.get('retry-after');
                }
                return answer;
            });
        }).catch(function (error) {
            return {status: 0, error: String(error)};
        });
    }
    // A refused request means the API is checking this session: stop asking
    // until the caller has backed off instead of spending the whole burst.
    var halted = false;
    var sent = 0;
    function paced(path) {
        var wait = sent ? new Promise(function (resolve) {
            setTimeout(resolve, spacingMs + Math.random() * jitterMs);
        }) : Promise.resolve();
        sent += 1;
        return wait.then(function () { return read(path); }).then(function (answer) {
            var status = answer.status;
            if (status === 0 || status === 403 || status === 429 || status >= 500) halted = true;
            return answer;
        });
    }
    var result = {available: null, groups: {}};
    var ids = defaultGroups.slice();
    var first = !readAvailable ? Promise.resolve() :
        paced('getOddsAvailableMarkets?' + query({geoState: ''})).then(function (available) {
            result.available = available;
            var listed = available.status === 200 && available.body && available.body.data;
            (Array.isArray(listed) ? listed : []).forEach(function (market) {
                var id = Number(market.market_group_id);
                if (id && ids.indexOf(id) < 0 && knownGroups.indexOf(id) < 0) ids.push(id);
            });
        });
    // Sequential and spaced on purpose: one small request at a time.
    first.then(function () {
        return ids.reduce(function (chain, groupId) {
            return chain.then(function () {
                if (halted) {
                    result.groups[groupId] = {status: -1, skipped: true};
                    return;
                }
                var path = 'getMatchOdds?' + query({
                    wettsteuer: '0',
                    bookmakerGeoCode: '',
                    bookmakerGeoState: '',
                    oddGroupId: groupId
                });
                return paced(path).then(function (response) { result.groups[groupId] = response; });
            });
        }, Promise.resolve());
    }).then(function () {
        done(JSON.parse(JSON.stringify(result, function (key, value) {
            if (value && typeof value === 'object' && !Array.isArray(value)
                    && 'bookie_name' in value) {
                var kept = {};
                Object.keys(value).forEach(function (name) {
                    if (bookmakerKeys.test(name)) kept[name] = value[name];
                });
                return kept;
            }
            return value;
        })));
    });
"""


class EventIdentityMismatchError(RuntimeError):
    """Raised when the page store belongs to a different event."""


@dataclass(frozen=True)
class ApiOddsResult:
    """Single-bookmaker pre-match football odds for one event."""

    odds: list[dict[str, Any]]
    market_names: list[str]
    unavailable_market_names: list[str]
    unavailable: bool
    failed_reads: tuple[str, ...] = field(default_factory=tuple)
    # The successful raw reads, compacted to the requested group of each read.
    raw: dict[str, Any] = field(default_factory=dict)
    # A read was refused with Cloudflare's check (``cf-mitigated: challenge``).
    challenged: bool = False

    @property
    def complete(self) -> bool:
        """Whether every request succeeded, so missing markets are source truth."""
        return not self.failed_reads


@dataclass(frozen=True)
class _SourceLine:
    """One line of a group with every bookmaker that prices all its outcomes."""

    period: str
    line_type: str
    label: str
    prices: dict[str, dict[str, float]]


def _as_list(value: Any) -> list[Any]:
    if isinstance(value, Mapping):
        return list(value.values())
    return list(value) if isinstance(value, list) else []


def _price(value: Any) -> float | None:
    try:
        price = float(value)
    except (TypeError, ValueError):
        return None
    return price if price > 0 else None


def _outcome_keys(group: Mapping[str, Any]) -> list[str]:
    """Return the price keys (``o1``, ``o2``, ...) a bookmaker must fill."""
    if group.get("waytype") == 1:
        return ["o1"]
    count = len(group.get("oddsnames") or []) or 2
    return [f"o{index}" for index in range(1, count + 1)]


def _bookmaker_prices(rows: Any, keys: list[str]) -> dict[str, dict[str, float]]:
    """Map bookmaker name to its prices, keeping only rows that price every key."""
    prices: dict[str, dict[str, float]] = {}
    for row in _as_list(rows):
        if not isinstance(row, Mapping):
            continue
        name = str(row.get("bookie_name") or "").strip()
        if not name or name in prices:
            continue
        values = {key: _price(row.get(key)) for key in keys}
        if all(value is not None for value in values.values()):
            prices[name] = values
    return prices


def _line_label(group: Mapping[str, Any], name: Any) -> str:
    label = str(name or "").strip()
    score = _SCORE_LABEL.match(label)
    if group.get("waytype") == 1 and score:
        return f"{score.group(1)}-{score.group(2)}"
    return label


def _source_lines(group: Mapping[str, Any]) -> list[_SourceLine]:
    """Return every line of a ``getMatchOdds`` group in source order."""
    keys = _outcome_keys(group)
    lines: list[_SourceLine] = []
    for period in _as_list(group.get("periods")):
        if not isinstance(period, Mapping):
            continue
        period_name = str(period.get("name") or "") or SAVED_PERIOD
        odds = period.get("odds")
        if group.get("has_handicap") and isinstance(odds, Mapping):
            labelled = [("main", line) for line in _as_list(odds.get("main"))]
            labelled += [("alternative", line) for line in _as_list(odds.get("alternative"))]
            for line_type, line in labelled:
                if not isinstance(line, Mapping):
                    continue
                lines.append(
                    _SourceLine(
                        period=period_name,
                        line_type=line_type,
                        label=_line_label(group, line.get("name")),
                        prices=_bookmaker_prices(line.get("odds"), keys),
                    )
                )
        else:
            lines.append(
                _SourceLine(
                    period=period_name,
                    line_type="main",
                    label="",
                    prices=_bookmaker_prices(odds, keys),
                )
            )
    return lines


def _saved_lines(group: Mapping[str, Any]) -> list[_SourceLine]:
    return [line for line in _source_lines(group) if line.period == SAVED_PERIOD]


def _line_counts(lines: list[_SourceLine]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for line in lines:
        for name in line.prices:
            counts[name] = counts.get(name, 0) + 1
    return counts


def _choose_bookmaker(
    counts: Mapping[str, int],
    event_counts: Mapping[str, int] | None = None,
) -> str | None:
    """Pick the bookmaker with the most lines in the market.

    Ties go to the bookmaker with the most lines across the event, then to the
    name, so the choice is repeatable.
    """
    if not counts:
        return None
    event_counts = event_counts or {}
    return min(
        counts,
        key=lambda name: (-counts[name], -event_counts.get(name, 0), name.casefold()),
    )


def _price_index(key: str) -> int:
    match = _PRICE_KEY.match(key)
    return int(match.group(1)) if match else 0


def _named_line(line: _SourceLine, prices: Mapping[str, float], names: list[str]) -> dict:
    """Map one bookmaker's prices onto named fields, the rest onto ``outcomes``."""
    saved: dict[str, Any] = {"type": line.line_type, "label": line.label}
    outcomes: dict[str, float] = {}
    for key, value in sorted(prices.items(), key=lambda item: _price_index(item[0])):
        index = _price_index(key) - 1
        name = names[index] if 0 <= index < len(names) and names[index] else key
        field_name = _OUTCOME_FIELDS.get(str(name).strip().casefold())
        if field_name:
            saved[field_name] = value
        else:
            outcomes[str(name)] = value
    if outcomes:
        saved["outcomes"] = outcomes
    return saved


def _one_way_line(lines: list[_SourceLine], bookmaker: str) -> list[dict[str, Any]]:
    """Collect one-way selections (Correct Score, HT/FT) into one line."""
    outcomes = {
        line.label: line.prices[bookmaker]["o1"]
        for line in lines
        if line.label and bookmaker in line.prices
    }
    return [{"type": "main", "label": "", "outcomes": outcomes}] if outcomes else []


def market_from_group(
    group: Mapping[str, Any],
    event_counts: Mapping[str, int] | None = None,
) -> dict[str, Any] | None:
    """Translate one ``getMatchOdds`` group into a single-bookmaker market.

    ``event_counts`` (Full Time lines per bookmaker across the event) breaks
    ties between bookmakers that price the same number of lines. Returns
    ``None`` when no bookmaker prices a full Full Time line.
    """
    market_name = str(group.get("name") or "").strip()
    if not market_name:
        return None
    lines = _saved_lines(group)
    bookmaker = _choose_bookmaker(_line_counts(lines), event_counts)
    if bookmaker is None:
        return None
    if group.get("waytype") == 1:
        saved = _one_way_line(lines, bookmaker)
    else:
        names = [str(name) if name else "" for name in group.get("oddsnames") or []]
        saved = [
            _named_line(line, line.prices[bookmaker], names)
            for line in lines
            if bookmaker in line.prices
        ]
    if not saved:
        return None
    return {
        "market": market_name,
        "market_group_id": group.get("id"),
        "bookmaker": bookmaker,
        "lines": saved,
    }


def _response_ok(response: Any) -> bool:
    return (
        isinstance(response, Mapping)
        and response.get("status") == 200
        and isinstance(response.get("body"), Mapping)
    )


def _requested_group(body: Mapping[str, Any], group_id: int) -> Mapping[str, Any] | None:
    """Return the requested group from a ``getMatchOdds`` body.

    The body lists every group of the event but prices only the requested one;
    an unknown id is answered with another group's prices, so the group is
    matched by id.
    """
    data = body.get("data")
    prematch = data.get("prematch") if isinstance(data, Mapping) else None
    for group in _as_list(prematch):
        if not isinstance(group, Mapping):
            continue
        try:
            if int(group.get("id")) == group_id:
                return group
        except (TypeError, ValueError):
            continue
    return None


def _available_settled(available: Any) -> bool:
    """``getOddsAvailableMarkets`` answered: listed groups, or ``404`` for none."""
    return _response_ok(available) or (
        isinstance(available, Mapping) and available.get("status") == 404
    )


def successful_reads(fetched: Mapping[str, Any] | None) -> dict[str, Any]:
    """Return only the reads that answered, for reuse by a retry."""
    fetched = fetched or {}
    kept: dict[str, Any] = {"groups": {}}
    if _available_settled(fetched.get("available")):
        kept["available"] = fetched["available"]
    for key, response in (fetched.get("groups") or {}).items():
        if _response_ok(response):
            kept["groups"][str(key)] = response
    return kept


def compact_reads(fetched: Mapping[str, Any] | None) -> dict[str, Any]:
    """Return the successful reads with each body cut to its requested group.

    Every ``getMatchOdds`` body lists all the event's groups; only the
    requested one carries prices. ``build_api_odds`` reads the same markets
    from the compact form, so stored payloads stay small and rebuildable.
    """
    kept = successful_reads(fetched)
    compact: dict[str, Any] = {"groups": {}}
    if "available" in kept:
        compact["available"] = kept["available"]
    for key, response in kept["groups"].items():
        group = _requested_group(response["body"], int(key))
        compact["groups"][key] = {
            "status": response["status"],
            "body": {"data": {"prematch": [group] if group else []}},
        }
    return compact


def build_api_odds(fetched: Mapping[str, Any] | None = None) -> ApiOddsResult:
    """Build saved markets from ``getOddsAvailableMarkets`` and ``getMatchOdds`` reads.

    ``fetched`` holds the ``available`` response and one response per group.
    A ``200`` group with no Full Time prices is an unavailable market.
    ``getOddsAvailableMarkets`` answers ``404`` when there are no extra groups.
    Any other status or an unreadable body is a failed read, never "no odds".
    """
    fetched = fetched or {}
    failed: list[str] = []
    available = fetched.get("available")
    names: dict[int, str] = {}
    if available is not None:
        if _response_ok(available):
            for market in available["body"].get("data") or []:
                if isinstance(market, Mapping) and market.get("market_group_id"):
                    names[int(market["market_group_id"])] = str(market.get("market_name") or "")
        elif not (isinstance(available, Mapping) and available.get("status") == 404):
            failed.append("available_markets")

    groups: list[tuple[int, Mapping[str, Any] | None]] = []
    for key, response in (fetched.get("groups") or {}).items():
        group_id = int(key)
        if not _response_ok(response):
            failed.append(f"market_group:{group_id}")
            continue
        groups.append((group_id, _requested_group(response["body"], group_id)))

    event_counts: dict[str, int] = {}
    for _group_id, group in groups:
        for name, count in _line_counts(_saved_lines(group or {})).items():
            event_counts[name] = event_counts.get(name, 0) + count

    odds: list[dict[str, Any]] = []
    unavailable: list[str] = []
    for group_id, group in groups:
        market = market_from_group(group, event_counts) if group else None
        if market:
            odds.append(market)
            continue
        name = (group or {}).get("name") or names.get(group_id)
        if name:
            unavailable.append(str(name).strip())

    return ApiOddsResult(
        odds=odds,
        market_names=[market["market"] for market in odds],
        unavailable_market_names=unavailable,
        unavailable=not odds and not failed,
        failed_reads=tuple(failed),
        raw=compact_reads(fetched),
    )


def default_group_ids(state: Mapping[str, Any]) -> list[int]:
    """Return the event's default market groups, falling back to the football defaults."""
    ids = []
    for value in state.get("default_groups") or DEFAULT_FOOTBALL_MARKET_GROUP_IDS:
        try:
            ids.append(int(value))
        except (TypeError, ValueError):
            continue
    return ids or list(DEFAULT_FOOTBALL_MARKET_GROUP_IDS)


def _read_event_state(driver: Any) -> dict[str, Any] | None:
    try:
        state = driver.execute_script(_JS_READ_EVENT_STATE)
    except WebDriverException as exc:
        logger.warning("api_odds_state_unreadable", error=str(exc))
        return None
    return state if isinstance(state, dict) else None


def _listed_group_ids(available: Any) -> list[int]:
    if not _response_ok(available):
        return []
    ids = []
    for market in available["body"].get("data") or []:
        try:
            ids.append(int(market["market_group_id"]))
        except (KeyError, TypeError, ValueError):
            continue
    return ids


def _refusals(fetched: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Describe the reads the API refused, for logs and the back-off."""
    reads = [("available_markets", fetched.get("available"))]
    reads += [
        (f"market_group:{key}", value) for key, value in (fetched.get("groups") or {}).items()
    ]
    refused = []
    for name, response in reads:
        if not isinstance(response, Mapping) or response.get("skipped"):
            continue
        status = response.get("status")
        if status in _REFUSAL_STATUSES or (isinstance(status, int) and status >= 500):
            refused.append(
                {
                    "read": name,
                    "status": status,
                    "cf_mitigated": response.get("cf_mitigated"),
                    "retry_after": response.get("retry_after"),
                    "error": response.get("error"),
                }
            )
    return refused


def _refusal_backoff(refused: list[dict[str, Any]], round_index: int) -> float:
    schedule = ODDS_REFUSAL_BACKOFF_SECONDS
    seconds = float(schedule[min(round_index, len(schedule) - 1)])
    for refusal in refused:
        try:
            seconds = max(seconds, float(refusal.get("retry_after")))
        except (TypeError, ValueError):
            continue
    return seconds


def _fetch_all_bookmaker_odds(
    driver: Any,
    match_id: Any,
    group_ids: list[int],
    read_available: bool = True,
    known_group_ids: list[int] | None = None,
) -> dict:
    driver.set_script_timeout(FETCH_SCRIPT_TIMEOUT_SECONDS)
    fetched = driver.execute_async_script(
        _JS_FETCH_ALL_BOOKMAKER_ODDS,
        str(match_id),
        group_ids,
        ALL_BOOKMAKERS_GEO_CODE,
        _BOOKMAKER_KEYS_PATTERN,
        read_available,
        list(known_group_ids or []),
        int(ODDS_REQUEST_SPACING_SECONDS * 1000),
        int(ODDS_REQUEST_JITTER_SECONDS * 1000),
    )
    return fetched if isinstance(fetched, dict) else {}


def _read_market_groups(driver: Any, match_id: Any, default_ids: list[int]) -> dict[str, Any]:
    """Read every market group, backing off on the same page after refusals."""
    fetched: dict[str, Any] = {"available": None, "groups": {}}
    rounds = len(ODDS_REFUSAL_BACKOFF_SECONDS) + 1
    for round_index in range(rounds):
        read_available = not _available_settled(fetched["available"])
        wanted = list(default_ids)
        for group_id in _listed_group_ids(fetched["available"]) + [
            int(k) for k in fetched["groups"]
        ]:
            if group_id not in wanted:
                wanted.append(group_id)
        answered = [gid for gid in wanted if _response_ok(fetched["groups"].get(str(gid)))]
        pending = [gid for gid in wanted if gid not in answered]
        if not pending and not read_available:
            break
        if round_index:
            refused = _refusals(fetched)
            if not refused:
                break
            if all(refusal.get("cf_mitigated") == "challenge" for refusal in refused):
                # The API keeps answering with the check until this session
                # passes one on a page; waiting here cannot help.
                break
            backoff = _refusal_backoff(refused, round_index - 1)
            logger.warning(
                "api_odds_refused_backoff",
                match_id=match_id,
                backoff_s=backoff,
                refused=refused,
            )
            time.sleep(backoff)
        try:
            batch = _fetch_all_bookmaker_odds(
                driver, match_id, pending, read_available=read_available, known_group_ids=answered
            )
        except WebDriverException as exc:
            logger.warning("api_odds_fetch_failed", match_id=match_id, error=str(exc))
            batch = {}
        if read_available:
            fetched["available"] = batch.get("available") or {"status": 0}
        batch_groups = batch.get("groups") or {}
        for group_id in pending:
            fetched["groups"][str(group_id)] = batch_groups.get(str(group_id)) or {"status": 0}
        for key, response in batch_groups.items():
            fetched["groups"].setdefault(str(key), response)
    return fetched


def extract_api_odds(driver: Any, match_id: Any) -> ApiOddsResult | None:
    """Read single-bookmaker pre-match odds for the rendered event.

    Returns ``None`` when the page store is missing, so the caller may use the
    DOM path. A store for a different event raises
    ``EventIdentityMismatchError``: every component on that page belongs to
    the other event, so no fallback may save it.
    """
    started = time.monotonic()
    state = _read_event_state(driver)
    if state is None:
        logger.info("api_odds_state_missing", match_id=match_id)
        return None
    if str(state.get("match_id") or "") != str(match_id):
        logger.warning(
            "api_odds_state_event_mismatch",
            match_id=match_id,
            state_match_id=state.get("match_id"),
        )
        raise EventIdentityMismatchError(
            f"page rendered event {state.get('match_id')} instead of {match_id}"
        )

    if state.get("has_odds") is False:
        # The source has no odds for this event from any bookmaker.
        result = build_api_odds()
    else:
        fetched = _read_market_groups(driver, match_id, default_group_ids(state))
        result = build_api_odds(fetched)
        if result.failed_reads:
            refused = _refusals(fetched)
            logger.warning("api_odds_refused", match_id=match_id, refused=refused)
            if any(refusal.get("cf_mitigated") == "challenge" for refusal in refused):
                result = replace(result, challenged=True)

    logger.info(
        "api_odds_read",
        match_id=match_id,
        page_geo_code=state.get("page_geo_code"),
        markets=len(result.odds),
        lines=sum(len(market["lines"]) for market in result.odds),
        market_names=result.market_names,
        market_bookmakers={market["market"]: market["bookmaker"] for market in result.odds},
        unavailable_market_names=result.unavailable_market_names,
        failed_reads=list(result.failed_reads),
        odds_unavailable=result.unavailable,
        duration_ms=int((time.monotonic() - started) * 1000),
    )
    return result
