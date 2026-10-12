import copy
import gzip
import json

import pytest
from fotmob_bronze_support import DATE, FakeClickHouse, load_payload, second_match, write_archive

from src.fotmob.bronze import loader
from src.fotmob.bronze.admission import admit_rows, load_bronze_table_specs
from src.fotmob.bronze.dead_letter import DeadLetterQueue
from src.fotmob.bronze.match_processor import (
    BRONZE_TABLES,
    BronzeProcessingError,
    FotMobBronzeMatchProcessor,
)
from src.fotmob.bronze.write_lock import fotmob_bronze_write_lock


@pytest.fixture(scope="module")
def specs():
    return load_bronze_table_specs()


@pytest.fixture
def payload():
    return load_payload()


@pytest.fixture
def dlq_dir(tmp_path, monkeypatch):
    path = tmp_path / "dlq"
    monkeypatch.setattr(loader, "DeadLetterQueue", lambda: DeadLetterQueue(str(path)))
    return path


def _service(root, client, specs):
    return loader.BronzeService(
        client=client, historical_root=root, specs=specs, lock_path=root / "bronze.lock"
    )


def test_processor_emits_only_bronze_tables_with_ddl_columns(payload, specs):
    processed = FotMobBronzeMatchProcessor().process_match(payload["data"])

    assert set(processed.rows) == set(BRONZE_TABLES) == set(loader.FOTMOB_TABLES)
    assert processed.rejected_rows == []
    for table, rows in processed.rows.items():
        assert rows, f"fixture should exercise {table}"
        admitted = admit_rows(specs[table], rows)
        assert len(admitted.frame) == len(rows)
    card = processed.rows["cards"][0]
    assert {"event_time", "score_at_event"} <= set(card) and "time" not in card
    assert {"shot_id", "minute", "minute_added"} <= set(processed.rows["shotmap"][0])
    assert "coach_id" in processed.rows["coaches"][0]


def test_payload_without_match_id_is_a_processing_error(payload):
    del payload["data"]["general"]["matchId"]

    with pytest.raises(BronzeProcessingError, match="general.matchId"):
        FotMobBronzeMatchProcessor().process_match(payload["data"])


def test_section_error_names_match_and_section(payload):
    payload["data"]["content"]["matchFacts"]["momentum"]["main"]["data"][0]["value"] = "high"

    with pytest.raises(BronzeProcessingError, match="FotMob match 4800001: momentum section"):
        FotMobBronzeMatchProcessor().process_match(payload["data"])


def _match_events(payload):
    return payload["data"]["content"]["matchFacts"]["events"]["events"]


def _cards(processed):
    return processed.rows["cards"]


def test_rows_rejected_by_source_models_are_returned(payload):
    _match_events(payload)[1]["time"] = None

    processed = FotMobBronzeMatchProcessor().process_match(payload["data"])

    assert len(_cards(processed)) == 1
    (rejection,) = processed.rejected_rows
    assert rejection.table == "cards" and "event_time" in rejection.reason


@pytest.mark.parametrize(
    "source, stored",
    [([66.7, 33.3], (67, 33)), ([50.5, 49.5], (50, 50)), ([55, 45], (55, 45))],
)
def test_fractional_possession_is_rounded_half_to_even(payload, source, stored):
    stats = payload["data"]["content"]["stats"]["Periods"]["All"]["stats"][0]["stats"]
    stats[0]["stats"] = source

    (period,) = FotMobBronzeMatchProcessor().process_match(payload["data"]).rows["period"]

    assert (period["ball_possession_home"], period["ball_possession_away"]) == stored


def test_different_events_sharing_a_source_id_get_distinct_ids(payload):
    goals = payload["data"]["header"]["events"]["homeTeamGoals"]["Test Striker"]
    goals[1]["eventId"] = goals[0]["eventId"]

    rows = FotMobBronzeMatchProcessor().process_match(payload["data"]).rows["goal"]
    repeated = [row for row in rows if row["player_id"] == 50001]

    assert repeated[0]["event_id"] == 70001
    assert repeated[1]["event_id"] not in (70001, 70003)
    rerun = FotMobBronzeMatchProcessor().process_match(payload["data"]).rows["goal"]
    assert [row["event_id"] for row in rerun] == [row["event_id"] for row in rows]


def test_repeat_of_a_reassigned_event_collapses_onto_it(payload, specs):
    goals = payload["data"]["header"]["events"]["homeTeamGoals"]["Test Striker"]
    goals[1]["eventId"] = goals[0]["eventId"]
    goals.append(copy.deepcopy(goals[1]))

    rows = FotMobBronzeMatchProcessor().process_match(payload["data"]).rows["goal"]
    striker = [row["event_id"] for row in rows if row["player_id"] == 50001]

    assert len(striker) == 3 and striker[1] == striker[2] != striker[0]
    assert admit_rows(specs["goal"], rows).collapsed_duplicates == 1


