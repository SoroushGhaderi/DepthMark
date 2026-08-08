from datetime import date, datetime
from pathlib import Path

import pytest

from src.oddspedia.silver.match_resolution import (
    FotMobMatch,
    OddspediaEvent,
    OddspediaBronzeNotPublishedError,
    OddspediaMatchResolver,
    OddspediaResolutionService,
)


PROJECT_ROOT = Path(__file__).resolve().parents[3]


def resolver():
    return OddspediaMatchResolver(
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "scoring_policy.yaml",
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "team_aliases.yaml",
    )


def event(home="Man Utd", away="Chelsea", league_name="Premier League"):
    return OddspediaEvent(
        oddspedia_match_id="odd-1",
        discovery_date=date(2026, 3, 1),
        kickoff_utc=datetime(2026, 3, 1, 16, 30),
        home_team_name=home,
        away_team_name=away,
        league_name=league_name,
    )


def test_resolves_alias_and_exact_team_names_to_coverage_category():
    result = resolver().resolve(
        event(),
        [
            FotMobMatch(
                match_id=123,
                match_date=date(2026, 3, 1),
                kickoff_utc=datetime(2026, 3, 1, 16, 32),
                home_team_name="Manchester United",
                away_team_name="Chelsea FC",
                coverage_level="xG",
                league_name="Premier League",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.fotmob_match_id == 123
    assert result.coverage_category == "xG"
    assert result.confidence == "alias"


def test_qualifier_mismatch_is_never_auto_matched():
    result = resolver().resolve(
        event(home="Copenhagen U19", away="Brondby U19"),
        [
            FotMobMatch(
                match_id=124,
                match_date=date(2026, 3, 1),
                kickoff_utc=datetime(2026, 3, 1, 16, 30),
                home_team_name="Copenhagen",
                away_team_name="Brondby",
                coverage_level="ratings",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "unmatched"
    assert result.coverage_category == "not_covered"


def test_unmatched_is_unresolved_when_reference_completeness_is_not_proven():
    result = resolver().resolve(event(), [], reference_window_complete=False)

    assert result.resolution_status == "unresolved"
    assert result.coverage_category is None


def test_close_candidates_are_ambiguous_instead_of_arbitrarily_selected():
    candidates = [
        FotMobMatch(
            match_id=125,
            match_date=date(2026, 3, 1),
            kickoff_utc=datetime(2026, 3, 1, 16, 30),
            home_team_name="Manchester United",
            away_team_name="Chelsea",
            coverage_level="ratings",
        ),
        FotMobMatch(
            match_id=126,
            match_date=date(2026, 3, 1),
            kickoff_utc=datetime(2026, 3, 1, 16, 31),
            home_team_name="Manchester United",
            away_team_name="Chelsea",
            coverage_level="ratings",
        ),
    ]
    result = resolver().resolve(event(away="Chelsea"), candidates, reference_window_complete=True)

    assert result.resolution_status == "ambiguous"
    assert result.coverage_category is None


def test_unique_exact_pair_matches_when_fotmob_kickoff_is_missing():
    result = resolver().resolve(
        event(home="Elche", away="Espanyol"),
        [
            FotMobMatch(
                match_id=127,
                match_date=date(2026, 3, 1),
                kickoff_utc=None,
                home_team_name="Elche",
                away_team_name="Espanyol",
                coverage_level="xG",
                league_name="LaLiga",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.confidence == "exact"
    assert result.coverage_category == "xG"


def test_spelling_fallback_finds_a_high_similarity_candidate():
    candidate = FotMobMatch(
        match_id=128,
        match_date=date(2026, 3, 1),
        kickoff_utc=None,
        home_team_name="Grasshopper",
        away_team_name="Lugano",
        coverage_level="ratings",
        league_name="Swiss Super League",
    )
    source_event = event(home="Grasshoppers", away="Lugano", league_name="Swiss Super League")

    result = resolver().resolve(
        source_event,
        resolver().candidate_index([candidate]).candidates_for(source_event),
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.confidence == "high_similarity"


def test_uses_team_names_only_inside_the_three_day_window():
    result = resolver().resolve(
        event(home="Elche", away="Espanyol", league_name="Unrelated League"),
        [
            FotMobMatch(
                match_id=129,
                match_date=date(2026, 2, 28),
                kickoff_utc=datetime(2026, 2, 28, 1, 0),
                home_team_name="Elche",
                away_team_name="Espanyol",
                coverage_level="xG",
                league_name="LaLiga",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.match_score == 100.0
    assert result.time_difference_minutes is None


def test_matches_distinctive_short_team_name_to_a_longer_provider_name():
    result = resolver().resolve(
        event(home="Brighton", away="Chelsea"),
        [
            FotMobMatch(
                match_id=130,
                match_date=date(2026, 3, 1),
                kickoff_utc=None,
                home_team_name="Brighton Hove Albion",
                away_team_name="Chelsea",
                coverage_level="xG",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.home_match_rule == "fuzzy_token_containment"
    assert result.match_score == 96.0


def test_matches_reordered_team_tokens_without_weakening_team_identity():
    result = resolver().resolve(
        event(home="Red Bull Salzburg", away="Chelsea"),
        [
            FotMobMatch(
                match_id=131,
                match_date=date(2026, 3, 1),
                kickoff_utc=None,
                home_team_name="Salzburg Red Bull",
                away_team_name="Chelsea",
                coverage_level="ratings",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.home_match_rule == "fuzzy_token_reordered"


def test_does_not_treat_a_short_generic_name_as_approximate_identity():
    result = resolver().resolve(
        event(home="United", away="Chelsea"),
        [
            FotMobMatch(
                match_id=132,
                match_date=date(2026, 3, 1),
                kickoff_utc=None,
                home_team_name="Manchester United",
                away_team_name="Chelsea",
                coverage_level="ratings",
            )
        ],
        reference_window_complete=True,
    )

    assert result.resolution_status == "unmatched"


def test_matches_club_designators_without_weakening_qualifier_matching():
    source_event = event(home="CSD Tristan Suarez", away="San Martin de San Juan")
    candidate = FotMobMatch(
        match_id=133,
        match_date=date(2026, 3, 1),
        kickoff_utc=None,
        home_team_name="Tristan Suarez",
        away_team_name="San Martin San Juan",
        coverage_level="ratings",
    )
    match_resolver = resolver()

    result = match_resolver.resolve_from_index(
        source_event,
        match_resolver.candidate_index([candidate]),
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.home_match_rule == "exact"
    assert result.coverage_category == "ratings"


def test_canonicalizes_second_team_numeral_as_a_qualifier():
    source_event = event(home="Houston Dynamo II", away="Colorado Rapids II")
    candidate = FotMobMatch(
        match_id=134,
        match_date=date(2026, 3, 1),
        kickoff_utc=None,
        home_team_name="Houston Dynamo 2",
        away_team_name="Colorado Rapids 2",
        coverage_level="lower",
    )
    match_resolver = resolver()

    result = match_resolver.resolve_from_index(
        source_event,
        match_resolver.candidate_index([candidate]),
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.home_match_rule == "exact"
    assert result.away_match_rule == "exact"


def test_uses_a_unique_token_only_when_the_opposite_team_is_an_anchor():
    source_event = event(home="Emmen", away="Utrecht Youth")
    candidate = FotMobMatch(
        match_id=135,
        match_date=date(2026, 3, 1),
        kickoff_utc=None,
        home_team_name="FC Emmen",
        away_team_name="Jong FC Utrecht",
        coverage_level="xG",
    )
    match_resolver = resolver()

    result = match_resolver.resolve_from_index(
        source_event,
        match_resolver.candidate_index([candidate]),
        reference_window_complete=True,
    )

    assert result.resolution_status == "matched"
    assert result.home_match_rule == "exact"
    assert result.away_match_rule == "fuzzy_unique_token"


def test_does_not_use_two_unique_tokens_without_an_exact_or_alias_anchor():
    source_event = event(home="Alpha United", away="Utrecht Youth")
    candidate = FotMobMatch(
        match_id=136,
        match_date=date(2026, 3, 1),
        kickoff_utc=None,
        home_team_name="Alpha City",
        away_team_name="Jong FC Utrecht",
        coverage_level="xG",
    )
    match_resolver = resolver()

    result = match_resolver.resolve_from_index(
        source_event,
        match_resolver.candidate_index([candidate]),
        reference_window_complete=True,
    )

    assert result.resolution_status == "unmatched"


def test_resolution_requires_a_published_oddspedia_bronze_batch():
    class _UnpublishedClient:
        def execute(self, query, parameters):
            return type("Result", (), {"result_rows": [("staging",)]})()

    with pytest.raises(OddspediaBronzeNotPublishedError):
        OddspediaResolutionService(_UnpublishedClient(), resolver()).resolve_date(
            date(2026, 3, 1), reference_window_complete=False, persist=False
        )
