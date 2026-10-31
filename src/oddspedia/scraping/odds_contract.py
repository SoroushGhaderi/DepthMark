"""Football odds contract: the pure rules that turn scraped markets into Bronze odds.

Nothing here drives a browser. ``match_scraper`` extracts raw markets from the
page; this module normalizes them to the football market contract, merges
retries, and decides coverage, so the rules are testable on recorded fixtures.
"""

import json
import re

from src.oddspedia.scraping.logging import get_logger

logger = get_logger(__name__)


class FootballOddsCoverageError(RuntimeError):
    """Raised when Oddspedia exposes a football market that was not saved."""

    def __init__(self, message, *, missing_markets=None, partial_odds=None):
        super().__init__(message)
        self.missing_markets = list(
            dict.fromkeys(
                str(name).strip() for name in (missing_markets or []) if str(name).strip()
            )
        )
        self.partial_odds = list(partial_odds or [])


class FootballOddsRetryableError(FootballOddsCoverageError):
    """Raised when football odds may appear on a subsequent page attempt."""


class FootballOddsUnavailableError(RuntimeError):
    """Raised when a valid football page publishes no betting lines."""


def build_odds(raw_markets):
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


def merge_odds_markets(existing, new_markets):
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


def has_football_market(odds, market_name):
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
    return all(str(line.get("label", "")).strip() for line in lines)


def validate_european_handicap_coverage(odds):
    complete = []
    for market in odds or []:
        if _football_market_family(
            market.get("market", "")
        ) == "european handicap" and not _football_market_has_coverage(market):
            logger.warning(
                "european_handicap_incomplete_lines_skipped",
                market=market.get("market", "European Handicap"),
                lines=market.get("lines", []),
            )
            continue
        complete.append(market)
    return complete


def football_odds_coverage_error(odds, total_markets=None, odds_unavailable=False):
    """Return an error when fewer odds markets were extracted than exposed."""
    # Preserve compatibility with callers that passed the former boolean
    # second positional argument while the denominator was not tracked yet.
    if isinstance(total_markets, bool) and odds_unavailable is False:
        odds_unavailable = total_markets
        total_markets = None
    if odds_unavailable or total_markets is None:
        return None
    try:
        expected_count = int(total_markets)
    except (TypeError, ValueError):
        return None
    if expected_count <= 0:
        return None

    extracted_count = len(odds or [])
    if extracted_count >= expected_count:
        return None
    return (
        "Football odds market coverage incomplete: "
        f"extracted {extracted_count}/{expected_count} markets; retry required"
    )


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


_FOOTBALL_PARAMETERIZED_MARKETS = {
    "total goals",
    "total corners",
    "asian handicap",
    "asian handicap corners",
    "european handicap",
}


FOOTBALL_DEFAULT_LINE_LABEL = "Main Line"


def _football_market_family(market_name):
    name = re.sub(r"^\s*(?:1st|2nd)\s+half\s*-\s*", "", str(market_name or ""), flags=re.I)
    return re.sub(r"\s+", " ", name).strip().lower()


def _football_market_family_key(market_name):
    """Return a stable key for equivalent source labels."""
    family = _football_market_family(market_name)
    return {
        "match winner": "full time result",
        "1x2": "full time result",
    }.get(family, family)


def football_market_names_match(left, right):
    """Return whether two Oddspedia labels describe the same market family."""
    left_key = _football_market_family_key(left)
    right_key = _football_market_family_key(right)
    return bool(left and right) and left_key == right_key


def football_filter_markets(markets, target_markets):
    """Keep only markets matching the requested source labels."""
    targets = list(target_markets or [])
    if not targets:
        return list(markets or [])
    return [
        market
        for market in markets or []
        if any(football_market_names_match(market.get("market"), target) for target in targets)
    ]


def football_missing_market_names(market_names, odds):
    """Return inventory labels that do not have a complete saved market."""
    missing = []
    for market_name in dict.fromkeys(str(name).strip() for name in (market_names or [])):
        if not market_name:
            continue
        if not any(
            football_market_names_match(market.get("market"), market_name)
            and _football_market_has_coverage(market)
            for market in odds or []
        ):
            missing.append(market_name)
    return missing


def _football_market_requires_label(market_name):
    return _football_market_family(market_name) in _FOOTBALL_PARAMETERIZED_MARKETS


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
            "home",
            "draw",
            "away",
            "over",
            "under",
            "yes",
            "no",
            "odd",
            "even",
            "home_draw",
            "draw_away",
            "home_away",
            "no_goal",
            "scores",
            "combinations",
            "outcomes",
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
        key not in _FOOTBALL_COMMON_LINE_FIELDS and line.get(key) is not None for key in line
    )


def _football_combo_key(label, home, away):
    text = str(label or "").strip()
    if not text:
        return ""
    canonical = re.fullmatch(r"(home|draw|away)_(home|draw|away)", text.lower())
    if canonical:
        return f"{canonical.group(1)}_{canonical.group(2)}"
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
        next_line["label"] = str(next_line.get("label", "")).strip()
        if not next_line["label"] and not _football_market_requires_label(market_name):
            next_line["label"] = FOOTBALL_DEFAULT_LINE_LABEL

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

        if _football_market_requires_label(market_name):
            missing = []
            if not str(next_line.get("label", "")).strip():
                missing.append("label")
            if family == "european handicap":
                missing.extend(
                    field for field in ("home", "draw", "away") if next_line.get(field) is None
                )
            if missing:
                logger.warning(
                    "parameterized_football_line_skipped",
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
        next_market.pop("schema_status", None)
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
            fallback["label"] = str(fallback.get("label", "")).strip()
            if not fallback["label"] and not _football_market_requires_label(market_name):
                fallback["label"] = FOOTBALL_DEFAULT_LINE_LABEL
            for key, value in line.items():
                if key in _FOOTBALL_COMMON_LINE_FIELDS:
                    continue
                if value is not None:
                    fallback[key] = value
            if len(fallback) > len(_FOOTBALL_COMMON_LINE_FIELDS):
                fallback["schema_status"] = "unmatched"
                fallback_lines.append(fallback)
        if shape != "generic":
            return None
        if not fallback_lines:
            return None
        next_market["schema_status"] = "unmatched"
        next_market["lines"] = fallback_lines
    return next_market


def normalize_football_odds(odds, home="", away=""):
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
                    field = (
                        ""
                        if shape in {"scores", "combinations"}
                        else _football_outcome_field(label, home, away)
                    )
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
    return merge_odds_markets([], normalized)


def apply_football_selector_context(markets, selector_text):
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


_FOOTBALL_NON_MARKET_SELECTOR_PATTERN = re.compile(
    r"(?:\bmoney\s+on\b|\bbetting\s+data\b)", flags=re.I
)


def is_football_market_selector_text(value):
    """Return whether *value* looks like a market selector rather than a stats link."""
    text = re.sub(r"\s+", " ", str(value or "")).strip()
    return bool(text) and not _FOOTBALL_NON_MARKET_SELECTOR_PATTERN.search(text)


def football_selector_rendered(markets, selector_text):
    """Whether a selector produced the market it was asked to display."""
    selector = str(selector_text or "").strip().lower()
    if selector in {"1st half", "2nd half"}:
        period_markets = [
            market
            for market in markets or []
            if str(market.get("market", "")).strip().lower().startswith(f"{selector} -")
        ]
        return bool(period_markets) and all(
            _football_market_has_coverage(market) for market in period_markets
        )
    return any(
        str(market.get("market", "")).strip().lower() == selector
        and _football_market_has_coverage(market)
        for market in markets or []
    )
