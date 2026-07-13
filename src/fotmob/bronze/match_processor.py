"""Match data processor: converts raw API data to structured format."""
import hashlib
import re
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
from pydantic import ValidationError as PydanticValidationError

from ...core import ProcessorProtocol
from ...models import (
    CardEventMatchFacts,
    FlatPlayerStats,
    GeneralMatchStats,
    GoalEventHeader,
    GoalEventMatchFacts,
    LineupPlayer,
    MatchTimeline,
    MatchVenue,
    MomentumDataPoint,
    PeriodStats,
    RedCardEvent,
    ShotEvent,
    SubstitutePlayer,
    SubstitutionEvent,
    TeamCoach,
    TeamFormMatch,
)
from src.fotmob.validation import FotMobValidator, SafeFieldExtractor
from src.common.logging import get_logger

logger = get_logger(__name__)


# Period statistics key mapping: API key -> (home_field, away_field)
PERIOD_STAT_KEY_MAPPING: Dict[str, Tuple[str, str]] = {
    "BallPossesion": ("ball_possession_home", "ball_possession_away"),
    "expected_goals": ("expected_goals_home", "expected_goals_away"),
    "total_shots": ("total_shots_home", "total_shots_away"),
    "ShotsOnTarget": ("shots_on_target_home", "shots_on_target_away"),
    "big_chance": ("big_chances_home", "big_chances_away"),
    "big_chance_missed_title": ("big_chances_missed_home", "big_chances_missed_away"),
    "accurate_passes": ("accurate_passes_home", "accurate_passes_away"),
    "fouls": ("fouls_home", "fouls_away"),
    "corners": ("corners_home", "corners_away"),
    # API sometimes emits "shots" as an alias of total shots.
    # Map directly to total_shots_* to align with bronze.period schema.
    "shots": ("total_shots_home", "total_shots_away"),
    "ShotsOffTarget": ("shots_off_target_home", "shots_off_target_away"),
    "blocked_shots": ("blocked_shots_home", "blocked_shots_away"),
    "shots_woodwork": ("shots_woodwork_home", "shots_woodwork_away"),
    "shots_sidebox": ("shots_sidebox_home", "shots_sidebox_away"),
    "shots_inside_box": ("shots_inside_box_home", "shots_inside_box_away"),
    "shots_outside_box": ("shots_outside_box_home", "shots_outside_box_away"),
    "expected_goals_open_play": ("expected_goals_open_play_home", "expected_goals_open_play_away"),
    "expected_goals_set_play": ("expected_goals_set_play_home", "expected_goals_set_play_away"),
    "expected_goals_non_penalty": (
        "expected_goals_non_penalty_home",
        "expected_goals_non_penalty_away",
    ),
    "expected_goals_on_target": ("expected_goals_on_target_home", "expected_goals_on_target_away"),
    "physical_metrics_distance_covered": ("distance_covered_home", "distance_covered_away"),
    "physical_metrics_walking": ("walking_distance_home", "walking_distance_away"),
    "physical_metrics_running": ("running_distance_home", "running_distance_away"),
    "physical_metrics_sprinting": ("sprinting_distance_home", "sprinting_distance_away"),
    "physical_metrics_number_of_sprints": ("number_of_sprints_home", "number_of_sprints_away"),
    "physical_metrics_topspeed": ("top_speed_home", "top_speed_away"),
    # Aliases seen in some payload variants (without physical_metrics_ prefix).
    "distance_covered": ("distance_covered_home", "distance_covered_away"),
    "walking": ("walking_distance_home", "walking_distance_away"),
    "running": ("running_distance_home", "running_distance_away"),
    "sprinting": ("sprinting_distance_home", "sprinting_distance_away"),
    "number_of_sprints": ("number_of_sprints_home", "number_of_sprints_away"),
    "passes": ("passes_home", "passes_away"),
    "own_half_passes": ("own_half_passes_home", "own_half_passes_away"),
    "opposition_half_passes": ("opposition_half_passes_home", "opposition_half_passes_away"),
    "long_balls_accurate": ("long_balls_accurate_home", "long_balls_accurate_away"),
    "accurate_crosses": ("accurate_crosses_home", "accurate_crosses_away"),
    "player_throws": ("player_throws_home", "player_throws_away"),
    "touches_opp_box": ("touches_opp_box_home", "touches_opp_box_away"),
    "Offsides": ("offsides_home", "offsides_away"),
    "matchstats.headers.tackles": ("tackles_succeeded_home", "tackles_succeeded_away"),
    "interceptions": ("interceptions_home", "interceptions_away"),
    "shot_blocks": ("shot_blocks_home", "shot_blocks_away"),
    "clearances": ("clearances_home", "clearances_away"),
    "keeper_saves": ("keeper_saves_home", "keeper_saves_away"),
    "duel_won": ("duels_won_home", "duels_won_away"),
    "ground_duels_won": ("ground_duels_won_home", "ground_duels_won_away"),
    "aerials_won": ("aerials_won_home", "aerials_won_away"),
    "dribbles_succeeded": ("dribbles_succeeded_home", "dribbles_succeeded_away"),
    "yellow_cards": ("yellow_cards_home", "yellow_cards_away"),
    "red_cards": ("red_cards_home", "red_cards_away"),
}

# Fields that contain ratio values (e.g., "5/10") instead of numeric values
RATIO_STAT_FIELDS = frozenset(
    {
        "accurate_passes",
        "long_balls_accurate",
        "accurate_crosses",
        "matchstats.headers.tackles",
        "ground_duels_won",
        "aerials_won",
        "dribbles_succeeded",
    }
)


