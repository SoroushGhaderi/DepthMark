import os
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from src.oddspedia.match_scraper import (
    _JS_EXTRACT_ODDS,
    _JS_FOOTBALL_MARKET_SELECTOR_TEXTS,
    FootballOddsUnavailableError,
    FootballScoreUnavailableError,
    _expand_football_market_cards,
    _expand_football_market_card_lines,
    _apply_football_selector_context,
    _football_selector_rendered,
    _merge_odds_markets,
    _normalize_football_odds,
    _parse_football_score_payload,
    _extract_football_odds,
    scrape_match,
)
from src.oddspedia.utils import load_json, save_json


class _FootballDriver:
    title = "Oddspedia Football"

    def execute_script(self, script, *args):
        if "var d = {" in script:
            return {
                "home": "Mexico",
                "away": "Ecuador",
                "league": "International Friendly",
                "date": "2026-07-09 19:00:00+00",
                "status": "finished",
                "winner": "draw",
                "home_score": 1,
                "away_score": 1,
                "result_unavailable": False,
            }
        if "var markets  = []" in script:
            return [
                {
                    "market": "Full Time Result",
                    "lines": [
                        {"type": "main", "label": "", "home": 2.1, "draw": 3.2, "away": 3.4},
                    ],
                },
                {
                    "market": "Both Teams To Score",
                    "lines": [
                        {"type": "main", "label": "", "yes": 1.8, "no": 1.95},
                    ],
                },
            ]
        if "looksLikeMarketText" in script:
            return []
        if "return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))" in script:
            return []
        return 1000


