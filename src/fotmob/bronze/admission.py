"""Fail-closed admission of FotMob Bronze rows into their ClickHouse tables.

The setup DDL under ``clickhouse/bronze`` is the only definition of a Bronze
table's columns, types, nullability, and defaults. Admission turns the rows the
processor emits into a frame that matches that DDL exactly, or raises
:class:`BronzeAdmissionError` naming every value it could not admit. It never
clips, rounds, truncates, or substitutes a value, and it never drops a column.

The rules, applied per column from its declared type:

- A column no row carries is omitted when the DDL gives it a default, sent as
  ``NULL`` when it is ``Nullable``, sent as ``[]`` when it is an ``Array``, and
  is an error otherwise.
- ``NULL`` is allowed only in ``Nullable`` columns. ``Array`` columns read
  ``NULL`` as ``[]`` because ClickHouse arrays cannot be ``NULL``.
- Integers must be whole numbers inside the type's range. Booleans become 0/1,
  and integral floats or digit strings become integers.
- Floats accept numbers and numeric strings; ``NaN`` is ``NULL``.
- Strings accept text. Temporal values are written as ISO-8601 and integers as
  digits; floats, booleans, and containers are an error in a ``String`` column
  because their text form is ambiguous.
- ``Date`` and ``DateTime`` accept Python temporal values or ISO-8601 text.
- A row key the DDL does not declare is an error.
- Row identity columns (``BRONZE_REQUIRED_KEYS``) must be present, non-null,
  positive where numeric, and unique within the batch.
"""

from __future__ import annotations

import math
import re
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Any

import pandas as pd

from src.warehouse.contracts import BRONZE_REQUIRED_KEYS, NUMERIC_KEY_COLUMNS
from src.warehouse.schema_drift import (
    ExpectedTable,
    compare_table_schema,
    parse_expected_tables,
    read_live_schemas,
)

BRONZE_DATABASE = "bronze"
BRONZE_DDL_DIR = Path(__file__).resolve().parents[3] / "clickhouse" / "bronze"
MAX_EXAMPLES_PER_VIOLATION = 3

_INTEGER_TYPE_PATTERN = re.compile(r"^(U?)Int(8|16|32|64)$")
_FLOAT_TYPE_PATTERN = re.compile(r"^Float(32|64)$")
_DATETIME_TYPE_PATTERN = re.compile(r"^DateTime(64)?(\(.*\))?$")
_INTEGER_STRING_PATTERN = re.compile(r"^[+-]?\d+$")
_ISO_DATE_PATTERN = re.compile(r"^\s*(\d{4}-\d{2}-\d{2})")
_COMPUTED_DEFAULT_KINDS = frozenset({"MATERIALIZED", "ALIAS"})


class BronzeAdmissionError(RuntimeError):
    """Raised when Bronze rows cannot be admitted into their table exactly as declared."""

    def __init__(
        self,
        message: str,
        *,
        table: str | None = None,
        violations: Sequence[AdmissionViolation] = (),
    ) -> None:
        details = "".join(f"\n  - {violation.describe()}" for violation in violations)
        super().__init__(f"{message}{details}")
        self.table = table
        self.violations = tuple(violations)


class BronzeSchemaError(BronzeAdmissionError):
    """Raised when the Bronze DDL or the live warehouse tables cannot accept admission."""


@dataclass(frozen=True)
class AdmissionViolation:
    """Every value of one column that broke one admission rule."""

    table: str
    column: str
    rule: str
    count: int
    examples: tuple[str, ...]

    def describe(self) -> str:
        examples = "; ".join(self.examples)
        return f"{self.table}.{self.column} {self.rule}: {self.count} value(s), e.g. {examples}"


@dataclass(frozen=True)
class BronzeColumnSpec:
    """One column as declared by Bronze setup DDL."""

    name: str
    clickhouse_type: str
    default_kind: str | None = None

    @property
    def nullable(self) -> bool:
        return self.clickhouse_type.startswith("Nullable(")

    @property
    def base_type(self) -> str:
        column_type = self.clickhouse_type
        if column_type.startswith("Nullable("):
            column_type = column_type[len("Nullable(") : -1]
        if column_type.startswith("LowCardinality("):
            column_type = column_type[len("LowCardinality(") : -1]
        if column_type.startswith("Nullable("):
            column_type = column_type[len("Nullable(") : -1]
        return column_type

    @property
    def is_array(self) -> bool:
        return self.base_type.startswith("Array(")

    @property
    def is_computed(self) -> bool:
        """MATERIALIZED and ALIAS columns are computed by ClickHouse and cannot be inserted."""
        return self.default_kind in _COMPUTED_DEFAULT_KINDS

    @property
    def has_insert_default(self) -> bool:
        return self.default_kind == "DEFAULT"


