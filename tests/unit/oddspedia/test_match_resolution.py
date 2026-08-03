from datetime import date, datetime
from pathlib import Path

from src.oddspedia.silver.match_resolution import (
    FotMobMatch,
    OddspediaEvent,
    OddspediaMatchResolver,
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
