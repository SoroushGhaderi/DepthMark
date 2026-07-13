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


def event(home="Man Utd", away="Chelsea"):
    return OddspediaEvent(
        oddspedia_match_id="odd-1",
        discovery_date=date(2026, 3, 1),
        kickoff_utc=datetime(2026, 3, 1, 16, 30),
        home_team_name=home,
        away_team_name=away,
        league_name="Premier League",
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