@dataclass(frozen=True)
class BronzeTableSpec:
    """One Bronze table: its DDL columns and its declared row identity."""

    table: str
    columns: tuple[BronzeColumnSpec, ...]
    row_identity: tuple[str, ...]
    source_file: Path
    expected: ExpectedTable = field(repr=False, compare=False)

    @property
    def qualified_name(self) -> str:
        return f"{BRONZE_DATABASE}.{self.table}"

    @property
    def column_names(self) -> tuple[str, ...]:
        return tuple(column.name for column in self.columns)

    def column(self, name: str) -> BronzeColumnSpec:
        for column in self.columns:
            if column.name == name:
                return column
        raise KeyError(f"{self.qualified_name} has no column {name}")


def load_bronze_table_specs(ddl_dir: Path = BRONZE_DDL_DIR) -> dict[str, BronzeTableSpec]:
    """Parse Bronze setup DDL into table specs and check each declared row identity.

    Raises :class:`BronzeSchemaError` when a table in ``BRONZE_REQUIRED_KEYS`` has no
    DDL, or when an identity column is missing from its DDL or declared ``Nullable``.
    """
    expected_tables = {
        table.table: table
        for table in parse_expected_tables(sorted(ddl_dir.glob("*.sql")))
        if table.database == BRONZE_DATABASE
    }
    specs: dict[str, BronzeTableSpec] = {}
    problems: list[str] = []
    for table_name, row_identity in BRONZE_REQUIRED_KEYS.items():
        expected = expected_tables.get(table_name)
        if expected is None:
            problems.append(f"{BRONZE_DATABASE}.{table_name} has no setup DDL in {ddl_dir}")
            continue
        defaults = dict(expected.column_defaults)
        columns = tuple(
            BronzeColumnSpec(
                name=name, clickhouse_type=column_type, default_kind=defaults.get(name)
            )
            for name, column_type in expected.columns
        )
        declared = {column.name: column for column in columns}
        for key in row_identity:
            if key not in declared:
                problems.append(
                    f"{expected.qualified_name} identity column {key} is not in its DDL"
                )
            elif declared[key].nullable:
                problems.append(f"{expected.qualified_name} identity column {key} is Nullable")
        specs[table_name] = BronzeTableSpec(
            table=table_name,
            columns=columns,
            row_identity=tuple(row_identity),
            source_file=expected.source_file,
            expected=expected,
        )
    if problems:
        raise BronzeSchemaError("Bronze DDL does not support admission: " + "; ".join(problems))
    return specs


def assert_live_bronze_tables_match(
    client: Any, specs: Mapping[str, BronzeTableSpec], tables: Iterable[str] | None = None
) -> None:
    """Fail closed unless every selected Bronze table exists and matches its setup DDL.

    Admission coerces values to DDL types, so a live table that drifted from its DDL
    would receive values shaped for a different schema.
    """
    selected = [specs[name] for name in (tables if tables is not None else specs)]
    live_schemas = read_live_schemas(client, [spec.expected for spec in selected])
    missing = [spec.qualified_name for spec in selected if spec.qualified_name not in live_schemas]
    if missing:
        raise BronzeSchemaError(
            f"Bronze tables do not exist: {', '.join(missing)}. "
            "Run scripts/orchestration/setup_fotmob_warehouse.py to create them."
        )
    drifted = []
    for spec in selected:
        differences = compare_table_schema(spec.expected, *live_schemas[spec.qualified_name])
        if differences:
            drifted.append(f"{spec.qualified_name}: {'; '.join(differences)}")
    if drifted:
        raise BronzeSchemaError(
            "Bronze tables differ from their setup DDL; apply the change with "
            "scripts/maintenance/recreate_clickhouse_tables.py and reload: " + " | ".join(drifted)
        )


class _ViolationCollector:
    """Group rule breaks by column and rule, keeping a few traceable examples."""

    def __init__(self, table: str) -> None:
        self.table = table
        self._counts: dict[tuple[str, str], int] = {}
        self._examples: dict[tuple[str, str], list[str]] = {}

    def add(self, column: str, rule: str, row: Mapping[str, Any], value: Any) -> None:
        key = (column, rule)
        self._counts[key] = self._counts.get(key, 0) + 1
        examples = self._examples.setdefault(key, [])
        if len(examples) < MAX_EXAMPLES_PER_VIOLATION:
            examples.append(f"match_id={row.get('match_id')!r} value={_short_repr(value)}")

    def add_count(self, column: str, rule: str, count: int, examples: Sequence[str]) -> None:
        key = (column, rule)
        self._counts[key] = self._counts.get(key, 0) + count
        self._examples.setdefault(key, []).extend(examples[:MAX_EXAMPLES_PER_VIOLATION])

    @property
    def violations(self) -> list[AdmissionViolation]:
        return [
            AdmissionViolation(
                table=self.table,
                column=column,
                rule=rule,
                count=count,
                examples=tuple(self._examples[(column, rule)]),
            )
            for (column, rule), count in self._counts.items()
        ]