class FotMobBronzeMatchProcessor(ProcessorProtocol):
    """Process raw FotMob bronze data into structured bronze tables."""

    _INT64_MIN = -(2**63)
    _INT64_MAX = (2**63) - 1

    def __init__(
        self,
        validator: Optional[FotMobValidator] = None,
        extractor: Optional[SafeFieldExtractor] = None,
    ):
        """
        Initialize the match processor with dependency injection.

        Args:
            validator: FotMobValidator instance for response validation.
                If None, creates a default instance.
            extractor: SafeFieldExtractor instance for safe field access.
                If None, creates a default instance.
        """
        self.logger = logger
        self.validator = validator or FotMobValidator()
        self.extractor = extractor or SafeFieldExtractor()
        self._processed_match_count = 0

    @staticmethod
    def _split_full_score(full_score: Optional[str]) -> Tuple[Optional[int], Optional[int]]:
        """Parse score strings like '2-1' or '2 - 1' into home/away integer scores."""
        if not full_score:
            return None, None

        match = re.match(r"^\s*(\d+)\s*-\s*(\d+)\s*$", str(full_score))
        if not match:
            return None, None

        return int(match.group(1)), int(match.group(2))

    @staticmethod
    def _extract_year_from_datetime(value: Optional[str]) -> Optional[str]:
        """Extract YYYY from ISO-like datetime strings."""
        if not value:
            return None
        match = re.match(r"^\s*(\d{4})", str(value))
        return match.group(1) if match else None

    def _generate_synthetic_lineup_player_id(
        self,
        match_id: int,
        team_side: str,
        player_raw: Dict[str, Any],
        used_ids: set,
    ) -> Tuple[int, str]:
        """Generate deterministic synthetic Int64 id from stable player attributes."""
        base_key = (
            f"match:{int(match_id)}|"
            f"team_side:{team_side}|"
            f"shirt_number:{player_raw.get('shirtNumber')}|"
            f"name:{(player_raw.get('name') or '').strip().lower()}|"
            f"first_name:{(player_raw.get('firstName') or '').strip().lower()}|"
            f"last_name:{(player_raw.get('lastName') or '').strip().lower()}|"
            f"country_code:{(player_raw.get('countryCode') or '').strip().lower()}|"
            f"position:{player_raw.get('usualPlayingPositionId')}"
        )

        salt = 0
        while True:
            key = base_key if salt == 0 else f"{base_key}_{salt}"
            digest_value = int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:16], 16)
            # Keep synthetic IDs in high positive Int64 range to satisfy key contracts.
            synthetic_id = self._INT64_MAX - (digest_value % 1_000_000_000_000_000)
            if synthetic_id not in used_ids:
                used_ids.add(synthetic_id)
                return synthetic_id, key
            salt += 1

    @staticmethod
    def _resolve_numeric_id(raw_id: Any) -> Optional[int]:
        """Resolve integer ids from mixed raw values."""
        if isinstance(raw_id, int):
            return raw_id
        if isinstance(raw_id, str) and raw_id.isdigit():
            return int(raw_id)
        return None

    def _collect_used_lineup_player_ids(self, lineup_raw: Dict[str, Any]) -> set:
        """Collect all valid positive lineup ids across home/away starters+subs."""
        used_ids = set()
        for team_key in ("homeTeam", "awayTeam"):
            team_raw = lineup_raw.get(team_key, {})
            if not isinstance(team_raw, dict):
                continue
            for section_key in ("starters", "subs"):
                section_raw = team_raw.get(section_key, [])
                if not isinstance(section_raw, list):
                    continue
                for player_raw in section_raw:
                    if not isinstance(player_raw, dict):
                        continue
                    resolved_id = self._resolve_numeric_id(player_raw.get("id"))
                    if resolved_id is not None and resolved_id > 0:
                        used_ids.add(resolved_id)
        return used_ids

    def _generate_synthetic_goal_event_id(
        self,
        match_id: int,
        goal_time: Any,
        goal_overload_time: Any,
        home_score: Any,
        away_score: Any,
        is_home: Any,
        player_id: Any,
        player_name: Any,
        assist_player_id: Any,
        goal_description: Any,
    ) -> int:
        """Generate deterministic positive Int64 id for goal events without valid event ids."""
        raw_key = (
            f"{int(match_id)}|{goal_time}|{goal_overload_time}|{home_score}|{away_score}|"
            f"{is_home}|{player_id}|{player_name}|{assist_player_id}|{goal_description}"
        )
        digest_value = int(hashlib.sha256(raw_key.encode("utf-8")).hexdigest()[:16], 16)
        return (digest_value % self._INT64_MAX) + 1

    def _resolve_positive_event_id(
        self,
        raw_event_id: Any,
        synthetic_seed: str,
        table_name: str,
        match_id: Any,
        id_field: str = "event_id",
        fallback_source_field: Optional[str] = None,
        fallback_source_value: Any = None,
        event_time: Any = None,
        player_id: Any = None,
    ) -> int:
        """Return a positive event_id, generating deterministic fallback when needed."""
        resolved_source_event_id = self._resolve_numeric_id(raw_event_id)
        if resolved_source_event_id is not None and resolved_source_event_id > 0:
            return resolved_source_event_id

        resolved_fallback_id = self._resolve_numeric_id(fallback_source_value)
        if resolved_fallback_id is not None and resolved_fallback_id > 0:
            self.logger.warning(
                "Filled invalid source id using fallback id",
                table_name=table_name,
                id_field=id_field,
                match_id=match_id,
                source_id=raw_event_id,
                resolved_id=resolved_fallback_id,
                strategy="fallback",
                fallback_source_field=fallback_source_field,
                fallback_source_value=fallback_source_value,
                event_time=event_time,
                player_id=player_id,
            )
            return resolved_fallback_id

        digest_value = int(hashlib.sha256(synthetic_seed.encode("utf-8")).hexdigest()[:16], 16)
        event_id = (digest_value % self._INT64_MAX) + 1
        self.logger.warning(
            "Filled invalid source id using synthetic id",
            table_name=table_name,
            id_field=id_field,
            match_id=match_id,
            source_id=raw_event_id,
            resolved_id=event_id,
            strategy="synthetic",
            synthetic_seed=synthetic_seed,
            event_time=event_time,
            player_id=player_id,
        )
        return event_id

    def _generate_synthetic_player_id_int32(self, seed: str) -> int:
        """Generate deterministic positive Int32 player id."""
        digest_value = int(hashlib.sha256(seed.encode("utf-8")).hexdigest()[:8], 16)
        # Keep synthetic ids in a high positive Int32 range.
        return 1_500_000_000 + (digest_value % 647_483_647)

    def process_all(
        self, raw_response: Dict[str, Any], validate_before_processing: bool = True
    ) -> Tuple[Dict[str, Any], Optional[Dict[str, Any]]]:
        """
        Process all match data with validation and optional response saving.

        Args:
            raw_response: Raw API response
            validate_before_processing: If True, validate response before processing

        Returns:
            Tuple of (processed_dataframes, validation_summary)
        """
        match_id = self.extractor.safe_get_nested(
            raw_response, "general", "matchId", default="unknown"
        )

        # Validate response
        validation_summary = None
        if validate_before_processing:
            validation_summary = self.validator.get_validation_summary(raw_response)

            if not validation_summary["is_valid"]:
                self.logger.warning(
                    f"Validation failed for match {match_id} with "
                    f"{validation_summary['error_count']} errors. Processing anyway..."
                )
                # Log errors
                for error in validation_summary["errors"]:
                    self.logger.error(f"  - {error}")
            else:
                self.logger.debug(f"[OK] Validation passed for match {match_id}")

        # Process data
        self.logger.debug("Processing match payload", match_id=match_id)
        general_stats = self.process_general_stats(raw_response)
        processed_data = {
            "match_reference": self.process_match_reference(general_stats),
            "general": general_stats,
            "timeline": self.process_match_timeline(raw_response),
            "goal": self.process_goal_events_from_header(raw_response),
            "red_card": self.process_red_card_events(raw_response),
            "cards_only": self.process_match_facts_events(raw_response),
            "venue": self.process_infobox_data(raw_response),
            "team_form": self.process_team_form_data(raw_response),
            "momentum": self.process_momentum_data(raw_response),
            "period": self.process_period_stats(raw_response),
            "player": self.process_flat_player_stats(raw_response),
            "shotmap": self.process_shotmap_data(raw_response),
            "lineup_data": self.process_lineup_data(raw_response),
        }
        dataframes = self._convert_to_dataframes(processed_data)
        self._processed_match_count += 1
        if self._processed_match_count % 100 == 0:
            self.logger.info(
                "Processed match batch",
                processed_matches=self._processed_match_count,
                latest_match_id=match_id,
            )
        else:
            self.logger.debug("Completed processing match", match_id=match_id)

        return dataframes, validation_summary

    @staticmethod
    def _extract_match_date(
        match_time_utc_date: Optional[str],
        match_time_utc: Optional[str],
    ) -> str:
        """Resolve a stable YYYY-MM-DD match date for the bronze match reference."""
        for raw_value in (match_time_utc_date, match_time_utc):
            if not raw_value:
                continue
            date_match = re.match(r"^\s*(\d{4}-\d{2}-\d{2})", str(raw_value))
            if date_match:
                return date_match.group(1)
        return "1970-01-01"

    def process_match_reference(
        self, general_stats: Optional[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Process the compact match reference row for bronze filters."""
        if not general_stats:
            return None

        match_reference_fields = {
            "match_id",
            "match_date",
            "match_time_utc",
            "match_time_utc_date",
            "match_round",
            "coverage_level",
            "league_id",
            "league_name",
            "league_round_name",
            "parent_league_id",
            "parent_league_name",
            "parent_league_season",
            "parent_league_tournament_id",
            "country_code",
            "home_team_id",
            "home_team_name",
            "away_team_id",
            "away_team_name",
            "match_started",
            "match_finished",
            "full_score",
            "home_score",
            "away_score",
        }
        match_reference = {
            key: value
            for key, value in general_stats.items()
            if key in match_reference_fields
        }
        match_reference["match_date"] = self._extract_match_date(
            general_stats.get("match_time_utc_date"),
            general_stats.get("match_time_utc"),
        )
        return match_reference

    def _convert_to_dataframes(self, processed_data: Dict[str, Any]) -> Dict[str, pd.DataFrame]:
        """Convert processed data to DataFrames."""
        dataframes = {}
        for key, value in processed_data.items():
            if isinstance(value, list):
                if value:
                    dataframes[key] = pd.DataFrame(value)
                else:
                    dataframes[key] = pd.DataFrame()
            elif isinstance(value, dict):
                if key == "cards_only":
                    for event_type, events in value.items():
                        if events and event_type not in ["goals", "substitutions"]:
                            dataframes[event_type] = pd.DataFrame(events)
                elif key == "lineup_data":
                    for lineup_type, lineup_items in value.items():
                        if lineup_items:
                            if isinstance(lineup_items, list):
                                dataframes[lineup_type] = pd.DataFrame(lineup_items)
                            else:
                                dataframes[lineup_type] = pd.DataFrame([lineup_items])
                        else:
                            dataframes[lineup_type] = pd.DataFrame()
                else:
                    dataframes[key] = pd.DataFrame([value])
            elif value is not None:
                dataframes[key] = pd.DataFrame([value])
        return dataframes

    def process_match_timeline(self, response_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Process match timeline data with safe field extraction."""
        try:
            self.logger.debug("Processing timeline data")

            # Use safe extraction
            timeline_dict = {
                "match_id": self.extractor.safe_get_nested(response_data, "general", "matchId"),
                "match_time_utc": self.extractor.safe_get_nested(
                    response_data, "header", "status", "utcTime"
                ),
                "first_half_started": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "firstHalfStarted"
                ),
                "first_half_ended": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "firstHalfEnded"
                ),
                "second_half_started": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "secondHalfStarted"
                ),
                "second_half_ended": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "secondHalfEnded"
                ),
                "first_extra_half_started": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "firstExtraHalfStarted"
                ),
                "second_extra_half_started": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "secondExtraHalfStarted"
                ),
                "game_ended": self.extractor.safe_get_nested(
                    response_data, "header", "status", "halfs", "gameEnded"
                ),
                "game_finished": self.extractor.safe_get_nested(
                    response_data, "header", "status", "finished"
                ),
                "game_started": self.extractor.safe_get_nested(
                    response_data, "header", "status", "started"
                ),
                "game_cancelled": self.extractor.safe_get_nested(
                    response_data, "header", "status", "cancelled"
                ),
            }

            validated_timeline = MatchTimeline(**timeline_dict)
            return validated_timeline.model_dump()
        except PydanticValidationError as e:
            self.logger.error(f"Validation failed for timeline: {e}")
            self.logger.debug(f"Timeline data: {timeline_dict}")
        except Exception as e:
            self.logger.exception(f"Error processing timeline: {e}")
        return None

    def process_general_stats(self, response_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Process general match statistics."""
        try:
            self.logger.debug("Processing general stats")
            general_data = response_data.get("general")
            if not general_data:
                self.logger.error("General data not found")
                return None
            team_colors_dark = general_data.get("teamColors", {}).get("darkMode", {})
            team_colors_light = general_data.get("teamColors", {}).get("lightMode", {})
            full_score = self.extractor.safe_get_nested(
                response_data, "header", "status", "scoreStr"
            )
            home_score, away_score = self._split_full_score(full_score)
            tournament_info = self.extractor.safe_get_nested(
                response_data, "content", "matchFacts", "infoBox", "Tournament"
            )
            if not isinstance(tournament_info, dict):
                tournament_info = {}

            match_time_utc_date = general_data.get("matchTimeUTCDate")
            parent_league_name = (
                general_data.get("parentLeagueName")
                or tournament_info.get("leagueName")
                or general_data.get("leagueName")
            )
            parent_league_tournament_id = (
                general_data.get("parentLeagueTournamentId")
                or tournament_info.get("id")
                or general_data.get("leagueId")
            )
            parent_league_season = (
                general_data.get("parentLeagueSeason")
                or tournament_info.get("season")
                or tournament_info.get("seasonName")
                or self._extract_year_from_datetime(match_time_utc_date)
            )

            processed_data = {
                "match_id": general_data.get("matchId"),
                "match_round": general_data.get("matchRound"),
                "team_color_dark_mode_home": team_colors_dark.get("home"),
                "team_color_dark_mode_away": team_colors_dark.get("away"),
                "team_color_light_mode_home": team_colors_light.get("home"),
                "team_color_light_mode_away": team_colors_light.get("away"),
                "league_id": general_data.get("leagueId"),
                "league_name": general_data.get("leagueName"),
                "league_round_name": general_data.get("leagueRoundName"),
                "parent_league_id": general_data.get("parentLeagueId"),
                "country_code": general_data.get("countryCode"),
                "parent_league_name": parent_league_name,
                "parent_league_season": parent_league_season,
                "parent_league_tournament_id": parent_league_tournament_id,
                "home_team_name": general_data.get("homeTeam", {}).get("name"),
                "home_team_id": general_data.get("homeTeam", {}).get("id"),
                "away_team_name": general_data.get("awayTeam", {}).get("name"),
                "away_team_id": general_data.get("awayTeam", {}).get("id"),
                "coverage_level": general_data.get("coverageLevel"),
                "match_time_utc": general_data.get("matchTimeUTC"),
                "match_time_utc_date": match_time_utc_date,
                "match_started": general_data.get("started", False),
                "match_finished": general_data.get("finished", False),
                "full_score": full_score,
                "home_score": home_score,
                "away_score": away_score,
            }
            validated_stats = GeneralMatchStats(**processed_data)
            return validated_stats.model_dump()
        except PydanticValidationError as e:
            self.logger.error(f"Validation failed for general stats: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing general stats: {e}")
        return None

    def process_goal_events_from_header(
        self, response_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Process goal events from header section."""
        all_goal_dicts = []
        try:
            self.logger.debug("Processing goal events")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                self.logger.warning("No match_id found, skipping goal events")
                return all_goal_dicts
            header = response_data.get("header", {})
            events = header.get("events", {})
            if not isinstance(events, dict):
                return all_goal_dicts
            goal_data_sources = [
                (events.get("homeTeamGoals", {}), "Home"),
                (events.get("awayTeamGoals", {}), "Away"),
            ]
            for team_goals_data, team_name in goal_data_sources:
                if not isinstance(team_goals_data, dict):
                    continue
                for _, scorer_stats_list in team_goals_data.items():
                    if not isinstance(scorer_stats_list, list):
                        continue
                    for scorer_stat in scorer_stats_list:
                        if not isinstance(scorer_stat, dict):
                            continue
                        player_data = scorer_stat.get("player", {}) or {}
                        shotmap_data = scorer_stat.get("shotmapEvent", {}) or {}
                        goal_time = scorer_stat.get("time")
                        if goal_time is None:
                            goal_time = shotmap_data.get("min")

                        raw_event_id = scorer_stat.get("eventId")

                        player_id = player_data.get("id")
                        if player_id is None:
                            player_id = scorer_stat.get("playerId")

                        shot_event_id = shotmap_data.get("id")
                        shot_event_id = int(shot_event_id) if shot_event_id is not None else None
                        seed_event_id = self._generate_synthetic_goal_event_id(
                            match_id=int(match_id),
                            goal_time=goal_time,
                            goal_overload_time=scorer_stat.get("overloadTime"),
                            home_score=scorer_stat.get("homeScore"),
                            away_score=scorer_stat.get("awayScore"),
                            is_home=scorer_stat.get("isHome"),
                            player_id=player_id,
                            player_name=player_data.get("name"),
                            assist_player_id=scorer_stat.get("assistPlayerId"),
                            goal_description=scorer_stat.get("goalDescription"),
                        )
                        event_id = self._resolve_positive_event_id(
                            raw_event_id=raw_event_id,
                            synthetic_seed=f"goal|{seed_event_id}",
                            table_name="goal",
                            match_id=match_id,
                            fallback_source_field="shot_event_id",
                            fallback_source_value=shot_event_id,
                            event_time=goal_time,
                            player_id=player_id,
                        )

                        flat_goal_data = {
                            "match_id": match_id,
                            "event_id": event_id,
                            "goal_time": goal_time,
                            "goal_overload_time": scorer_stat.get("overloadTime"),
                            "home_score": scorer_stat.get("homeScore"),
                            "away_score": scorer_stat.get("awayScore"),
                            "is_home": scorer_stat.get("isHome"),
                            "is_own_goal": scorer_stat.get("ownGoal", False),
                            "goal_description": scorer_stat.get("goalDescription"),
                            "assist_player_id": scorer_stat.get("assistPlayerId"),
                            "assist_player_name": scorer_stat.get("assistInput"),
                            "player_id": player_id,
                            "player_name": player_data.get("name"),
                            "shot_event_id": shot_event_id,
                            "shot_x_loc": shotmap_data.get("x"),
                            "shot_y_loc": shotmap_data.get("y"),
                            "shot_minute": (
                                shotmap_data.get("min")
                                if shotmap_data.get("min") is not None
                                else shotmap_data.get("minute")
                            ),
                            "shot_minute_added": (
                                shotmap_data.get("minAdded")
                                if shotmap_data.get("minAdded") is not None
                                else shotmap_data.get("mAdded")
                            ),
                            "shot_expected_goal": shotmap_data.get("expectedGoals"),
                            "shot_expected_goal_on_target": shotmap_data.get(
                                "expectedGoalsOnTarget"
                            ),
                            "shot_type": shotmap_data.get("shotType"),
                            "shot_situation": shotmap_data.get("situation"),
                            "shot_period": shotmap_data.get("period"),
                            "shot_from_inside_box": shotmap_data.get("isFromInsideBox"),
                        }
                        try:
                            validated_event = GoalEventHeader(**flat_goal_data)
                            goal_dict = validated_event.model_dump()
                            all_goal_dicts.append(goal_dict)
                        except PydanticValidationError as e:
                            self.logger.warning(
                                f"Validation error for goal event (match {match_id}, event_id {scorer_stat.get('eventId')}): {e}"
                            )
                            self.logger.debug(f"Goal data that failed validation: {flat_goal_data}")
                        except Exception as e:
                            self.logger.error(
                                f"Unexpected error processing goal event: {e}", exc_info=True
                            )
            if len(all_goal_dicts) > 0:
                self.logger.debug(
                    f"Processed {len(all_goal_dicts)} goal events for match {match_id}"
                )
            else:
                self.logger.debug(f"No goal events found for match {match_id}")
        except Exception as e:
            self.logger.exception(f"Error processing goal events for match {match_id}: {e}")
        return all_goal_dicts

    def process_red_card_events(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Process red card events."""
        all_red_cards = []
        try:
            self.logger.debug("Processing red card events")
            header = response_data.get("header", {})
            events = header.get("events", {})
            match_id = response_data.get("general", {}).get("matchId")
            if not isinstance(events, dict) or not match_id:
                return all_red_cards
            team_red_cards_sources = [
                (events.get("homeTeamRedCards", {}), "Home"),
                (events.get("awayTeamRedCards", {}), "Away"),
            ]
            for team_red_card_data, team_name in team_red_cards_sources:
                if not isinstance(team_red_card_data, dict):
                    continue
                for _, player_stats_list in team_red_card_data.items():
                    if not isinstance(player_stats_list, list):
                        continue
                    for player_stat in player_stats_list:
                        if not isinstance(player_stat, dict):
                            continue
                        player_data = player_stat.get("player", {}) or {}
                        red_card_time = player_stat.get("time")
                        player_id = player_data.get("id")
                        event_id = self._resolve_positive_event_id(
                            raw_event_id=player_stat.get("eventId"),
                            synthetic_seed=(
                                f"red_card|{match_id}|{red_card_time}|{player_stat.get('overloadTime')}|"
                                f"{player_id}|{player_data.get('name')}|{player_stat.get('homeScore')}|"
                                f"{player_stat.get('awayScore')}|{player_stat.get('isHome')}"
                            ),
                            table_name="red_card",
                            match_id=match_id,
                            event_time=red_card_time,
                            player_id=player_id,
                        )
                        flat_data = {
                            "match_id": match_id,
                            "event_id": event_id,
                            "red_card_time": red_card_time,
                            "red_card_overload_time": player_stat.get("overloadTime"),
                            "player_id": player_id,
                            "player_name": player_data.get("name"),
                            "home_score": player_stat.get("homeScore"),
                            "away_score": player_stat.get("awayScore"),
                            "is_home": player_stat.get("isHome"),
                        }
                        try:
                            validated_event = RedCardEvent(**flat_data)
                            all_red_cards.append(validated_event.model_dump())
                        except PydanticValidationError as e:
                            self.logger.error(f"Validation error for red card: {e}")
                        except Exception as e:
                            self.logger.exception(f"Error processing red cards: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing red card events: {e}")
        return all_red_cards

    def process_match_facts_events(
        self, response_data: Dict[str, Any]
    ) -> Dict[str, List[Dict[str, Any]]]:
        """Process match facts events."""
        results = {"goals": [], "cards": [], "substitutions": [], "added_time": [], "half_time": []}
        try:
            self.logger.debug("Processing match facts events")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return results
            events_list = (
                response_data.get("content", {})
                .get("matchFacts", {})
                .get("events", {})
                .get("events", [])
            )
            if not isinstance(events_list, list):
                return results
            for event in events_list:
                if not isinstance(event, dict):
                    continue
                event_type = event.get("type")
                # Only cards are materialized from match facts into bronze tables.
                if event_type in ("Goal", "Substitution"):
                    continue
                if event_type == "Goal":
                    shotmap_event = event.get("shotmapEvent", {}) or {}
                    event_id = self._resolve_positive_event_id(
                        raw_event_id=event.get("eventId"),
                        synthetic_seed=(
                            f"match_facts_goal|{match_id}|{event.get('time')}|{event.get('overloadTime')}|"
                            f"{event.get('homeScore')}|{event.get('awayScore')}|{event.get('isHome')}|"
                            f"{event.get('player', {}).get('id')}|{event.get('assistPlayerId')}"
                        ),
                        table_name="match_facts_goal",
                        match_id=match_id,
                        event_time=event.get("time"),
                        player_id=event.get("player", {}).get("id"),
                    )
                    goal_data = {
                        "match_id": match_id,
                        "event_id": event_id,
                        "time": event.get("time"),
                        "added_time": event.get("overloadTime"),
                        "player_id": event.get("player", {}).get("id"),
                        "player_name": event.get("player", {}).get("name"),
                        "player_profile_url": event.get("player", {}).get("profileUrl"),
                        "team": "Home" if event.get("isHome") else "Away",
                        "score": f"{event.get('homeScore')}-{event.get('awayScore')}",
                        "new_score": event.get("newScore", []),
                        "shot_type": shotmap_event.get("shotType"),
                        "xg": shotmap_event.get("expectedGoals"),
                        "xg_ot": shotmap_event.get("expectedGoalsOnTarget"),
                        "situation": shotmap_event.get("situation"),
                        "assist_player": event.get("assistInput"),
                        "assist_id": event.get("assistPlayerId"),
                        "shot_x": shotmap_event.get("x"),
                        "shot_y": shotmap_event.get("y"),
                    }
                    try:
                        validated = GoalEventMatchFacts(**goal_data)
                        results["goals"].append(validated.model_dump())
                    except PydanticValidationError as e:
                        self.logger.error(f"Validation error for goal: {e}")
                elif event_type == "Card":
                    card_description = event.get("cardDescription")
                    if isinstance(card_description, dict):
                        description_text = (
                            card_description.get("defaultText")
                            or card_description.get("localizedKey")
                            or None
                        )
                    else:
                        description_text = (
                            card_description if isinstance(card_description, str) else None
                        )
                    event_id = self._resolve_positive_event_id(
                        raw_event_id=event.get("eventId"),
                        synthetic_seed=(
                            f"match_facts_card|{match_id}|{event.get('time')}|{event.get('overloadTime')}|"
                            f"{event.get('homeScore')}|{event.get('awayScore')}|{event.get('isHome')}|"
                            f"{event.get('player', {}).get('id')}|{event.get('card')}"
                        ),
                        table_name="cards",
                        match_id=match_id,
                        event_time=event.get("time"),
                        player_id=event.get("player", {}).get("id"),
                    )
                    card_data = {
                        "match_id": match_id,
                        "event_id": event_id,
                        "time": event.get("time"),
                        "added_time": event.get("overloadTime"),
                        "player_id": event.get("player", {}).get("id"),
                        "player_name": event.get("player", {}).get("name"),
                        "player_profile_url": event.get("player", {}).get("profileUrl"),
                        "team": "Home" if event.get("isHome") else "Away",
                        "card_type": event.get("card"),
                        "description": description_text,
                        "score": f"{event.get('homeScore')}-{event.get('awayScore')}",
                    }
                    try:
                        validated = CardEventMatchFacts(**card_data)
                        results["cards"].append(validated.model_dump())
                    except PydanticValidationError as e:
                        self.logger.error(f"Validation error for card: {e}")
                elif event_type == "Substitution":
                    swap = event.get("swap", [{}, {}])
                    player_in = swap[0] if len(swap) > 0 else {}
                    player_out = swap[1] if len(swap) > 1 else {}
                    sub_data = {
                        "match_id": match_id,
                        "time": event.get("time"),
                        "added_time": event.get("overloadTime"),
                        "team": "Home" if event.get("isHome") else "Away",
                        "player_in_id": player_in.get("id"),
                        "player_in_name": player_in.get("name"),
                        "player_in_profile_url": player_in.get("profileUrl"),
                        "player_out_id": player_out.get("id"),
                        "player_out_name": player_out.get("name"),
                        "player_out_profile_url": player_out.get("profileUrl"),
                        "injured": event.get("injuredPlayerOut", False),
                        "score": f"{event.get('homeScore')}-{event.get('awayScore')}",
                    }
                    try:
                        validated = SubstitutionEvent(**sub_data)
                        results["substitutions"].append(validated.model_dump())
                    except PydanticValidationError as e:
                        self.logger.error(f"Validation error for substitution: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing match facts events: {e}")
        return results

    def process_momentum_data(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Process momentum data."""
        processed_points = []
        try:
            self.logger.debug("Processing momentum data")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return processed_points
            momentum_main_data = (
                response_data.get("content", {})
                .get("matchFacts", {})
                .get("momentum", {})
                .get("main", {})
                .get("data", [])
            )
            for point_raw in momentum_main_data:
                if not isinstance(point_raw, dict):
                    continue
                value = point_raw.get("value")
                momentum_team = "neutral"
                if value is not None:
                    if value > 0:
                        momentum_team = "home"
                    elif value < 0:
                        momentum_team = "away"
                processed_data = {
                    "match_id": match_id,
                    "minute": point_raw.get("minute"),
                    "value": value,
                    "momentum_team": momentum_team,
                }
                try:
                    validated_data = MomentumDataPoint(**processed_data)
                    processed_points.append(validated_data.model_dump())
                except PydanticValidationError as e:
                    self.logger.error(f"Validation error for momentum point: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing momentum data: {e}")
        return processed_points

    def _parse_stat_values(self, key: str, values_raw: List[Any]) -> List[Any]:
        """Parse stat values, handling ratio fields and type conversion.

        Args:
            key: The stat key name
            values_raw: List of raw values (typically [home_value, away_value])

        Returns:
            List of parsed values with appropriate types
        """
        values = []
        for v_raw in values_raw:
            try:
                if v_raw is None:
                    values.append(None)
                elif key in RATIO_STAT_FIELDS:
                    # Keep ratio fields as strings (e.g., "5/10")
                    values.append(str(v_raw))
                elif (
                    isinstance(v_raw, str)
                    and "/" not in v_raw
                    and v_raw.replace(".", "", 1).isdigit()
                ):
                    # Convert numeric strings to numbers
                    values.append(float(v_raw) if "." in v_raw else int(v_raw))
                elif isinstance(v_raw, (int, float)):
                    values.append(v_raw)
                else:
                    values.append(str(v_raw))
            except (ValueError, TypeError):
                values.append(None if v_raw is None else str(v_raw))
        return values

    def process_period_stats(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Process period statistics."""
        results = []
        try:
            self.logger.debug("Processing period stats")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return results
            stats = response_data.get("content", {}).get("stats") or {}
            periods_raw = stats.get("Periods")
            if not periods_raw or not isinstance(periods_raw, dict):
                return results

            for period_name, period_data_raw in periods_raw.items():
                if not isinstance(period_data_raw, dict):
                    continue
                flat_data = {"match_id": match_id, "period": period_name}
                team_colors = period_data_raw.get("teamColors", {})
                if isinstance(team_colors, dict):
                    light_mode = team_colors.get("lightMode", {})
                    if isinstance(light_mode, dict):
                        flat_data["home_color"] = light_mode.get("home")
                        flat_data["away_color"] = light_mode.get("away")
                for group in period_data_raw.get("stats", []):
                    if not isinstance(group, dict):
                        continue
                    for stat_item in group.get("stats", []):
                        if not isinstance(stat_item, dict):
                            continue
                        key = stat_item.get("key")
                        values_raw = stat_item.get("stats")
                        if not key or not isinstance(values_raw, list) or len(values_raw) != 2:
                            continue
                        values = self._parse_stat_values(key, values_raw)
                        if key in PERIOD_STAT_KEY_MAPPING:
                            home_field, away_field = PERIOD_STAT_KEY_MAPPING[key]
                            flat_data[home_field] = values[0]
                            flat_data[away_field] = values[1]

                # FotMob commonly emits `shots_inside_box` but not `shots_sidebox`.
                # Keep legacy `shots_sidebox_*` populated for schema compatibility.
                if "shots_sidebox_home" not in flat_data and "shots_inside_box_home" in flat_data:
                    flat_data["shots_sidebox_home"] = flat_data.get("shots_inside_box_home")
                if "shots_sidebox_away" not in flat_data and "shots_inside_box_away" in flat_data:
                    flat_data["shots_sidebox_away"] = flat_data.get("shots_inside_box_away")

                # Populate source-style physical metric aliases from normalized fields.
                alias_pairs = (
                    ("distance_covered_home", "physical_metrics_distance_covered_home"),
                    ("distance_covered_away", "physical_metrics_distance_covered_away"),
                    ("walking_distance_home", "physical_metrics_walking_home"),
                    ("walking_distance_away", "physical_metrics_walking_away"),
                    ("running_distance_home", "physical_metrics_running_home"),
                    ("running_distance_away", "physical_metrics_running_away"),
                    ("sprinting_distance_home", "physical_metrics_sprinting_home"),
                    ("sprinting_distance_away", "physical_metrics_sprinting_away"),
                    ("number_of_sprints_home", "physical_metrics_number_of_sprints_home"),
                    ("number_of_sprints_away", "physical_metrics_number_of_sprints_away"),
                )
                for source_field, alias_field in alias_pairs:
                    if alias_field not in flat_data and source_field in flat_data:
                        flat_data[alias_field] = flat_data.get(source_field)
                try:
                    validated = PeriodStats(**flat_data)
                    # Avoid emitting deprecated/unused optional fields as null columns.
                    results.append(validated.model_dump(exclude_none=True))
                except PydanticValidationError as e:
                    self.logger.error(f"Validation error for period stats: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing period stats: {e}")
        return results

    def process_flat_player_stats(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Process player statistics."""
        all_player_stats = []
        try:
            self.logger.debug("Processing player stats")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return all_player_stats
            player_stats_raw_map = response_data.get("content", {}).get("playerStats", {})
            if not isinstance(player_stats_raw_map, dict):
                return all_player_stats
            for player_id_str, player_data_raw in player_stats_raw_map.items():
                if not isinstance(player_data_raw, dict):
                    continue
                raw_player_id = player_data_raw.get("id")
                resolved_player_id = None
                if isinstance(raw_player_id, int):
                    resolved_player_id = raw_player_id
                elif isinstance(raw_player_id, str) and raw_player_id.isdigit():
                    resolved_player_id = int(raw_player_id)

                if (
                    (resolved_player_id is None or resolved_player_id <= 0)
                    and isinstance(player_id_str, str)
                    and player_id_str.isdigit()
                ):
                    parsed_key_id = int(player_id_str)
                    if parsed_key_id > 0:
                        resolved_player_id = parsed_key_id

                if resolved_player_id is None or resolved_player_id <= 0:
                    synthetic_seed = (
                        f"player|{match_id}|{player_id_str}|{player_data_raw.get('name')}|"
                        f"{player_data_raw.get('teamId')}|{player_data_raw.get('optaId')}"
                    )
                    resolved_player_id = self._generate_synthetic_player_id_int32(synthetic_seed)
                    self.logger.warning(
                        "Filled invalid source id using synthetic id",
                        table_name="player",
                        id_field="player_id",
                        match_id=match_id,
                        source_id=raw_player_id,
                        source_map_key=player_id_str,
                        resolved_id=resolved_player_id,
                        strategy="synthetic",
                        synthetic_seed=synthetic_seed,
                        player_name=player_data_raw.get("name"),
                    )
                flat_data = {
                    "match_id": match_id,
                    "id": resolved_player_id,
                    "name": player_data_raw.get("name"),
                    "opta_id": player_data_raw.get("optaId"),
                    "team_id": player_data_raw.get("teamId"),
                    "team_name": player_data_raw.get("teamName"),
                    "is_goalkeeper": player_data_raw.get("isGoalkeeper", False),
                }
                fun_facts = []
                for fact in player_data_raw.get("funFacts", []):
                    if not isinstance(fact, dict):
                        continue
                    fallback = fact.get("fallback")
                    if isinstance(fallback, str):
                        cleaned_fallback = fallback.strip()
                        if cleaned_fallback:
                            fun_facts.append(cleaned_fallback)
                if fun_facts:
                    flat_data["fun_facts"] = fun_facts
                for group in player_data_raw.get("stats", []):
                    if not isinstance(group, dict):
                        continue
                    for stat_name, stat_detail in group.get("stats", {}).items():
                        if not isinstance(stat_detail, dict):
                            continue
                        key = stat_detail.get("key")
                        value = stat_detail.get("stat", {}).get("value")
                        total = stat_detail.get("stat", {}).get("total")
                        if key == "rating_title":
                            flat_data["fotmob_rating"] = value
                        elif key in ("minutes_played", "mins_played"):
                            flat_data["minutes_played"] = value
                        elif key == "goals":
                            flat_data["goals"] = value
                        elif key == "assists":
                            flat_data["assists"] = value
                        elif key == "total_shots":
                            flat_data["total_shots"] = value
                        elif key == "ShotsOnTarget":
                            flat_data["shots_on_target"] = value
                            if flat_data.get("total_shots") and value:
                                flat_data["shots_off_target"] = flat_data["total_shots"] - value
                        elif key == "blocked_shots":
                            flat_data["blocked_shots"] = value
                        elif key == "expected_goals":
                            flat_data["expected_goals"] = value
                        elif key == "expected_goals_non_penalty":
                            flat_data["xg_non_penalty"] = value
                        elif key == "expected_assists":
                            flat_data["expected_assists"] = value
                        elif key == "xg_and_xa":
                            flat_data["xg_plus_xa"] = value
                        elif key == "touches":
                            flat_data["touches"] = value
                        elif key == "touches_opp_box":
                            flat_data["touches_opp_box"] = value
                        elif key == "accurate_passes":
                            if value is not None:
                                flat_data["accurate_passes"] = value
                            if total is not None:
                                flat_data["total_passes"] = total
                            if total and total > 0 and value is not None:
                                flat_data["pass_accuracy"] = round((value / total) * 100, 1)
                        elif key in ("passes_into_final_third", "passes_to_final_third"):
                            flat_data["passes_final_third"] = value
                        elif key == "accurate_crosses":
                            flat_data["accurate_crosses"] = value
                            if total is not None:
                                flat_data["cross_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["cross_success_rate"] = round((value / total) * 100, 1)
                        elif key == "long_balls_accurate":
                            flat_data["accurate_long_balls"] = value
                            if total is not None:
                                flat_data["long_ball_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["long_ball_success_rate"] = round(
                                    (value / total) * 100, 1
                                )
                        elif key == "matchstats.headers.tackles":
                            flat_data["tackles_won"] = value
                            if total is not None:
                                flat_data["tackle_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["tackle_success_rate"] = round((value / total) * 100, 1)
                        elif key == "interceptions":
                            flat_data["interceptions"] = value
                        elif key == "clearances":
                            flat_data["clearances"] = value
                        elif key == "recoveries":
                            flat_data["recoveries"] = value
                        elif key == "defensive_actions":
                            flat_data["defensive_actions"] = value
                        elif key == "dribbles_succeeded":
                            flat_data["successful_dribbles"] = value
                            if total is not None:
                                flat_data["dribble_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["dribble_success_rate"] = round((value / total) * 100, 1)
                        elif key == "dribbled_past":
                            flat_data["dribbled_past"] = value
                        elif key == "ground_duels_won":
                            flat_data["ground_duels_won"] = value
                            if total is not None:
                                flat_data["ground_duel_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["ground_duel_success_rate"] = round(
                                    (value / total) * 100, 1
                                )
                        elif key == "aerials_won":
                            flat_data["aerial_duels_won"] = value
                            if total is not None:
                                flat_data["aerial_duel_attempts"] = total
                            if total and total > 0 and value is not None:
                                flat_data["aerial_duel_success_rate"] = round(
                                    (value / total) * 100, 1
                                )
                        elif key == "duel_won":
                            flat_data["duels_won"] = value
                        elif key == "duel_lost":
                            flat_data["duels_lost"] = value
                        elif key == "fouls":
                            flat_data["fouls_committed"] = value
                        elif key == "was_fouled":
                            flat_data["was_fouled"] = value
                        elif key == "chances_created":
                            flat_data["chances_created"] = value
                        elif key == "shot_blocks":
                            if "blocked_shots" not in flat_data:
                                flat_data["blocked_shots"] = value
                shotmap_raw = player_data_raw.get("shotmap", [])
                if isinstance(shotmap_raw, list) and shotmap_raw:
                    flat_data["shotmap_count"] = len(shotmap_raw)
                    total_xg_shotmap = sum(
                        s.get("expectedGoals", 0) or 0 for s in shotmap_raw if isinstance(s, dict)
                    )
                    flat_data["total_xg"] = round(total_xg_shotmap, 2)
                    if len(shotmap_raw) > 0:
                        flat_data["average_xg_per_shot"] = round(
                            total_xg_shotmap / len(shotmap_raw), 2
                        )
                try:
                    validated = FlatPlayerStats(**flat_data)
                    player_dict = validated.model_dump(by_alias=False)
                    if "id" in player_dict:
                        player_dict["player_id"] = player_dict.pop("id")
                    if "name" in player_dict:
                        player_dict["player_name"] = player_dict.pop("name")
                    all_player_stats.append(player_dict)
                except PydanticValidationError as e:
                    match_id = flat_data.get("match_id", "unknown")
                    player_id = flat_data.get("id", "unknown")
                    self.logger.warning(
                        f"Validation error for player {player_id} match {match_id}: {e}"
                    )
                    self.logger.debug(f"Player data that failed validation: {flat_data}")
                except Exception as e:
                    self.logger.error(
                        f"Unexpected error processing player stats: {e}", exc_info=True
                    )
        except Exception as e:
            self.logger.exception(f"Error processing player stats: {e}")
        if len(all_player_stats) > 0:
            match_id = response_data.get("general", {}).get("matchId", "unknown")
            self.logger.debug(
                f"Processed {len(all_player_stats)} player stats for match {match_id}"
            )
        else:
            match_id = response_data.get("general", {}).get("matchId", "unknown")
            self.logger.debug(f"No player stats found for match {match_id}")
        return all_player_stats

    def process_shotmap_data(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Process shotmap data."""
        processed_shots = []
        try:
            self.logger.debug("Processing shotmap data")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return processed_shots
            shots_raw = response_data.get("content", {}).get("shotmap", {}).get("shots", [])
            if not isinstance(shots_raw, list):
                return processed_shots
            for shot_raw in shots_raw:
                if not isinstance(shot_raw, dict):
                    continue
                on_goal_shot = shot_raw.get("onGoalShot", {}) or {}
                if not isinstance(on_goal_shot, dict):
                    on_goal_shot = {}
                processed_shot = {
                    "match_id": match_id,
                    "id": shot_raw.get("id"),
                    "event_type": shot_raw.get("eventType"),
                    "team_id": shot_raw.get("teamId"),
                    "player_id": shot_raw.get("playerId"),
                    "player_name": shot_raw.get("playerName"),
                    "x": shot_raw.get("x"),
                    "y": shot_raw.get("y"),
                    "min": (
                        shot_raw.get("min")
                        if shot_raw.get("min") is not None
                        else shot_raw.get("minute")
                    ),
                    "min_added": (
                        shot_raw.get("minAdded")
                        if shot_raw.get("minAdded") is not None
                        else shot_raw.get("mAdded")
                    ),
                    "is_blocked": shot_raw.get("isBlocked"),
                    "is_on_target": shot_raw.get("isOnTarget"),
                    "blocked_x": shot_raw.get("blockedX"),
                    "blocked_y": shot_raw.get("blockedY"),
                    "goal_crossed_y": shot_raw.get("goalCrossedY"),
                    "goal_crossed_z": shot_raw.get("goalCrossedZ"),
                    "expected_goals": shot_raw.get("expectedGoals"),
                    "expected_goals_on_target": shot_raw.get("expectedGoalsOnTarget"),
                    "shot_type": shot_raw.get("shotType"),
                    "situation": shot_raw.get("situation"),
                    "period": shot_raw.get("period"),
                    "is_own_goal": shot_raw.get("isOwnGoal"),
                    "on_goal_shot_x": on_goal_shot.get("x"),
                    "on_goal_shot_y": on_goal_shot.get("y"),
                    "on_goal_shot_zoom_ratio": on_goal_shot.get("zoomRatio"),
                    "is_saved_off_line": shot_raw.get("isSavedOffLine"),
                    "is_from_inside_box": shot_raw.get("isFromInsideBox"),
                    "keeper_id": shot_raw.get("keeperId"),
                    "first_name": shot_raw.get("firstName"),
                    "last_name": shot_raw.get("lastName"),
                    "full_name": shot_raw.get("fullName"),
                    "team_color": shot_raw.get("teamColor"),
                }
                try:
                    validated_shot = ShotEvent(**processed_shot)
                    shot_dict = validated_shot.model_dump()
                    processed_shots.append(shot_dict)
                except PydanticValidationError as e:
                    self.logger.warning(
                        f"Validation error for shot event (match {match_id}, shot id {shot_raw.get('id')}): {e}"
                    )
                    self.logger.debug(f"Shot data that failed validation: {processed_shot}")
                except Exception as e:
                    self.logger.error(f"Unexpected error processing shot event: {e}", exc_info=True)
        except Exception as e:
            self.logger.exception(f"Error processing shotmap for match {match_id}: {e}")
        if len(processed_shots) > 0:
            self.logger.debug(f"Processed {len(processed_shots)} shots for match {match_id}")
        else:
            self.logger.debug(f"No shots found for match {match_id}")
        return processed_shots

    def process_lineup_data(self, response_data: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
        """
        Process lineup data (starters, subs, coaches).
        IMPROVED: Combines home/away to single dataframes with team_side field
        to prevent redundant folders and files.
        """
        lineup_output = {"starters": [], "substitutes": [], "coaches": []}
        try:
            self.logger.debug("Processing lineup data")
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return lineup_output
            lineup_raw = response_data.get("content", {}).get("lineup", {})
            if not isinstance(lineup_raw, dict):
                return lineup_output
            used_lineup_player_ids = self._collect_used_lineup_player_ids(lineup_raw)
            home_team_raw = lineup_raw.get("homeTeam", {})
            if isinstance(home_team_raw, dict):
                home_starters = self._process_lineup_players(
                    home_team_raw.get("starters", []),
                    LineupPlayer,
                    match_id,
                    team_side="home",
                    used_ids=used_lineup_player_ids,
                )
                home_substitutes = self._process_lineup_players(
                    home_team_raw.get("subs", []),
                    SubstitutePlayer,
                    match_id,
                    team_side="home",
                    used_ids=used_lineup_player_ids,
                )
                lineup_output["starters"].extend(home_starters)
                lineup_output["substitutes"].extend(home_substitutes)
                home_coach_raw = home_team_raw.get("coach", {})
                if isinstance(home_coach_raw, dict) and home_coach_raw:
                    home_coach = self._process_coach(home_coach_raw, match_id, team_side="home")
                    if home_coach:
                        lineup_output["coaches"].append(home_coach)
            away_team_raw = lineup_raw.get("awayTeam", {})
            if isinstance(away_team_raw, dict):
                away_starters = self._process_lineup_players(
                    away_team_raw.get("starters", []),
                    LineupPlayer,
                    match_id,
                    team_side="away",
                    used_ids=used_lineup_player_ids,
                )
                away_substitutes = self._process_lineup_players(
                    away_team_raw.get("subs", []),
                    SubstitutePlayer,
                    match_id,
                    team_side="away",
                    used_ids=used_lineup_player_ids,
                )
                lineup_output["starters"].extend(away_starters)
                lineup_output["substitutes"].extend(away_substitutes)
                away_coach_raw = away_team_raw.get("coach", {})
                if isinstance(away_coach_raw, dict) and away_coach_raw:
                    away_coach = self._process_coach(away_coach_raw, match_id, team_side="away")
                    if away_coach:
                        lineup_output["coaches"].append(away_coach)
        except Exception as e:
            self.logger.exception(f"Error processing lineup: {e}")
        return lineup_output

    def _process_lineup_players(
        self,
        players_raw: List[Dict[str, Any]],
        player_model,
        match_id: int,
        team_side: str = "home",
        used_ids: Optional[set] = None,
    ) -> List[Dict[str, Any]]:
        """
        Helper to process lineup players.
        Args:
            team_side: "home" or "away" indicates which team this player belongs to
        """
        processed_players = []
        if not isinstance(players_raw, list):
            return processed_players
        if used_ids is None:
            used_ids = set()
        for player_raw in players_raw:
            if not isinstance(player_raw, dict):
                continue
            raw_player_id = player_raw.get("id")
            resolved_player_id = self._resolve_numeric_id(raw_player_id)

            if resolved_player_id is None or resolved_player_id <= 0:
                synthetic_id, synthetic_key = self._generate_synthetic_lineup_player_id(
                    match_id=match_id,
                    team_side=team_side,
                    player_raw=player_raw,
                    used_ids=used_ids,
                )
                player_id = synthetic_id
                self.logger.warning(
                    "Filled invalid source id using synthetic id",
                    table_name="lineup",
                    id_field="player_id",
                    match_id=match_id,
                    source_id=raw_player_id,
                    resolved_id=player_id,
                    strategy="synthetic",
                    synthetic_seed=synthetic_key,
                    team_side=team_side,
                    player_name=player_raw.get("name"),
                )
            else:
                player_id = resolved_player_id
            player_data = {
                "match_id": match_id,
                "team_side": team_side,
                "player_id": player_id,
                "name": player_raw.get("name"),
                "age": player_raw.get("age"),
                "shirt_number": player_raw.get("shirtNumber"),
                "usual_playing_position_id": player_raw.get("usualPlayingPositionId"),
                "first_name": player_raw.get("firstName"),
                "last_name": player_raw.get("lastName"),
                "country_name": player_raw.get("countryName"),
                "country_code": player_raw.get("countryCode"),
            }
            if player_model == LineupPlayer:
                player_data.update(
                    {
                        "position_id": player_raw.get("positionId"),
                        "is_captain": player_raw.get("isCaptain", False),
                    }
                )
            h_layout = player_raw.get("horizontalLayout", {})
            if h_layout:
                player_data.update(
                    {
                        "horizontal_x": h_layout.get("x"),
                        "horizontal_y": h_layout.get("y"),
                        "horizontal_height": h_layout.get("height"),
                        "horizontal_width": h_layout.get("width"),
                    }
                )
            v_layout = player_raw.get("verticalLayout", {})
            if v_layout:
                player_data.update(
                    {
                        "vertical_x": v_layout.get("x"),
                        "vertical_y": v_layout.get("y"),
                        "vertical_height": v_layout.get("height"),
                        "vertical_width": v_layout.get("width"),
                    }
                )
            performance = player_raw.get("performance", {})
            if performance:
                player_data["performance_rating"] = performance.get("rating")
                sub_events = performance.get("substitutionEvents", [])
                if sub_events and len(sub_events) > 0:
                    first_sub = sub_events[0]
                    player_data.update(
                        {
                            "substitution_time": first_sub.get("time"),
                            "substitution_type": first_sub.get("type"),
                            "substitution_reason": first_sub.get("reason"),
                        }
                    )
            try:
                validated_player = player_model(**player_data)
                processed_players.append(validated_player.model_dump())
            except PydanticValidationError as e:
                self.logger.error(f"Validation error for player {player_raw.get('id')}: {e}")
        return processed_players

    def _process_coach(
        self, coach_raw: Dict[str, Any], match_id: int, team_side: str = "home"
    ) -> Dict[str, Any]:
        """
        Helper to process coach data.
        Args:
            team_side: "home" or "away" indicates which team this coach belongs to
        """
        try:
            raw_coach_id = coach_raw.get("id")
            resolved_coach_id = self._resolve_numeric_id(raw_coach_id)
            if resolved_coach_id is None or resolved_coach_id <= 0:
                synthetic_seed = (
                    f"coach|{match_id}|{team_side}|{coach_raw.get('name')}|"
                    f"{coach_raw.get('firstName')}|{coach_raw.get('lastName')}|"
                    f"{coach_raw.get('countryCode')}|{coach_raw.get('primaryTeamId')}"
                )
                resolved_coach_id = self._INT64_MAX - (
                    int(hashlib.sha256(synthetic_seed.encode("utf-8")).hexdigest()[:16], 16)
                    % 1_000_000_000_000_000
                )
                self.logger.warning(
                    "Filled invalid source id using synthetic id",
                    table_name="coaches",
                    id_field="coach_id",
                    match_id=match_id,
                    source_id=raw_coach_id,
                    resolved_id=resolved_coach_id,
                    strategy="synthetic",
                    synthetic_seed=synthetic_seed,
                    team_side=team_side,
                    coach_name=coach_raw.get("name"),
                )
            coach_data = {
                "match_id": match_id,
                "team_side": team_side,
                "id": resolved_coach_id,
                "age": coach_raw.get("age"),
                "name": coach_raw.get("name"),
                "first_name": coach_raw.get("firstName"),
                "last_name": coach_raw.get("lastName"),
                "country_name": coach_raw.get("countryName"),
                "country_code": coach_raw.get("countryCode"),
                "primary_team_id": coach_raw.get("primaryTeamId"),
                "primary_team_name": coach_raw.get("primaryTeamName"),
                "is_coach": coach_raw.get("isCoach", True),
            }
            validated_coach = TeamCoach(**coach_data)
            return validated_coach.model_dump()
        except PydanticValidationError as e:
            self.logger.error(f"Validation error for coach {coach_raw.get('id')}: {e}")
            return {}
        except Exception as e:
            self.logger.error(f"Error processing coach: {e}")
            return {}

    def process_infobox_data(self, response_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process venue, stadium, attendance, and match information from InfoBox.
        Extracts:
        - Stadium details (name, city, country, capacity, surface, GPS coordinates)
        - Attendance
        - Referee information
        - Match date and tournament info
        """
        try:
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return {}
            infobox = response_data.get("content", {}).get("matchFacts", {}).get("infoBox", {})
            if not isinstance(infobox, dict):
                return {}
            stadium = infobox.get("Stadium", {})
            stadium_data = {}
            if isinstance(stadium, dict):
                stadium_data = {
                    "stadium_name": stadium.get("name"),
                    "stadium_city": stadium.get("city"),
                    "stadium_country": stadium.get("country"),
                    "stadium_latitude": stadium.get("lat"),
                    "stadium_longitude": stadium.get("long"),
                    "stadium_capacity": stadium.get("capacity"),
                    "stadium_surface": stadium.get("surface"),
                }
            attendance = infobox.get("Attendance")
            referee = infobox.get("Referee", {})
            referee_data = {}
            if isinstance(referee, dict):
                referee_data = {
                    "referee_name": referee.get("text"),
                    "referee_country": referee.get("country"),
                    "referee_image_url": referee.get("imgUrl"),
                }
            match_date = infobox.get("Match Date", {})
            match_date_data = {}
            if isinstance(match_date, dict):
                match_date_data = {
                    "match_date_utc": match_date.get("utcTime"),
                    "match_date_verified": match_date.get("isDateCorrect"),
                }
            tournament = infobox.get("Tournament", {})
            tournament_data = {}
            if isinstance(tournament, dict):
                tournament_data = {
                    "tournament_id": tournament.get("id"),
                    "tournament_name": tournament.get("leagueName"),
                    "tournament_round": tournament.get("round"),
                    "tournament_parent_league_id": tournament.get("parentLeagueId"),
                    "tournament_link": tournament.get("link"),
                }
            venue_data = {
                "match_id": match_id,
                "attendance": attendance,
                **stadium_data,
                **referee_data,
                **match_date_data,
                **tournament_data,
            }
            validated_venue = MatchVenue(**venue_data)
            return validated_venue.model_dump()
        except PydanticValidationError as e:
            self.logger.error(f"Validation error for venue data: {e}")
            return {}
        except Exception as e:
            self.logger.exception(f"Error processing venue data: {e}")
            return {}

    def process_team_form_data(self, response_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Process team form data to flattened structure with team_side field.
        Returns list of TeamFormMatch objects (one per past match for each team).
        Following the same consolidation pattern as lineup data.
        """
        processed_form = []
        try:
            match_id = response_data.get("general", {}).get("matchId")
            if not match_id:
                return processed_form
            team_form_raw = (
                response_data.get("content", {}).get("matchFacts", {}).get("teamForm", [])
            )
            if not isinstance(team_form_raw, list) or len(team_form_raw) != 2:
                return processed_form
            for team_idx, (team_side, form_matches) in enumerate(
                [("home", team_form_raw[0]), ("away", team_form_raw[1])]
            ):
                if not isinstance(form_matches, list):
                    continue
                for position, past_match in enumerate(form_matches[:5], start=1):
                    if not isinstance(past_match, dict):
                        continue
                    result = past_match.get("result", 0)
                    result_string = past_match.get("resultString", "")
                    score = past_match.get("score")
                    date_obj = past_match.get("date", {})
                    form_match_date = (
                        date_obj.get("utcTime") if isinstance(date_obj, dict) else None
                    )
                    match_link = past_match.get("lkToMatch", "")
                    form_match_id = match_link.split("#")[-1] if "#" in match_link else None
                    home_info = past_match.get("home", {})
                    away_info = past_match.get("away", {})
                    home_is_our_team = (
                        home_info.get("isOurTeam", False) if isinstance(home_info, dict) else False
                    )
                    if isinstance(home_info, dict) and isinstance(away_info, dict):
                        home_team_id = int(home_info.get("id")) if home_info.get("id") else None
                        home_team_name = home_info.get("name")
                        away_team_id = int(away_info.get("id")) if away_info.get("id") else None
                        away_team_name = away_info.get("name")
                        if home_is_our_team:
                            team_id = home_team_id
                            team_name = home_team_name
                            opponent_id = away_team_id
                            opponent_name = away_team_name
                            is_home_match = True
                        else:
                            team_id = away_team_id
                            team_name = away_team_name
                            opponent_id = home_team_id
                            opponent_name = home_team_name
                            is_home_match = False
                    else:
                        team_id = None
                        team_name = None
                        opponent_id = None
                        opponent_name = None
                        is_home_match = None
                        home_team_id = None
                        home_team_name = None
                        away_team_id = None
                        away_team_name = None
                    tooltip = past_match.get("tooltipText", {})
                    if isinstance(tooltip, dict):
                        home_score = tooltip.get("homeScore")
                        away_score = tooltip.get("awayScore")
                    else:
                        home_score = None
                        away_score = None
                    form_match_data = {
                        "match_id": match_id,
                        "team_side": team_side,
                        "team_id": team_id,
                        "team_name": team_name,
                        "form_position": position,
                        "result": result,
                        "result_string": result_string,
                        "score": score,
                        "form_match_date": form_match_date,
                        "form_match_id": form_match_id,
                        "form_match_link": match_link,
                        "opponent_id": opponent_id,
                        "opponent_name": opponent_name,
                        "opponent_image_url": past_match.get("imageUrl"),
                        "is_home_match": is_home_match,
                        "home_team_id": home_team_id,
                        "home_team_name": home_team_name,
                        "home_score": home_score,
                        "away_team_id": away_team_id,
                        "away_team_name": away_team_name,
                        "away_score": away_score,
                    }
                    try:
                        validated_form = TeamFormMatch(**form_match_data)
                        processed_form.append(validated_form.model_dump())
                    except PydanticValidationError as e:
                        self.logger.error(f"Validation error for team form match: {e}")
        except Exception as e:
            self.logger.exception(f"Error processing team form data: {e}")
        return processed_form


# Backward-compatible alias; prefer FotMobBronzeMatchProcessor in new code.
MatchProcessor = FotMobBronzeMatchProcessor
