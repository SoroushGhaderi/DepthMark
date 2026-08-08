from datetime import date, datetime
from pathlib import Path

import pytest

from src.oddspedia.scraping import link_prioritization
from src.oddspedia.scraping.link_prioritization import (
    LinkPriorityService,
    load_priority_artifact,
    priority_artifact_is_current,
    save_priority_artifact,
    select_links_for_priority,
)
from src.oddspedia.silver.match_resolution import OddspediaMatchResolver
from src.oddspedia.silver.match_resolution import ReferenceWindowNotReadyError


PROJECT_ROOT = Path(__file__).resolve().parents[3]


class _QueryResult:
    def __init__(self, rows):
        self.result_rows = rows


class _FakeClient:
    def __init__(self, rows):
        self.rows = rows
        self.queries = []

    def execute(self, query, parameters):
        self.queries.append((query, parameters))
        if "FROM bronze.match_reference" in query:
            candidate_rows = [(row[0], row[1]) for row in self.rows]
            return _QueryResult(
                [
                    (900001, date(2026, 2, 28)),
                    (900000, date(2026, 3, 1)),
                    *candidate_rows,
                    (900002, date(2026, 3, 2)),
                ]
            )
        if "oddspedia_reference_window:silver" in query:
            candidate_rows = [(row[0], row[1]) for row in self.rows]
            return _QueryResult(
                [
                    (900001, date(2026, 2, 28)),
                    (900000, date(2026, 3, 1)),
                    *candidate_rows,
                    (900002, date(2026, 3, 2)),
                ]
            )
        return _QueryResult(self.rows)


@pytest.fixture
def resolver():
    return OddspediaMatchResolver(
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "scoring_policy.yaml",
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "team_aliases.yaml",
    )


@pytest.fixture
def source_links():
    return [
        {
            "id": "odd-xg",
            "home": "Man Utd",
            "away": "Chelsea",
            "league_name": "Premier League",
            "date": "2026-03-01T16:30:00Z",
            "url": "/football/man-utd-chelsea",
        },
        {
            "id": "odd-ratings",
            "home": "Arsenal",
            "away": "Tottenham",
            "league_name": "Premier League",
            "date": "2026-03-01T18:00:00Z",
            "url": "/football/arsenal-tottenham",
        },
        {
            "id": "odd-lower",
            "home": "Everton",
            "away": "West Ham",
            "league_name": "Premier League",
            "date": "2026-03-01T20:00:00Z",
            "url": "/football/everton-west-ham",
        },
        {
            "id": "odd-unmatched",
            "home": "Unknown FC",
            "away": "Nobody United",
            "league_name": "Unknown League",
            "date": "2026-03-01T21:00:00Z",
            "url": "/football/unknown-nobody",
        },
    ]