def test_cards_without_ids_in_the_same_minute_stay_distinct(payload, specs):
    events = _match_events(payload)
    for name in ("Player One", "Player Two"):
        events.append(
            {
                "type": "Card",
                "eventId": None,
                "time": 90,
                "card": "Yellow",
                "isHome": False,
                "homeScore": 2,
                "awayScore": 1,
                "player": {"id": 0, "name": name},
            }
        )

    cards = _cards(FotMobBronzeMatchProcessor().process_match(payload["data"]))

    late = [card for card in cards if card["player_name"] in ("Player One", "Player Two")]
    assert len({card["event_id"] for card in late}) == 2
    assert len(admit_rows(specs["cards"], cards).frame) == len(cards)


def test_exactly_repeated_event_keeps_its_id_and_collapses(payload, specs):
    events = _match_events(payload)
    events.append(copy.deepcopy(events[1]))

    cards = _cards(FotMobBronzeMatchProcessor().process_match(payload["data"]))

    assert [card["event_id"] for card in cards].count(70020) == 2
    assert admit_rows(specs["cards"], cards).collapsed_duplicates == 1


def test_repeated_lineup_player_keeps_the_first_entry(payload):
    starters = payload["data"]["content"]["lineup"]["awayTeam"]["starters"]
    starters.append({**starters[0], "positionId": 86})
    payload["data"]["content"]["lineup"]["homeTeam"]["subs"].append(
        {"id": 50010, "name": "Test Substitute", "shirtNumber": "99"}
    )

    rows = FotMobBronzeMatchProcessor().process_match(payload["data"]).rows

    away = [row for row in rows["starters"] if row["player_id"] == 60001]
    assert len(away) == 1 and away[0]["position_id"] is None
    subs = [row for row in rows["substitutes"] if row["player_id"] == 50010]
    assert len(subs) == 1 and subs[0]["shirt_number"] == "18"


def test_match_without_date_is_rejected_instead_of_epoch(payload, specs):
    payload["data"]["general"]["matchTimeUTCDate"] = None
    payload["data"]["general"]["matchTimeUTC"] = None

    processed = FotMobBronzeMatchProcessor().process_match(payload["data"])

    with pytest.raises(loader.BronzeAdmissionError, match="match_date null_in_non_nullable"):
        admit_rows(specs["match_reference"], processed.rows["match_reference"])


def test_date_loads_every_table_then_reports_counts(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload, second_match(payload)])
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 0
    assert set(client.inserted) == set(loader.FOTMOB_TABLES)
    assert result.row_counts["general"] == 2
    assert result.total_rows == sum(len(f) for frames in client.inserted.values() for f in frames)
    for table, (frame,) in client.inserted.items():
        assert "inserted_at" not in frame.columns
        assert set(frame.columns) <= set(specs[table].column_names)
    assert not dlq_dir.exists()


def test_any_inadmissible_value_inserts_nothing_for_the_date(tmp_path, payload, specs, dlq_dir):
    bad = second_match(payload)
    bad["data"]["content"]["matchFacts"]["infoBox"]["Attendance"] = 3_000_000_000
    write_archive(tmp_path, [payload, bad])
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert (
        "venue.attendance" in result.failed_dates[DATE] and "4800002" in result.failed_dates[DATE]
    )
    assert result.run_error is None
    assert client.inserted == {}


def test_rejected_source_rows_fail_the_date(tmp_path, payload, specs, dlq_dir):
    _match_events(payload)[1]["time"] = None
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert "cards match_id=4800001" in result.failed_dates[DATE]
    assert client.inserted == {}


def test_insert_failure_goes_to_dlq_and_fails_the_run(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs, fail_insert="period")

    write_archive(tmp_path, [second_match(payload)], date_str="20251209")

    result = _service(tmp_path, client, specs).run(dates=[DATE, "20251209"])

    assert result.exit_code == 1
    assert result.failed_dates == {}
    assert "bronze.period" in result.run_error and "Type mismatch" in result.run_error
    assert "period" not in client.inserted
    assert len(client.inserted["general"]) == 1, "the run stops; 20251209 is never loaded"
    (dlq_file,) = dlq_dir.glob("period_*.jsonl")
    assert json.loads(dlq_file.read_text().splitlines()[0])["row_count"] == 1


def test_failed_insert_of_a_table_with_dates_still_reaches_the_dlq(
    tmp_path, payload, specs, dlq_dir
):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs, fail_insert="match_reference")

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert "BronzeInsertError" in result.run_error and "Type mismatch" in result.run_error
    (dlq_file,) = dlq_dir.glob("match_reference_*.jsonl")
    record = json.loads(dlq_file.read_text().splitlines()[0])
    assert record["data"][0]["match_date"] == "2025-12-08"


def test_unreadable_payload_fails_the_date(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload, second_match(payload)], corrupt_member=True)
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert "Cannot read FotMob payload" in result.failed_dates[DATE]
    assert "match_1.json.gz" in result.failed_dates[DATE]
    assert client.inserted == {}


