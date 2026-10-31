from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from src.fotmob.bronze.admission import (
    BronzeAdmissionError,
    BronzeColumnSpec,
    BronzeSchemaError,
    BronzeTableSpec,
    admit_rows,
    assert_live_bronze_tables_match,
    load_bronze_table_specs,
)
from src.warehouse.contracts import BRONZE_REQUIRED_KEYS
from src.warehouse.schema_drift import ExpectedTable


@pytest.fixture(scope="module")
def specs():
    return load_bronze_table_specs()


def _spec(*columns, identity=("match_id",)):
    column_specs = tuple(BronzeColumnSpec(*column) for column in columns)
    expected = ExpectedTable(
        database="bronze",
        table="example",
        columns=tuple((column.name, column.clickhouse_type) for column in column_specs),
        sorting_key=identity,
        create_statement="",
        source_file=Path("example.sql"),
    )
    return BronzeTableSpec(
        table="example",
        columns=column_specs,
        row_identity=identity,
        source_file=Path("example.sql"),
        expected=expected,
    )


def _violations(error):
    return {(violation.column, violation.rule): violation for violation in error.violations}


def test_every_bronze_table_has_ddl_with_non_nullable_identity(specs):
    assert set(specs) == set(BRONZE_REQUIRED_KEYS)
    for table, spec in specs.items():
        assert spec.row_identity == tuple(BRONZE_REQUIRED_KEYS[table])
        for key in spec.row_identity:
            assert not spec.column(key).nullable, f"{table}.{key}"
        assert spec.column("inserted_at").has_insert_default


def test_admitted_frame_has_exactly_the_insertable_ddl_columns(specs):
    rows = [
        {
            "match_id": 1,
            "event_id": 10,
            "event_time": 30,
            "team": "Home",
            "card_type": "Yellow",
            "score_at_event": "1-0",
        }
    ]

    admitted = admit_rows(specs["cards"], rows)

    expected = [name for name in specs["cards"].column_names if name != "inserted_at"]
    assert list(admitted.frame.columns) == expected
    assert admitted.frame.loc[0, "player_name"] is None
    assert admitted.frame["event_id"].dtype == "int64"
    assert admitted.frame["player_id"].dtype == "Int64"


def test_null_in_required_column_is_rejected_with_match_examples(specs):
    rows = [
        {
            "match_id": 7,
            "event_id": 10,
            "event_time": None,
            "team": "Home",
            "card_type": "Yellow",
            "score_at_event": "1-0",
        }
    ]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(specs["cards"], rows)

    violation = _violations(error.value)[("event_time", "null_in_non_nullable_column")]
    assert violation.count == 1
    assert "match_id=7" in violation.examples[0]
    assert "cards.event_time null_in_non_nullable_column" in str(error.value)


def test_required_column_absent_from_every_row_is_rejected(specs):
    rows = [{"match_id": 1, "event_id": 10, "event_time": 30, "team": "Home", "card_type": "Y"}]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(specs["cards"], rows)

    assert ("score_at_event", "required_column_absent") in _violations(error.value)


def test_integers_are_never_clipped_or_rounded():
    spec = _spec(("match_id", "Int32"), ("value", "Nullable(Int32)"))
    rows = [
        {"match_id": 1, "value": 2**31},
        {"match_id": 2, "value": 4.5},
        {"match_id": 3, "value": "12a"},
    ]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, rows)

    violations = _violations(error.value)
    assert violations[("value", "outside_Int32_range")].count == 1
    assert violations[("value", "not_a_whole_number")].count == 1
    assert violations[("value", "not_an_integer")].count == 1


def test_lossless_integer_inputs_are_converted():
    spec = _spec(("match_id", "Int32"), ("flag", "UInt8"), ("count", "Nullable(Int32)"))
    rows = [
        {"match_id": 1, "flag": True, "count": 3.0},
        {"match_id": 2, "flag": False, "count": "17"},
        {"match_id": 3, "flag": 1, "count": float("nan")},
    ]

    frame = admit_rows(spec, rows).frame

    assert frame["flag"].tolist() == [1, 0, 1]
    assert frame["count"].tolist()[:2] == [3, 17]
    assert frame["count"].isna().tolist() == [False, False, True]


def test_floats_accept_numeric_text_and_treat_nan_as_null():
    spec = _spec(("match_id", "Int32"), ("xg", "Nullable(Float32)"), ("x", "Float64"))
    rows = [
        {"match_id": 1, "xg": "0.42", "x": 3},
        {"match_id": 2, "xg": float("nan"), "x": 1.5},
    ]

    frame = admit_rows(spec, rows).frame

    assert frame["xg"].tolist() == [0.42, None]
    assert frame["x"].tolist() == [3.0, 1.5]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [{"match_id": 3, "xg": "high", "x": 1.0}])
    assert ("xg", "not_a_number") in _violations(error.value)