def test_priority_artifact_contains_all_links_and_selects_inclusive_tiers(resolver, source_links):
    client = _FakeClient(
        [
            (
                101,
                date(2026, 3, 1),
                datetime(2026, 3, 1, 16, 31),
                "Manchester United",
                "Chelsea FC",
                "xG",
                "Premier League",
            ),
            (
                102,
                date(2026, 3, 1),
                datetime(2026, 3, 1, 18),
                "Arsenal",
                "Tottenham",
                "ratings",
                "Premier League",
            ),
            (
                103,
                date(2026, 3, 1),
                datetime(2026, 3, 1, 20),
                "Everton",
                "West Ham",
                "lower",
                "Premier League",
            ),
        ]
    )

    artifact = LinkPriorityService(client, resolver).prioritize("20260301", source_links)

    assert artifact.payload["prioritized_date"] == "20260301"
    assert artifact.payload["reference_window"]["dates"] == [
        "20260228",
        "20260301",
        "20260302",
    ]
    assert len(artifact.links) == 4
    assert [record["resolution"]["priority"] for record in artifact.links] == [
        "xG",
        "ratings",
        "lower",
        "unmatched",
    ]
    assert artifact.links[-1]["resolution"]["coverage_category"] == "not_covered"
    record = artifact.links[0]
    assert record["oddspedia_id"] == "odd-xg"
    providers = record["providers"]
    assert list(providers["oddspedia"]) == list(providers["fotmob"])
    assert providers == {
        "oddspedia": {
            "id": "odd-xg",
            "home_team": "Man Utd",
            "away_team": "Chelsea",
            "scheduled_at_utc": "2026-03-01T16:30:00Z",
            "competition": "Premier League",
            "coverage_level": None,
            "url": "/football/man-utd-chelsea",
        },
        "fotmob": {
            "id": "101",
            "home_team": "Manchester United",
            "away_team": "Chelsea FC",
            "scheduled_at_utc": "2026-03-01T16:31:00",
            "competition": "Premier League",
            "coverage_level": "xG",
            "url": None,
        },
    }
    assert record["resolution"] == {
        "status": "matched",
        "coverage_category": "xG",
        "priority": "xG",
        "confidence": "alias",
        "score": 100.0,
        "margin": 100.0,
        "rules": {"home": "alias", "away": "exact"},
    }
    assert [link["id"] for link in select_links_for_priority(artifact, "xG", source_links)] == [
        "odd-xg"
    ]
    assert [
        link["id"] for link in select_links_for_priority(artifact, "ratings", source_links)
    ] == [
        "odd-xg",
        "odd-ratings",
    ]
    assert [link["id"] for link in select_links_for_priority(artifact, "lower", source_links)] == [
        "odd-xg",
        "odd-ratings",
        "odd-lower",
    ]
    assert [
        link["id"] for link in select_links_for_priority(artifact, "unmatched", source_links)
    ] == [
        "odd-xg",
        "odd-ratings",
        "odd-lower",
        "odd-unmatched",
    ]
    assert client.queries[-1][1] == {"start_date": "2026-02-28", "end_date": "2026-03-02"}


def test_priority_rejects_an_operator_assertion_when_silver_is_not_reconciled(
    resolver, source_links
):
    class IncompleteReferenceClient:
        def execute(self, query, parameters):
            if "FROM bronze.match_reference" in query:
                return _QueryResult(
                    [
                        (1, date(2026, 2, 28)),
                        (2, date(2026, 3, 1)),
                        (3, date(2026, 3, 2)),
                    ]
                )
            if "oddspedia_reference_window:silver" in query:
                return _QueryResult(
                    [(1, date(2026, 2, 28)), (2, date(2026, 3, 1))]
                )
            raise AssertionError("candidate rows must not load before readiness succeeds")

    with pytest.raises(ReferenceWindowNotReadyError, match="2026-03-02"):
        LinkPriorityService(IncompleteReferenceClient(), resolver).prioritize(
            "20260301", source_links
        )


def test_priority_artifact_round_trip_detects_stale_source_inventory(
    monkeypatch, tmp_path, resolver, source_links
):
    artifact_path = tmp_path / "prioritized_match_links.json"
    monkeypatch.setattr(
        link_prioritization,
        "get_prioritized_match_links_file",
        lambda date_str, sport="football": str(artifact_path),
    )
    artifact = LinkPriorityService(_FakeClient([]), resolver).prioritize("20260301", source_links)

    save_priority_artifact(artifact, "20260301")
    loaded = load_priority_artifact("20260301")

    assert loaded is not None
    assert priority_artifact_is_current(loaded, "20260301", source_links)
    changed_links = [dict(link) for link in source_links]
    changed_links[0]["home"] = "Manchester United"
    assert not priority_artifact_is_current(loaded, "20260301", changed_links)
    assert not priority_artifact_is_current(
        loaded, "20260301", source_links, matcher_rule_version="different-rule-version"
    )
    loaded.payload["schema_version"] = "older-schema"
    assert not priority_artifact_is_current(loaded, "20260301", source_links)


def test_priority_does_not_use_oddspedia_kickoff_as_matching_evidence(resolver):
    artifact = LinkPriorityService(
        _FakeClient(
            [
                (
                    104,
                    date(2026, 3, 1),
                    datetime(2026, 3, 1, 16, 30),
                    "Elche",
                    "Espanyol",
                    "xG",
                    "LaLiga",
                )
            ]
        ),
        resolver,
    ).prioritize(
        "20260301",
        [
            {
                "id": "odd-elche",
                "home": "Elche",
                "away": "Espanyol",
                "league_name": "La Liga",
                "date": "2026-03-01 16:30:00+00",
            }
        ],
    )

    resolution = artifact.links[0]["resolution"]
    assert resolution["status"] == "matched"
    assert resolution["score"] == 100.0
