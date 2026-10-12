import copy

import pytest
from fotmob_bronze_support import DATE, FakeClickHouse, load_payload, second_match, write_archive

from src.fotmob.bronze import loader
from src.fotmob.bronze.admission import load_bronze_table_specs
from src.fotmob.bronze.dead_letter import DeadLetterQueue
from src.fotmob.bronze.loader import BronzeService
from src.fotmob.bronze.write_lock import fotmob_bronze_write_lock

OLD_ONLY_MATCH = 4799999


@pytest.fixture(scope="module")
def specs():
    return load_bronze_table_specs()


@pytest.fixture(autouse=True)
def dlq_dir(tmp_path, monkeypatch):
    path = tmp_path / "dlq"
    monkeypatch.setattr(loader, "DeadLetterQueue", lambda: DeadLetterQueue(str(path)))
    return path


@pytest.fixture
def warehouse(specs):
    """Bronze already holding an old row that the current source no longer produces."""
    client = FakeClickHouse(specs)
    client.rows["general"].append({"match_id": OLD_ONLY_MATCH, "league_name": "Old"})
    return client


def _service(tmp_path, client, specs):
    return BronzeService(
        client=client, historical_root=tmp_path, specs=specs, lock_path=tmp_path / "lock"
    )


def _general_ids(client):
    return sorted(row["match_id"] for row in client.rows["general"])


def test_rebuild_swaps_in_exactly_the_reloaded_history(tmp_path, specs, warehouse):
    write_archive(tmp_path, [second_match(load_payload())], date_str="20251207")
    write_archive(tmp_path, [load_payload()], date_str=DATE)

    result = _service(tmp_path, warehouse, specs).run(
        dates=["20251207", DATE, "20251209"], mode="rebuild"
    )

    assert result.exit_code == 0 and result.swapped is True
    assert _general_ids(warehouse) == [4800001, 4800002]
    assert len(warehouse.rows["cards"]) == 4
    assert result.dates_without_source == ["20251209"]
    assert warehouse.stage == {}, "staging clones are dropped after the swap"
    assert all(
        statement.startswith("CREATE TABLE warehouse_stage.") and " AS bronze." in statement
        for statement in warehouse.statements
        if statement.startswith("CREATE TABLE")
    )


def test_a_failed_date_prevents_the_swap_but_every_date_is_still_checked(
    tmp_path, specs, warehouse
):
    bad = copy.deepcopy(load_payload())
    bad["data"]["content"]["matchFacts"]["infoBox"]["Attendance"] = 3_000_000_000
    write_archive(tmp_path, [bad], date_str="20251207")
    write_archive(tmp_path, [load_payload()], date_str=DATE)

    result = _service(tmp_path, warehouse, specs).run(dates=["20251207", DATE], mode="rebuild")

    assert result.exit_code == 1 and result.swapped is False
    assert list(result.failed_dates) == ["20251207"]
    assert result.row_counts["general"] == 1, "the later date was still staged and checked"
    assert _general_ids(warehouse) == [OLD_ONLY_MATCH]
    assert warehouse.stage == {}
    assert not any(statement.startswith("EXCHANGE") for statement in warehouse.statements)


def test_insert_failure_stops_the_rebuild_and_leaves_bronze_unchanged(tmp_path, specs, warehouse):
    write_archive(tmp_path, [load_payload()], date_str=DATE)
    warehouse.fail_insert = "period"

    result = _service(tmp_path, warehouse, specs).run(dates=[DATE], mode="rebuild")

    assert result.exit_code == 1 and result.swapped is False
    assert "BronzeInsertError" in result.run_error
    assert _general_ids(warehouse) == [OLD_ONLY_MATCH]
    assert warehouse.stage == {}


def test_rebuild_with_nothing_staged_refuses_to_swap(tmp_path, specs, warehouse):
    result = _service(tmp_path, warehouse, specs).run(dates=[DATE], mode="rebuild")

    assert result.exit_code == 1
    assert "staged no rows" in result.run_error
    assert _general_ids(warehouse) == [OLD_ONLY_MATCH]


def test_missing_staging_database_stops_the_rebuild_before_loading(tmp_path, specs, warehouse):
    write_archive(tmp_path, [load_payload()], date_str=DATE)
    warehouse.has_staging_database = False

    result = _service(tmp_path, warehouse, specs).run(dates=[DATE], mode="rebuild")

    assert result.exit_code == 1
    assert "warehouse_stage does not exist" in result.run_error
    assert result.row_counts == {} and warehouse.stage == {}
    assert _general_ids(warehouse) == [OLD_ONLY_MATCH]


def test_held_write_lock_stops_the_rebuild(tmp_path, specs, warehouse):
    write_archive(tmp_path, [load_payload()], date_str=DATE)

    with fotmob_bronze_write_lock("load-fotmob-bronze --append", tmp_path / "lock"):
        result = _service(tmp_path, warehouse, specs).run(dates=[DATE], mode="rebuild")

    assert result.exit_code == 1
    assert "BronzeWriteLockedError" in result.run_error
    assert _general_ids(warehouse) == [OLD_ONLY_MATCH]
