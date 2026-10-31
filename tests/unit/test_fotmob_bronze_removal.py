import pytest
from fotmob_bronze_support import DATE, FakeClickHouse, load_payload, second_match, write_archive

from scripts.bronze import remove_fotmob_bronze
from src.fotmob.bronze.admission import load_bronze_table_specs
from src.fotmob.bronze.loader import BronzeService
from src.fotmob.bronze.removal import BronzeRemovalService, stale_scope_commands
from src.fotmob.bronze.source import source_date_match_ids
from src.fotmob.bronze.write_lock import fotmob_bronze_write_lock


@pytest.fixture(scope="module")
def specs():
    return load_bronze_table_specs()


@pytest.fixture
def warehouse(tmp_path, specs):
    """Two loaded Source Dates: 20251207 holds match 4800002, 20251208 holds 4800001."""
    write_archive(tmp_path, [second_match(load_payload())], date_str="20251207")
    write_archive(tmp_path, [load_payload()], date_str=DATE)
    client = FakeClickHouse(specs)
    loaded = BronzeService(
        client=client, historical_root=tmp_path, specs=specs, lock_path=tmp_path / "lock"
    ).run(dates=["20251207", DATE])
    assert loaded.exit_code == 0
    return client


def _removal(tmp_path, client, specs):
    return BronzeRemovalService(client, tmp_path, specs=specs, lock_path=tmp_path / "lock")


def test_source_date_matches_come_from_the_stored_payloads(tmp_path):
    write_archive(tmp_path, [load_payload(), second_match(load_payload())])

    assert source_date_match_ids(tmp_path, DATE) == (4800001, 4800002)


def test_removing_a_date_deletes_only_its_matches_from_every_table(tmp_path, specs, warehouse):
    result = _removal(tmp_path, warehouse, specs).run(dates=[DATE])

    assert result.exit_code == 0
    assert result.dates_removed == [DATE]
    assert result.removed_rows["general"] == 1 and result.removed_rows["cards"] == 2
    for table in specs:
        assert warehouse.match_rows(table, 4800001) == [], table
    assert len(warehouse.match_rows("general", 4800002)) == 1
    assert result.stale_match_dates == ["2025-12-08"]
    assert result.follow_up_commands == [
        "depthmark load-fotmob-silver --date 20251208",
        "depthmark load-fotmob-gold --date 20251208",
    ]


def test_dry_run_counts_without_deleting_or_locking(tmp_path, specs, warehouse):
    with fotmob_bronze_write_lock("load-fotmob-bronze", tmp_path / "lock"):
        result = _removal(tmp_path, warehouse, specs).run(dates=[DATE], dry_run=True)

    assert result.exit_code == 0
    assert result.removed_rows["general"] == 1
    assert len(warehouse.match_rows("general", 4800001)) == 1
    assert not any(statement.startswith("ALTER TABLE") for statement in warehouse.statements)


def test_date_without_stored_source_fails_and_the_rest_are_removed(tmp_path, specs, warehouse):
    result = _removal(tmp_path, warehouse, specs).run(dates=["20251206", DATE])

    assert result.exit_code == 1
    assert "cannot be identified" in result.failed_dates["20251206"]
    assert result.dates_removed == [DATE]
    assert warehouse.match_rows("general", 4800001) == []


def test_full_history_removal_truncates_every_table(tmp_path, specs, warehouse):
    result = _removal(tmp_path, warehouse, specs).run(full_history=True)

    assert result.exit_code == 0
    assert set(warehouse.truncated) == set(specs)
    assert result.removed_rows["general"] == 2
    assert result.follow_up_commands == [
        "depthmark load-fotmob-silver --full-history",
        "depthmark load-fotmob-gold --full-history",
    ]


def test_held_write_lock_stops_removal(tmp_path, specs, warehouse):
    with fotmob_bronze_write_lock("load-fotmob-bronze", tmp_path / "lock"):
        result = _removal(tmp_path, warehouse, specs).run(dates=[DATE])

    assert result.exit_code == 1
    assert "BronzeWriteLockedError" in result.run_error
    assert len(warehouse.match_rows("general", 4800001)) == 1


def test_stale_scopes_rerun_single_dates_or_whole_months():
    commands = stale_scope_commands(["2025-12-08", "2026-01-30", "2026-01-31", "2026-01-30"])

    assert commands == [
        "depthmark load-fotmob-silver --date 20251208",
        "depthmark load-fotmob-silver --month 202601",
        "depthmark load-fotmob-gold --date 20251208",
        "depthmark load-fotmob-gold --month 202601",
    ]


@pytest.mark.parametrize(
    "argv, message",
    [
        ([], "one of the arguments"),
        (["--date", "2025-12-08"], "expected YYYYMMDD"),
        (["--start-date", "20251208"], "--end-date is required"),
        (["--start-date", "20251208", "--end-date", "20251201"], "cannot be before"),
        (["--date", "20251208", "--month", "202512"], "not allowed with"),
    ],
)
def test_removal_cli_rejects_invalid_scopes(argv, message, capsys):
    with pytest.raises(SystemExit) as exit_info:
        remove_fotmob_bronze.main(argv)

    assert exit_info.value.code == 2
    assert message in capsys.readouterr().err