class _Reject(Exception):
    """Internal signal that one value breaks one rule."""

    def __init__(self, rule: str) -> None:
        super().__init__(rule)
        self.rule = rule


def _short_repr(value: Any, limit: int = 80) -> str:
    text = repr(value)
    return text if len(text) <= limit else text[: limit - 3] + "..."


def _is_null(value: Any) -> bool:
    if value is None or value is pd.NA or value is pd.NaT:
        return True
    return isinstance(value, float) and math.isnan(value)


def _integer_converter(base_type: str) -> Callable[[Any], int]:
    match = _INTEGER_TYPE_PATTERN.match(base_type)
    assert match is not None
    bits = int(match.group(2))
    if match.group(1) == "U":
        lower, upper = 0, (1 << bits) - 1
    else:
        lower, upper = -(1 << (bits - 1)), (1 << (bits - 1)) - 1

    def convert(value: Any) -> int:
        if isinstance(value, bool):
            number = int(value)
        elif isinstance(value, int):
            number = value
        elif isinstance(value, float):
            if not value.is_integer():
                raise _Reject("not_a_whole_number")
            number = int(value)
        elif isinstance(value, str) and _INTEGER_STRING_PATTERN.match(value.strip()):
            number = int(value.strip())
        else:
            raise _Reject("not_an_integer")
        if not lower <= number <= upper:
            raise _Reject(f"outside_{base_type}_range")
        return number

    return convert


def _float_converter(value: Any) -> float:
    if isinstance(value, bool):
        raise _Reject("not_a_number")
    if isinstance(value, (int, float)):
        number = float(value)
    elif isinstance(value, str):
        try:
            number = float(value.strip())
        except ValueError as error:
            raise _Reject("not_a_number") from error
    else:
        raise _Reject("not_a_number")
    if math.isinf(number):
        raise _Reject("infinite_number")
    return number