def test_processing_error_names_the_source_artifact(tmp_path, payload, specs, dlq_dir):
    payload["data"]["content"]["matchFacts"]["momentum"]["main"]["data"][0]["value"] = "high"
    write_archive(tmp_path, [payload])

    result = _service(tmp_path, FakeClickHouse(specs), specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert "momentum section" in result.failed_dates[DATE]
    assert "_matches.tar:match_0.json.gz" in result.failed_dates[DATE]


def test_missing_live_table_fails_before_reading_any_date(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs, missing=("cards",))

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert result.failed_dates == {}
    assert "bronze.cards" in result.run_error
    assert client.inserted == {}


def test_date_level_failure_fails_its_date_and_the_run_continues(tmp_path, payload, specs, dlq_dir):
    bad = copy.deepcopy(payload)
    bad["data"]["content"]["matchFacts"]["infoBox"]["Attendance"] = 3_000_000_000
    write_archive(tmp_path, [bad], date_str="20251207")
    write_archive(tmp_path, [payload], date_str=DATE)
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=["20251207", DATE])

    assert result.exit_code == 1
    assert list(result.failed_dates) == ["20251207"]
    assert result.run_error is None
    assert result.dates_processed == 1
    assert result.row_counts["general"] == 1
    assert len(client.inserted["general"]) == 1


def test_held_write_lock_stops_the_run_and_names_the_holder(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs)
    service = _service(tmp_path, client, specs)

    with fotmob_bronze_write_lock("remove-fotmob-bronze", service.lock_path):
        result = service.run(dates=[DATE])

    assert result.exit_code == 1
    assert "BronzeWriteLockedError" in result.run_error
    assert "remove-fotmob-bronze" in result.run_error and '"pid"' in result.run_error
    assert client.inserted == {}
    assert service.run(dates=[DATE]).exit_code == 0, "the lock is released when its holder ends"


def test_replace_removes_the_dates_matches_then_reloads_them(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload, second_match(payload)])
    client = FakeClickHouse(specs)
    service = _service(tmp_path, client, specs)
    assert service.run(dates=[DATE]).exit_code == 0
    stale_copy = dict(client.match_rows("general", 4800001)[0], league_name="Old Name")
    client.rows["general"].append(stale_copy)

    result = service.run(dates=[DATE], mode="replace")

    assert result.exit_code == 0
    assert result.removed_rows["general"] == 3
    assert result.row_counts["general"] == 2
    (general,) = client.match_rows("general", 4800001)
    assert general["league_name"] == "Test League"
    assert result.stale_match_dates == ["2025-12-08"]


def test_replace_keeps_existing_rows_when_the_date_fails_admission(
    tmp_path, payload, specs, dlq_dir
):
    archive = write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs)
    service = _service(tmp_path, client, specs)
    assert service.run(dates=[DATE]).exit_code == 0
    archive.unlink()
    bad = copy.deepcopy(payload)
    bad["data"]["content"]["matchFacts"]["infoBox"]["Attendance"] = 3_000_000_000
    archive.parent.rmdir()
    write_archive(tmp_path, [bad])

    result = service.run(dates=[DATE], mode="replace")

    assert result.exit_code == 1 and DATE in result.failed_dates
    assert not any(statement.startswith("ALTER TABLE") for statement in client.statements)
    assert len(client.match_rows("general", 4800001)) == 1


def test_replace_fails_a_date_with_no_stored_source_and_continues(
    tmp_path, payload, specs, dlq_dir
):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=["20251207", DATE], mode="replace")

    assert result.exit_code == 1
    assert "cannot be replaced" in result.failed_dates["20251207"]
    assert result.row_counts["general"] == 1


def test_dates_without_stored_source_are_reported_not_failed(tmp_path, payload, specs, dlq_dir):
    write_archive(tmp_path, [payload])
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE, "20251209"])

    assert result.exit_code == 0
    assert result.dates_processed == 2
    assert result.dates_without_source == ["20251209"]


def test_loose_json_files_are_read_when_no_archive_exists(tmp_path, payload, specs, dlq_dir):
    matches_dir = loader.get_matches_dir(tmp_path, DATE)
    matches_dir.mkdir(parents=True)
    with gzip.open(matches_dir / "match_4800001.json.gz", "wt", encoding="utf-8") as handle:
        json.dump(payload, handle)
    client = FakeClickHouse(specs)

    result = _service(tmp_path, client, specs).run(dates=[DATE])

    assert result.exit_code == 0
    assert result.row_counts["general"] == 1


def test_process_all_keeps_returning_frames_for_scrape_quality_checks(payload):
    frames, summary = FotMobBronzeMatchProcessor().process_all(payload["data"])

    assert set(frames) == set(BRONZE_TABLES)
    assert summary is not None