def test_strings_accept_text_temporal_values_and_integers_only():
    spec = _spec(("match_id", "Int32"), ("label", "Nullable(String)"))
    kicked_off = datetime(2021, 1, 10, 15, tzinfo=UTC)

    frame = admit_rows(
        spec,
        [
            {"match_id": 1, "label": "text"},
            {"match_id": 2, "label": kicked_off},
            {"match_id": 3, "label": 42},
        ],
    ).frame

    assert frame["label"].tolist() == ["text", "2021-01-10T15:00:00+00:00", "42"]
    for value in (1.5, True, {"a": 1}, ["a"]):
        with pytest.raises(BronzeAdmissionError) as error:
            admit_rows(spec, [{"match_id": 9, "label": value}])
        assert ("label", "not_text") in _violations(error.value)


def test_arrays_read_null_as_empty_and_absent_as_empty(specs):
    spec = _spec(("match_id", "Int32"), ("facts", "Array(String)"))

    frame = admit_rows(
        spec, [{"match_id": 1, "facts": None}, {"match_id": 2, "facts": ["a"]}]
    ).frame
    absent = admit_rows(spec, [{"match_id": 3}]).frame

    assert frame["facts"].tolist() == [[], ["a"]]
    assert absent["facts"].tolist() == [[]]


def test_dates_accept_iso_text_and_reject_anything_else():
    spec = _spec(("match_id", "Int32"), ("match_date", "Date"))

    frame = admit_rows(spec, [{"match_id": 1, "match_date": "2025-12-08T15:00:00Z"}]).frame
    assert frame["match_date"].tolist() == [date(2025, 12, 8)]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [{"match_id": 2, "match_date": "08/12/2025"}])
    assert ("match_date", "not_a_date") in _violations(error.value)


def test_columns_not_declared_in_ddl_are_rejected():
    spec = _spec(("match_id", "Int32"))

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [{"match_id": 1, "id": 5}, {"match_id": 2, "id": 6}])

    violation = _violations(error.value)[("id", "not_declared_in_ddl")]
    assert violation.count == 2


def test_computed_columns_must_not_be_supplied():
    spec = _spec(("match_id", "Int32"), ("month", "UInt32", "MATERIALIZED"))

    assert list(admit_rows(spec, [{"match_id": 1}]).frame.columns) == ["match_id"]
    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [{"match_id": 1, "month": 202512}])
    assert ("month", "computed_column_supplied") in _violations(error.value)


def test_identity_must_be_positive():
    spec = _spec(("match_id", "Int32"))

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [{"match_id": 0}])

    assert ("match_id", "non_positive_identity") in _violations(error.value)


def test_identical_duplicate_identities_collapse_and_conflicts_fail():
    spec = _spec(
        ("match_id", "Int32"),
        ("event_id", "Int64"),
        ("player_name", "Nullable(String)"),
        identity=("match_id", "event_id"),
    )
    same = {"match_id": 1, "event_id": 5, "player_name": "A"}

    admitted = admit_rows(spec, [same, dict(same), {"match_id": 1, "event_id": 6}])
    assert admitted.collapsed_duplicates == 1
    assert admitted.frame["event_id"].tolist() == [5, 6]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, [same, {**same, "player_name": "B"}])
    violation = _violations(error.value)[("match_id,event_id", "conflicting_row_identity")]
    assert "differs in player_name" in violation.examples[0]


def test_violations_from_many_rows_report_one_line_per_column_and_rule():
    spec = _spec(("match_id", "Int32"), ("value", "Int32"))
    rows = [{"match_id": index, "value": None} for index in range(1, 101)]

    with pytest.raises(BronzeAdmissionError) as error:
        admit_rows(spec, rows)

    (violation,) = error.value.violations
    assert violation.count == 100
    assert len(violation.examples) == 3


class FakeSystemTablesClient:
    def __init__(self, tables):
        self.tables = tables

    def execute(self, query, *args, **kwargs):
        if "FROM system.columns" in query:
            rows = [
                ("bronze", table, name, column_type)
                for table, (columns, _) in self.tables.items()
                for name, column_type in columns
            ]
        else:
            rows = [("bronze", table, key) for table, (_, key) in self.tables.items()]
        return type("Result", (), {"result_rows": rows})()


def _live_tables(specs, *, drop=(), retype=None):
    tables = {}
    for name, spec in specs.items():
        if name in drop:
            continue
        columns = list(spec.expected.columns)
        if retype and retype[0] == name:
            columns = [
                (column, retype[2] if column == retype[1] else kind) for column, kind in columns
            ]
        tables[name] = (columns, ", ".join(spec.expected.sorting_key))
    return tables


def test_live_tables_matching_ddl_pass(specs):
    assert_live_bronze_tables_match(FakeSystemTablesClient(_live_tables(specs)), specs) is None


def test_missing_live_table_fails_with_setup_remediation(specs):
    client = FakeSystemTablesClient(_live_tables(specs, drop=("cards",)))

    with pytest.raises(BronzeSchemaError, match="bronze.cards.*setup_fotmob_warehouse"):
        assert_live_bronze_tables_match(client, specs)


def test_drifted_live_table_fails_with_recreation_remediation(specs):
    client = FakeSystemTablesClient(
        _live_tables(specs, retype=("period", "ball_possession_home", "Nullable(Float32)"))
    )

    with pytest.raises(BronzeSchemaError, match="recreate_clickhouse_tables.*ball_possession_home"):
        assert_live_bronze_tables_match(client, specs)