class FootballMatchSchemaTests(unittest.TestCase):
    @patch("src.oddspedia.match_scraper.now_iso", return_value="2026-07-09T12:00:00Z")
    @patch("src.oddspedia.match_scraper._extract_live_odds", side_effect=AssertionError("football must not scrape live odds"))
    @patch("src.oddspedia.match_scraper._extract_overall_stats")
    @patch("src.oddspedia.match_scraper._expand_all_odds_lines", return_value=1)
    @patch("src.oddspedia.match_scraper._scroll_page")
    @patch("src.oddspedia.match_scraper.safe_get", return_value=True)
    @patch("src.oddspedia.match_scraper.time.sleep", return_value=None)
    def test_football_match_uses_football_schema_and_live_stats(
        self,
        _sleep,
        _safe_get,
        _scroll_page,
        _expand,
        extract_overall_stats,
        _extract_live_odds,
        _now_iso,
    ):
        extract_overall_stats.return_value = {
            "tabs": [
                {
                    "tab": "Live Stats",
                    "metrics": [
                        {"name": "Ball possession", "home": "43%", "away": "57%", "view": "horizontal"},
                        {"name": "Shots on target", "home": "9", "away": "6", "view": "shots"},
                    ],
                }
            ]
        }

        result = scrape_match(
            _FootballDriver(),
            {
                "id": "1979571",
                "sport": "football",
                "home": "Mexico",
                "away": "Ecuador",
                "league_name": "International Friendly",
                "date": "2026-07-09",
                "full_url": "https://oddspedia.com/football/mexico-ecuador-1979571",
            },
            sport="football",
        )

        self.assertEqual(result["sport"], "football")
        self.assertEqual(result["score"], {"home": 1, "away": 1, "winner": "draw"})
        self.assertEqual(result["stats_source"], "Live Stats")
        self.assertEqual([m["name"] for m in result["stats"]], ["Ball possession", "Shots on target"])
        self.assertEqual(len(result["odds"]), 2)
        self.assertNotIn("result_unavailable", result)
        self.assertNotIn("live_odds", result)
        self.assertNotIn("set_scores", result)
        self.assertNotIn("point_by_point", result)

    def test_save_json_does_not_add_default_live_odds_to_football(self):
        data = {
            "sport": "football",
            "id": "1979571",
            "home": "Mexico",
            "away": "Ecuador",
            "tournament": "International Friendly",
            "date": "2026-07-09",
            "status": "finished",
            "score": {"home": 1, "away": 1, "winner": "draw"},
            "odds": [{"market": "Full Time Result", "lines": [{"type": "main", "label": "", "home": 2.1, "draw": 3.2, "away": 3.4}]}],
            "stats": [{"name": "Ball possession", "home": "43%", "away": "57%"}],
            "scraped_at": "2026-07-09T12:00:00Z",
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "match.json")
            save_json(data, path)
            saved = load_json(path)

        self.assertNotIn("live_odds", saved)
        self.assertNotIn("set_scores", saved)
        self.assertEqual(saved["score"]["home"], 1)

    def test_football_score_can_be_derived_from_period_status_payload(self):
        status = """[
            {"period_type":"regular_period","period_number":1,"home":2,"away":0,"tiebreak":null},
            {"period_type":"regular_period","period_number":2,"home":0,"away":0,"tiebreak":null}
        ]"""

        self.assertEqual(_parse_football_score_payload(status), {"home": 2, "away": 0})

    def test_finished_football_match_without_score_fails_instead_of_saving_blank_result(self):
        class BlankScoreDriver(_FootballDriver):
            def execute_script(self, script, *args):
                result = super().execute_script(script, *args)
                if "var d = {" in script:
                    result.update(home_score="", away_score="", winner="")
                return result

        with patch("src.oddspedia.match_scraper.safe_get", return_value=True), \
             patch("src.oddspedia.match_scraper._scroll_page"), \
             patch("src.oddspedia.match_scraper._expand_football_market_list"), \
             patch("src.oddspedia.match_scraper._expand_football_market_cards"), \
             patch("src.oddspedia.match_scraper._extract_football_odds", return_value=[]), \
             patch("src.oddspedia.match_scraper._extract_overall_stats", return_value={"tabs": []}), \
             patch("src.oddspedia.match_scraper._football_score_from_dom", return_value=None), \
             patch("src.oddspedia.match_scraper.time.sleep"):
            with self.assertRaises(FootballScoreUnavailableError):
                scrape_match(
                    BlankScoreDriver(),
                    {"id": "blank", "sport": "football", "full_url": "https://oddspedia.com/football/test"},
                    sport="football",
                )

    def test_football_named_outcomes_are_saved_as_team_fields(self):
        odds = [
            {
                "market": "Draw No Bet",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"Canada": 1.8, "Morocco": 2.0},
                    }
                ],
            },
            {
                "market": "First Team to Score",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"Canada": 1.9, "Morocco": 2.1, "No Goal": 8.5},
                    }
                ],
            },
        ]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(normalized[0]["lines"][0], {"type": "main", "label": "", "home": 1.8, "away": 2.0})
        self.assertEqual(
            normalized[1]["lines"][0],
            {"type": "main", "label": "", "home": 1.9, "away": 2.1, "no_goal": 8.5},
        )

    def test_full_time_result_keeps_only_the_full_time_line(self):
        odds = [{
            "market": "Full Time Result",
            "lines": [
                {"type": "main", "label": "", "home": 2.07, "draw": 3.25, "away": 4.5},
                {"type": "main", "label": "", "home": 2.4, "draw": 2.38, "away": 4.5},
            ],
        }]

        normalized = _normalize_football_odds(odds, home="Switzerland", away="Algeria")

        self.assertEqual(
            normalized[0]["lines"],
            [{"type": "main", "label": "", "home": 2.07, "draw": 3.25, "away": 4.5}],
        )

    def test_odds_extractor_keeps_middle_outcomes_and_no_goal(self):
        """Regression guard for football rows with three or more outcomes."""
        self.assertIn("else if (t.indexOf('NO GOAL') >= 0) dir = 'no_goal';", _JS_EXTRACT_ODDS)
        self.assertIn("buttons.forEach(function(button)", _JS_EXTRACT_ODDS)
        self.assertIn("entry.no_goal = s.val", _JS_EXTRACT_ODDS)

    def test_odds_extractor_supports_nested_and_single_outcome_rows(self):
        """Correct Score and Double Chance use non-standard card row layouts."""
        self.assertIn("var candidates = Array.from(row.querySelectorAll", _JS_EXTRACT_ODDS)
        self.assertIn("containsOddsChild", _JS_EXTRACT_ODDS)
        self.assertIn("parsedCount >= 2 || entry.outcomes", _JS_EXTRACT_ODDS)
        self.assertIn("function parseLooseCard(card)", _JS_EXTRACT_ODDS)
        self.assertIn("var fragmented = lines.length", _JS_EXTRACT_ODDS)

    def test_odds_extractor_recovers_nested_threshold_and_handicap_labels(self):
        """Line labels share a wrapper with odds controls on football cards."""
        self.assertIn("function looksLikeLineLabel(text)", _JS_EXTRACT_ODDS)
        self.assertIn('[class*="label"], [class*="line"], [class*="handicap"]', _JS_EXTRACT_ODDS)
        self.assertIn("if (node.closest('button, a, [role=\"button\"]", _JS_EXTRACT_ODDS)
        self.assertIn("left every total/handicap line with an empty label", _JS_EXTRACT_ODDS)
        self.assertIn("var node = row", _JS_EXTRACT_ODDS)
        self.assertIn("node = node.parentElement", _JS_EXTRACT_ODDS)
        self.assertIn(".matchup-handicap-line-info > [class*=\"text-capitalize\"]", _JS_EXTRACT_ODDS)

    def test_odds_extractor_skips_hidden_period_tabs(self):
        """Hidden 1st/2nd-half panes must not be added to Full Time Result."""
        self.assertIn("function isRendered(el)", _JS_EXTRACT_ODDS)
        self.assertIn("if (!isRendered(rows[r])) continue;", _JS_EXTRACT_ODDS)
        self.assertIn("if (!isRendered(allRows[r])) continue;", _JS_EXTRACT_ODDS)
        self.assertIn('"1:0 Compare', _JS_EXTRACT_ODDS)

    def test_merge_removes_a_duplicate_fallback_schema_line(self):
        unmatched = {
            "market": "Half Time / Full Time",
            "schema_status": "unmatched",
            "lines": [{
                "type": "main", "label": "", "schema_status": "unmatched",
                "combinations": {"home_home": 2.0, "draw_draw": 8.5},
            }],
        }
        normalized = {
            "market": "Half Time / Full Time",
            "lines": [{
                "type": "main", "label": "",
                "combinations": {"home_home": 2.0, "draw_draw": 8.5},
            }],
        }

        merged = _merge_odds_markets([], [unmatched, normalized])

        self.assertEqual(len(merged), 1)
        self.assertEqual(len(merged[0]["lines"]), 1)
        self.assertNotIn("schema_status", merged[0])
        self.assertNotIn("schema_status", merged[0]["lines"][0])

    def test_odds_extractor_preserves_half_time_full_time_combinations(self):
        self.assertIn("var isCompositeOutcome = /[\\/→>]/.test(explicitLabel);", _JS_EXTRACT_ODDS)
        self.assertIn("return {dir: 'outcome', outcome: explicitLabel, val: val};", _JS_EXTRACT_ODDS)

    def test_market_selector_clicks_the_specific_control(self):
        from src.oddspedia.match_scraper import _click_football_market_selector

        # The callable's script is intentionally kept outside the test driver;
        # this guards against reintroducing broad market/filter ancestors.
        class Driver:
            def execute_script(self, script, *_args):
                self.script = script
                return None

        driver = Driver()
        _click_football_market_selector(driver, "Double Chance")
        self.assertIn("function controlFor(el)", driver.script)
        self.assertIn(".btn-group-item__btn, .btn-group-item, li, [tabindex]", driver.script)
        self.assertNotIn("[class*=\"market\"], [class*=\"filter\"]", driver.script)

    def test_market_selector_uses_native_click(self):
        from src.oddspedia.match_scraper import _click_football_market_selector

        class Clickable:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.element = Clickable()
                self.calls = 0

            def execute_script(self, *_args):
                self.calls += 1
                return self.element if self.calls == 1 else None

        driver = Driver()
        self.assertTrue(_click_football_market_selector(driver, "Correct Score"))
        self.assertTrue(driver.element.clicked)

    @patch("src.oddspedia.match_scraper._current_odds_dom_signature", return_value="before")
    @patch("src.oddspedia.match_scraper._click_football_market_selector", return_value=True)
    @patch("src.oddspedia.match_scraper._wait_for_football_market_odds", return_value=[])
    def test_all_unresolved_exposed_markets_are_terminally_unavailable(
        self, _wait, _click, _signature
    ):
        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return ["Double Chance"]
                return []

        with self.assertRaisesRegex(FootballOddsUnavailableError, "Double Chance"):
            _extract_football_odds(Driver(), [], home="Spain", away="Austria")

    @patch("src.oddspedia.match_scraper._wait_for_football_market_card", return_value=True)
    @patch("src.oddspedia.match_scraper._click_football_market_card", return_value=True)
    def test_collapsed_football_cards_are_expanded_before_parsing(self, click_card, wait_card):
        class Driver:
            def execute_script(self, script, *_args):
                if "return Array.from(document.querySelectorAll('.matchup-odds-comparison-card'))" in script:
                    return ["Double Chance", "Correct Score"]
                return None

        _expand_football_market_cards(Driver())
        self.assertEqual(click_card.call_args_list[0].args[1], "Double Chance")
        self.assertEqual(wait_card.call_args_list[1].args[1], "Correct Score")

    def test_expands_alternative_lines_within_the_market_card(self):
        class Button:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.button = Button()
                self.calls = 0

            def execute_script(self, *_args):
                self.calls += 1
                return self.button if self.calls == 1 else None

        driver = Driver()
        self.assertEqual(_expand_football_market_card_lines(driver, "Total Corners"), 1)
        self.assertTrue(driver.button.clicked)

    def test_football_market_list_expansion_uses_one_scoped_control(self):
        from src.oddspedia.match_scraper import _expand_football_market_list

        class Button:
            def __init__(self):
                self.clicked = False

            def click(self):
                self.clicked = True

        class Driver:
            def __init__(self):
                self.button = Button()
                self.card_count = 4

            def execute_script(self, script, *_args):
                if "return {button: button" in script:
                    return {"button": self.button, "cards": self.card_count}
                if "querySelectorAll('.matchup-odds-comparison-card').length" in script:
                    self.card_count = 22
                    return self.card_count
                return None

        driver = Driver()
        expanded = _expand_football_market_list(driver)

        self.assertEqual(expanded, 18)
        self.assertTrue(driver.button.clicked)

    @patch("src.oddspedia.match_scraper._expand_football_market_card_lines", return_value=1)
    @patch("src.oddspedia.match_scraper._wait_for_football_market_card", return_value=True)
    @patch("src.oddspedia.match_scraper._click_football_market_card", return_value=True)
    def test_european_handicap_card_expands_its_alternative_lines(
        self, click_card, wait_card, expand_lines
    ):
        class Driver:
            def execute_script(self, *_args):
                return ["European Handicap"]

        _expand_football_market_cards(Driver())

        click_card.assert_called_once_with(unittest.mock.ANY, "European Handicap")
        wait_card.assert_called_once_with(unittest.mock.ANY, "European Handicap")
        expand_lines.assert_called_once_with(unittest.mock.ANY, "European Handicap")

    @patch("src.oddspedia.match_scraper._expand_football_market_card_lines", return_value=0)
    @patch("src.oddspedia.match_scraper._wait_for_football_market_odds")
    @patch("src.oddspedia.match_scraper._click_football_market_selector", return_value=True)
    @patch("src.oddspedia.match_scraper._current_odds_dom_signature", return_value="before")
    def test_captured_european_handicap_is_not_clicked_as_a_selector(
        self, _signature, _click, wait_for_market, _expand_lines
    ):
        fixture_path = os.path.join(ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json")
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)
        wait_for_market.return_value = fixture["initial"]

        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return ["European Handicap"]
                if script == _JS_EXTRACT_ODDS:
                    return fixture["expanded"]
                return []

        odds = _extract_football_odds(Driver(), fixture["initial"], home="Canada", away="Morocco")

        self.assertEqual(odds[0]["lines"], fixture["initial"][0]["lines"])
        _click.assert_not_called()

    def test_expanded_european_handicap_fixture_preserves_every_line(self):
        fixture_path = os.path.join(ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json")
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)

        normalized = _normalize_football_odds(fixture["expanded"], home="Canada", away="Morocco")

        self.assertEqual(normalized[0]["lines"], fixture["expanded"][0]["lines"])

    @patch("src.oddspedia.match_scraper._expand_football_market_card_lines", return_value=0)
    @patch("src.oddspedia.match_scraper._wait_for_football_market_odds")
    @patch("src.oddspedia.match_scraper._click_football_market_selector", return_value=True)
    @patch("src.oddspedia.match_scraper._current_odds_dom_signature", return_value="before")
    def test_unlabeled_european_handicap_is_skipped_without_retrying_match(
        self, _signature, _click, wait_for_market, _expand_lines
    ):
        fixture_path = os.path.join(ROOT, "tests", "fixtures", "oddspedia", "european_handicap_markets.json")
        with open(fixture_path, encoding="utf-8") as fixture_file:
            fixture = json.load(fixture_file)
        wait_for_market.return_value = fixture["incomplete"]

        class Driver:
            def execute_script(self, script, *_args):
                if "var texts = []" in script:
                    return []
                if script == _JS_EXTRACT_ODDS:
                    return fixture["incomplete"]
                return []

        odds = _extract_football_odds(
            Driver(), fixture["incomplete"], home="Canada", away="Morocco"
        )

        self.assertEqual(odds, [])

    def test_football_correct_score_outcomes_are_saved_as_scores(self):
        odds = [
            {
                "market": "Correct Score",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"1-0": 7.0, "0-0": 9.5},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(normalized[0]["lines"][0]["scores"], {"1-0": 7.0, "0-0": 9.5})
        self.assertNotIn("outcomes", normalized[0]["lines"][0])

    def test_football_market_contract_flags_misclassified_lines(self):
        odds = [
            {
                "market": "Total Goals",
                "lines": [
                    {"type": "main", "label": "2.5", "over": 1.9, "under": 1.9},
                    {"type": "alternative", "label": "1.25", "under": 6.4, "home_away": 1.12},
                ],
            },
            {
                "market": "Asian Handicap",
                "lines": [{"type": "main", "label": "", "yes": 1.83, "no": 1.95}],
            },
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")

        self.assertEqual(len(normalized), 2)
        self.assertEqual(normalized[0]["market"], "Total Goals")
        self.assertEqual(normalized[0]["lines"][0], {"type": "main", "label": "2.5", "over": 1.9, "under": 1.9})
        self.assertEqual(normalized[1]["market"], "Asian Handicap")
        self.assertEqual(normalized[1]["schema_status"], "unmatched")
        self.assertEqual(normalized[1]["lines"][0]["schema_status"], "unmatched")

    def test_football_market_contract_maps_dash_separated_half_time_full_time_outcomes(self):
        odds = [
            {
                "market": "Half Time / Full Time",
                "lines": [
                    {
                        "type": "main",
                        "label": "",
                        "outcomes": {"USA - USA": 2.0, "Draw - USA": 4.5},
                    }
                ],
            }
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")

        self.assertEqual(normalized[0]["market"], "Half Time / Full Time")
        self.assertEqual(
            normalized[0]["lines"][0]["combinations"],
            {"home_home": 2.0, "draw_home": 4.5},
        )
        self.assertNotIn("schema_status", normalized[0])

    def test_football_half_time_full_time_maps_one_x_two_outcomes(self):
        odds = [{
            "market": "Half Time / Full Time",
            "lines": [{
                "type": "main",
                "label": "",
                "outcomes": {
                    "1/1": 2.0, "1/X": 12.0, "1/2": 29.0,
                    "X/1": 7.0, "X/X": 8.5, "X/2": 12.0,
                    "2/1": 34.0, "2/X": 15.0, "2/2": 5.5,
                },
            }],
        }]

        normalized = _normalize_football_odds(odds, home="Canada", away="Morocco")

        self.assertEqual(
            normalized[0]["lines"][0]["combinations"],
            {
                "home_home": 2.0, "home_draw": 12.0, "home_away": 29.0,
                "draw_home": 7.0, "draw_draw": 8.5, "draw_away": 12.0,
                "away_home": 34.0, "away_draw": 15.0, "away_away": 5.5,
            },
        )

    def test_football_selector_context_does_not_relabel_known_stale_market(self):
        markets = [{"market": "Both Teams to Score", "lines": [{"type": "main", "label": "", "yes": 1.9, "no": 1.8}]}]

        contextual = _apply_football_selector_context(markets, "Asian Handicap")

        self.assertEqual(contextual[0]["market"], "Both Teams to Score")

    def test_football_selector_requires_the_requested_market(self):
        stale = [{"market": "Total Goals", "lines": [{"type": "main", "label": "2.5", "over": 1.9, "under": 1.9}]}]
        rendered = [{"market": "Total Corners", "lines": [{"type": "main", "label": "9.5", "over": 1.9, "under": 1.9}]}]

        self.assertFalse(_football_selector_rendered(stale, "Total Corners"))
        self.assertTrue(_football_selector_rendered(rendered, "Total Corners"))

    def test_period_selector_requires_period_context(self):
        markets = [{"market": "1st Half - Total Goals", "lines": [{"type": "main", "label": "0.5", "over": 1.8, "under": 2.0}]}]

        self.assertTrue(_football_selector_rendered(markets, "1st Half"))
        self.assertFalse(_football_selector_rendered(markets, "2nd Half"))

    def test_football_world_cup_market_shapes_are_explicit(self):
        odds = [
            {"market": "Full Time Result", "lines": [{"type": "main", "label": "", "home": 1.4, "draw": 5.0, "away": 8.0}]},
            {"market": "1st Half - Total Goals", "lines": [{"type": "main", "label": "1.5", "over": 2.0, "under": 1.8}]},
            {"market": "Asian Handicap", "lines": [{"type": "main", "label": "-1/+1", "home": 1.9, "away": 1.9}]},
            {"market": "Both Teams to Score", "lines": [{"type": "main", "label": "", "yes": 1.95, "no": 1.83}]},
            {"market": "Double Chance", "lines": [{"type": "main", "label": "", "home_draw": 1.1, "draw_away": 3.2, "home_away": 1.2}]},
            {"market": "Draw No Bet", "lines": [{"type": "main", "label": "", "home": 1.2, "away": 4.5}]},
            {"market": "First Team to Score", "lines": [{"type": "main", "label": "", "home": 1.4, "away": 3.1, "no_goal": 9.0}]},
            {"market": "Correct Score", "lines": [{"type": "main", "label": "", "outcomes": {"1-0": 7.0, "2-0": 9.0}}]},
            {"market": "European Handicap", "lines": [{"type": "main", "label": "-1/+1", "home": 2.1, "draw": 3.7, "away": 3.3}]},
            {"market": "Half Time / Full Time", "lines": [{"type": "main", "label": "", "outcomes": {"USA/USA": 2.0, "Draw/USA": 4.5}}]},
            {"market": "Next Goal", "lines": [{"type": "main", "label": "", "home": 1.3, "away": 3.8, "no_goal": 12.0}]},
            {"market": "Corners Odd or Even", "lines": [{"type": "main", "label": "", "odd": 1.9, "even": 1.9}]},
            {"market": "Clean Sheet", "lines": [{"type": "main", "label": "", "home": 2.0, "away": 8.0}]},
            {"market": "To Win Both Halves", "lines": [{"type": "main", "label": "", "home": 3.0, "away": 34.0}]},
            {"market": "To Score in Both Halves", "lines": [{"type": "main", "label": "", "home": 2.8, "away": 20.0}]},
            {"market": "To Score a Penalty", "lines": [{"type": "main", "label": "", "home": 5.0, "away": 8.0}]},
            {"market": "Total Corners", "lines": [{"type": "main", "label": "9.5", "over": 1.9, "under": 1.9}]},
        ]

        normalized = _normalize_football_odds(odds, home="USA", away="Bosnia-Herzegovina")
        by_market = {market["market"]: market["lines"][0] for market in normalized}

        self.assertNotIn("1st Half - Total Goals", by_market)
        self.assertEqual(
            set(by_market),
            {market["market"] for market in odds if not market["market"].startswith("1st Half -")},
        )
        self.assertEqual(by_market["Half Time / Full Time"]["combinations"], {"home_home": 2.0, "draw_home": 4.5})
        self.assertEqual(by_market["Correct Score"]["scores"], {"1-0": 7.0, "2-0": 9.0})
        self.assertEqual(by_market["Corners Odd or Even"]["odd"], 1.9)
        self.assertNotIn("outcomes", by_market["Half Time / Full Time"])

    def test_market_discovery_excludes_period_tabs_and_card_headers(self):
        self.assertIn("if (/^(1st|2nd) half$/i.test(text)) return;", _JS_FOOTBALL_MARKET_SELECTOR_TEXTS)
        self.assertIn("control.classList.contains('matchup-odds-comparison-card__header')", _JS_FOOTBALL_MARKET_SELECTOR_TEXTS)

    def test_normalization_keeps_only_full_time_markets(self):
        odds = [
            {"market": "European Handicap", "lines": [{"type": "main", "label": "-1/+1", "home": 3.3, "draw": 3.75, "away": 2.0}]},
            {"market": "1st Half - European Handicap", "lines": [{"type": "main", "label": "-1/+1", "home": 6.0, "draw": 4.0, "away": 1.5}]},
            {"market": "2nd Half - Total Goals", "lines": [{"type": "main", "label": "1.5", "over": 1.8, "under": 2.0}]},
        ]

        normalized = _normalize_football_odds(odds, home="Brazil", away="Norway")

        self.assertEqual([market["market"] for market in normalized], ["European Handicap"])

    def test_european_handicap_maps_live_tie_outcome_to_draw(self):
        odds = [{
            "market": "European Handicap",
            "lines": [{
                "type": "main",
                "label": "-1/+1",
                "outcomes": {"Home": 3.3, "Tie": 3.75, "Away": 2.0},
            }],
        }]

        normalized = _normalize_football_odds(odds, home="Brazil", away="Norway")

        self.assertEqual(
            normalized[0]["lines"],
            [{"type": "main", "label": "-1/+1", "home": 3.3, "draw": 3.75, "away": 2.0}],
        )


if __name__ == "__main__":
    unittest.main()