def _string_converter(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    raise _Reject("not_text")


def _string_array_converter(value: Any) -> list[str]:
    if not isinstance(value, (list, tuple)):
        raise _Reject("not_a_list")
    items = []
    for item in value:
        if _is_null(item):
            raise _Reject("null_array_item")
        items.append(_string_converter(item))
    return items


def _date_converter(value: Any) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        match = _ISO_DATE_PATTERN.match(value)
        if match:
            try:
                return date.fromisoformat(match.group(1))
            except ValueError as error:
                raise _Reject("not_a_date") from error
    raise _Reject("not_a_date")


def _datetime_converter(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day)
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
        except ValueError as error:
            raise _Reject("not_a_datetime") from error
    raise _Reject("not_a_datetime")


def _converter_for(column: BronzeColumnSpec) -> Callable[[Any], Any]:
    base_type = column.base_type
    if _INTEGER_TYPE_PATTERN.match(base_type):
        return _integer_converter(base_type)
    if _FLOAT_TYPE_PATTERN.match(base_type):
        return _float_converter
    if base_type == "String":
        return _string_converter
    if base_type == "Array(String)":
        return _string_array_converter
    if base_type == "Date":
        return _date_converter
    if _DATETIME_TYPE_PATTERN.match(base_type):
        return _datetime_converter
    raise BronzeSchemaError(
        f"Bronze admission has no rule for column type {column.clickhouse_type} "
        f"({column.name}); add one to src/fotmob/bronze/admission.py"
    )


def _pandas_dtype(column: BronzeColumnSpec) -> str:
    """Return the frame dtype clickhouse-connect writes correctly for this column."""
    if _INTEGER_TYPE_PATTERN.match(column.base_type) and column.base_type != "UInt64":
        return "Int64" if column.nullable else "int64"
    if _FLOAT_TYPE_PATTERN.match(column.base_type) and not column.nullable:
        return "float64"
    return "object"


@dataclass(frozen=True)
class AdmittedTable:
    """A table's rows as they will be inserted, and how many exact duplicates collapsed."""

    table: str
    frame: pd.DataFrame
    source_rows: int
    collapsed_duplicates: int = 0


def admit_rows(spec: BronzeTableSpec, rows: Sequence[Mapping[str, Any]]) -> AdmittedTable:
    """Return the rows as a frame of exactly the table's insertable DDL columns.

    Rows that repeat another row's identity with identical values collapse into one,
    as ``ReplacingMergeTree`` would; rows that share an identity but differ are an
    error, because ClickHouse would silently keep only one of them.

    Raises :class:`BronzeAdmissionError` listing every column, rule, count, and a few
    ``match_id`` examples when any value cannot be admitted unchanged.
    """
    if not rows:
        return AdmittedTable(table=spec.table, frame=pd.DataFrame(), source_rows=0)
    collector = _ViolationCollector(spec.table)
    declared = set(spec.column_names)
    unknown: dict[str, int] = {}
    unknown_examples: dict[str, list[str]] = {}
    for row in rows:
        for key in row:
            if key not in declared:
                unknown[key] = unknown.get(key, 0) + 1
                examples = unknown_examples.setdefault(key, [])
                if len(examples) < MAX_EXAMPLES_PER_VIOLATION:
                    examples.append(f"match_id={row.get('match_id')!r}")
    for key, count in unknown.items():
        collector.add_count(key, "not_declared_in_ddl", count, unknown_examples[key])

    present = {key for row in rows for key in row}
    data: dict[str, pd.Series] = {}
    for column in spec.columns:
        if column.is_computed:
            if column.name in present:
                collector.add_count(column.name, "computed_column_supplied", len(rows), [])
            continue
        if column.name not in present and column.has_insert_default:
            continue
        if column.name not in present and not (column.nullable or column.is_array):
            collector.add_count(column.name, "required_column_absent", len(rows), [])
            continue
        convert = _converter_for(column)
        values: list[Any] = []
        for row in rows:
            value = row.get(column.name)
            if _is_null(value):
                if column.is_array:
                    values.append([])
                elif column.nullable:
                    values.append(None)
                else:
                    collector.add(column.name, "null_in_non_nullable_column", row, value)
                    values.append(None)
                continue
            try:
                values.append(convert(value))
            except _Reject as rejection:
                collector.add(column.name, rejection.rule, row, value)
                values.append(None)
        data[column.name] = pd.Series(values, dtype="object")

    keep = _check_row_identity(spec, rows, data, collector)
    violations = collector.violations
    if violations:
        raise BronzeAdmissionError(
            f"{len(rows)} row(s) for {spec.qualified_name} cannot be admitted",
            table=spec.table,
            violations=violations,
        )
    frame = pd.DataFrame(data, index=pd.RangeIndex(len(rows)))
    if len(keep) != len(rows):
        frame = frame.iloc[keep].reset_index(drop=True)
    for name in frame.columns:
        dtype = _pandas_dtype(spec.column(name))
        if dtype != "object":
            frame[name] = frame[name].astype(dtype)
    return AdmittedTable(
        table=spec.table,
        frame=frame,
        source_rows=len(rows),
        collapsed_duplicates=len(rows) - len(keep),
    )


def _check_row_identity(
    spec: BronzeTableSpec,
    rows: Sequence[Mapping[str, Any]],
    data: Mapping[str, pd.Series],
    collector: _ViolationCollector,
) -> list[int]:
    """Check identity values and return the row positions to keep.

    Identity columns must be positive where numeric. A row repeating an earlier
    row's identity is dropped when every admitted value matches, and is a
    ``conflicting_row_identity`` violation otherwise.
    """
    if any(key not in data for key in spec.row_identity):
        return list(range(len(rows)))
    for key in spec.row_identity:
        if key not in NUMERIC_KEY_COLUMNS:
            continue
        for row, value in zip(rows, data[key]):
            if value is not None and value <= 0:
                collector.add(key, "non_positive_identity", row, value)

    columns = list(data.values())
    first_index: dict[tuple[Any, ...], int] = {}
    keep: list[int] = []
    conflicts: list[str] = []
    conflict_count = 0
    for index, identity in enumerate(zip(*(data[key] for key in spec.row_identity))):
        earlier = first_index.get(identity)
        if earlier is None:
            first_index[identity] = index
            keep.append(index)
            continue
        if all(_same_value(column.iloc[earlier], column.iloc[index]) for column in columns):
            continue
        conflict_count += 1
        if len(conflicts) < MAX_EXAMPLES_PER_VIOLATION:
            differing = [
                name
                for name, column in data.items()
                if not _same_value(column.iloc[earlier], column.iloc[index])
            ]
            conflicts.append(f"identity={identity!r} differs in {', '.join(differing)}")
    if conflict_count:
        collector.add_count(
            ",".join(spec.row_identity), "conflicting_row_identity", conflict_count, conflicts
        )
    return keep


def _same_value(left: Any, right: Any) -> bool:
    if left is None or right is None:
        return left is right
    return bool(left == right)
