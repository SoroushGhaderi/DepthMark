"""Non-destructive setup checks: allowed setup statements and schema drift detection.

Normal warehouse setup may only create missing databases and tables. When an
existing table no longer matches its setup DDL (column names, column types, or
``ORDER BY`` sorting key), setup fails closed instead of changing the table;
applying that change is an explicit Table Recreation (see ADR 0026).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Optional, Sequence

from src.integrations.clickhouse.sql import split_sql_statements

ALLOWED_SETUP_STATEMENT_PATTERN = re.compile(
    r"^CREATE\s+(?:DATABASE|TABLE)\s+IF\s+NOT\s+EXISTS\s",
    re.IGNORECASE,
)
CREATE_TABLE_HEADER_PATTERN = re.compile(
    r"^CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+"
    r"[`\"]?(?P<database>\w+)[`\"]?\.[`\"]?(?P<table>\w+)[`\"]?\s*\(",
    re.IGNORECASE,
)
ORDER_BY_PATTERN = re.compile(r"\bORDER\s+BY\b", re.IGNORECASE)
CLAUSE_AFTER_ORDER_BY_PATTERN = re.compile(
    r"\b(?:PARTITION\s+BY|PRIMARY\s+KEY|SAMPLE\s+BY|TTL|SETTINGS|COMMENT)\b",
    re.IGNORECASE,
)
NON_COLUMN_ELEMENT_KEYWORDS = ("INDEX", "PROJECTION", "CONSTRAINT", "PRIMARY")
COLUMN_DEFAULT_KINDS = ("DEFAULT", "MATERIALIZED", "ALIAS", "EPHEMERAL")
SAFE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclass(frozen=True)
class ExpectedTable:
    """One table as declared by setup DDL.

    ``column_defaults`` maps each column that declares a default expression to its
    kind (``DEFAULT``, ``MATERIALIZED``, ``ALIAS``, or ``EPHEMERAL``).
    """

    database: str
    table: str
    columns: tuple[tuple[str, str], ...]
    sorting_key: tuple[str, ...]
    create_statement: str
    source_file: Path
    column_defaults: tuple[tuple[str, str], ...] = ()

    @property
    def qualified_name(self) -> str:
        return f"{self.database}.{self.table}"


@dataclass(frozen=True)
class TableDrift:
    """Schema drift between an existing table and its setup DDL."""

    expected: ExpectedTable
    differences: tuple[str, ...]


def _split_top_level(text: str, separator: str = ",") -> list[str]:
    """Split text on a separator that is outside parentheses and quotes."""
    parts: list[str] = []
    depth = 0
    quote: Optional[str] = None
    current: list[str] = []
    for char in text:
        if quote:
            current.append(char)
            if char == quote:
                quote = None
            continue
        if char in ("'", '"', "`"):
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == separator and depth == 0:
            parts.append("".join(current).strip())
            current = []
            continue
        current.append(char)
    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def _matching_paren_index(text: str, open_index: int) -> int:
    """Return the index of the parenthesis closing the one at ``open_index``."""
    depth = 0
    quote: Optional[str] = None
    for index in range(open_index, len(text)):
        char = text[index]
        if quote:
            if char == quote:
                quote = None
            continue
        if char in ("'", '"', "`"):
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("Unbalanced parentheses in CREATE TABLE statement")


def normalize_sql_fragment(fragment: str) -> str:
    """Normalize a type or expression for comparison: drop whitespace outside quotes."""
    normalized: list[str] = []
    quote: Optional[str] = None
    for char in fragment.strip():
        if quote:
            normalized.append(char)
            if char == quote:
                quote = None
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "`" or char.isspace():
            continue
        normalized.append(char)
    return "".join(normalized)


def _first_top_level_token(text: str) -> str:
    """Return text up to the first whitespace outside parentheses and quotes."""
    depth = 0
    quote: Optional[str] = None
    for index, char in enumerate(text):
        if quote:
            if char == quote:
                quote = None
        elif char in ("'", '"', "`"):
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char.isspace() and depth == 0:
            return text[:index]
    return text


def _parse_column(element: str) -> Optional[tuple[str, str]]:
    """Parse ``name Type [modifiers]`` into a normalized (name, type) pair."""
    name_and_rest = element.split(None, 1)
    if name_and_rest[0].upper() in NON_COLUMN_ELEMENT_KEYWORDS:
        return None
    if len(name_and_rest) != 2:
        raise ValueError(f"Column definition has no type: {element}")
    name = name_and_rest[0].strip('`"')
    return name, normalize_sql_fragment(_first_top_level_token(name_and_rest[1]))


def _column_default_kind(element: str) -> Optional[str]:
    """Return the default kind a column definition declares after its type, if any."""
    name_and_rest = element.split(None, 1)
    if len(name_and_rest) != 2:
        return None
    column_type = _first_top_level_token(name_and_rest[1])
    modifiers = name_and_rest[1][len(column_type) :].split()
    if modifiers and modifiers[0].upper() in COLUMN_DEFAULT_KINDS:
        return modifiers[0].upper()
    return None


def parse_sorting_key(text: str) -> tuple[str, ...]:
    """Parse the ``ORDER BY`` expression list that follows a column definition."""
    match = ORDER_BY_PATTERN.search(text)
    if match is None:
        return ()
    remainder = text[match.end() :].lstrip()
    if remainder.startswith("("):
        expression = remainder[1 : _matching_paren_index(remainder, 0)]
    else:
        clause = CLAUSE_AFTER_ORDER_BY_PATTERN.search(remainder)
        expression = remainder[: clause.start()] if clause else remainder
    if normalize_sql_fragment(expression).lower() in ("", "tuple()"):
        return ()
    return tuple(normalize_sql_fragment(part) for part in _split_top_level(expression))


def parse_create_table(statement: str, source_file: Path) -> Optional[ExpectedTable]:
    """Parse a schema-qualified ``CREATE TABLE IF NOT EXISTS`` statement."""
    header = CREATE_TABLE_HEADER_PATTERN.match(statement)
    if header is None:
        return None
    open_index = header.end() - 1
    close_index = _matching_paren_index(statement, open_index)
    columns: list[tuple[str, str]] = []
    column_defaults: list[tuple[str, str]] = []
    for element in _split_top_level(statement[open_index + 1 : close_index]):
        column = _parse_column(element)
        if column is None:
            continue
        columns.append(column)
        default_kind = _column_default_kind(element)
        if default_kind is not None:
            column_defaults.append((column[0], default_kind))
    return ExpectedTable(
        database=header.group("database"),
        table=header.group("table"),
        columns=tuple(columns),
        sorting_key=parse_sorting_key(statement[close_index + 1 :]),
        create_statement=statement,
        source_file=source_file,
        column_defaults=tuple(column_defaults),
    )


def setup_statements(sql_file: Path) -> list[str]:
    """Return the executable statements in one setup SQL file."""
    return split_sql_statements(sql_file.read_text(encoding="utf-8"))


def find_disallowed_setup_statements(sql_files: Iterable[Path]) -> list[tuple[Path, str]]:
    """Return setup statements that are not create-if-missing operations."""
    disallowed: list[tuple[Path, str]] = []
    for sql_file in sql_files:
        for statement in setup_statements(sql_file):
            if not ALLOWED_SETUP_STATEMENT_PATTERN.match(statement):
                disallowed.append((sql_file, statement))
    return disallowed


def assert_setup_sql_is_non_destructive(sql_files: Iterable[Path]) -> None:
    """Raise when setup SQL contains anything other than create-if-missing statements."""
    disallowed = find_disallowed_setup_statements(sql_files)
    if disallowed:
        details = "; ".join(f"{path.name}: {statement[:80]}" for path, statement in disallowed)
        raise ValueError(
            "Setup SQL may only contain CREATE DATABASE/TABLE IF NOT EXISTS statements. "
            f"Disallowed statements: {details}"
        )


def parse_expected_tables(sql_files: Iterable[Path]) -> list[ExpectedTable]:
    """Parse every table declared by the given setup SQL files.

    A table declared in more than one file keeps its first declaration, matching
    setup where later ``CREATE TABLE IF NOT EXISTS`` statements are no-ops.
    """
    expected: dict[str, ExpectedTable] = {}
    for sql_file in sql_files:
        for statement in setup_statements(sql_file):
            table = parse_create_table(statement, sql_file)
            if table is not None and table.qualified_name not in expected:
                expected[table.qualified_name] = table
    return list(expected.values())


def _result_rows(result: Any) -> list[Sequence[Any]]:
    return list(getattr(result, "result_rows", None) or [])


def _database_list(expected_tables: Sequence[ExpectedTable]) -> str:
    databases = sorted({table.database for table in expected_tables})
    for database in databases:
        if not SAFE_IDENTIFIER_PATTERN.fullmatch(database):
            raise ValueError(f"Unsafe database name in setup DDL: {database}")
    return ", ".join(f"'{database}'" for database in databases)


def read_live_schemas(
    client: Any, expected_tables: Sequence[ExpectedTable]
) -> dict[str, tuple[dict[str, str], tuple[str, ...]]]:
    """Read live columns and sorting keys for existing tables in the setup databases."""
    if not expected_tables:
        return {}
    database_list = _database_list(expected_tables)
    sorting_keys: dict[str, tuple[str, ...]] = {}
    for database, table, sorting_key in _result_rows(
        client.execute(
            "SELECT database, name, sorting_key FROM system.tables "
            f"WHERE database IN ({database_list})",
            log_query=False,
        )
    ):
        expression = str(sorting_key or "")
        sorting_keys[f"{database}.{table}"] = tuple(
            normalize_sql_fragment(part) for part in _split_top_level(expression)
        )
    columns: dict[str, dict[str, str]] = {name: {} for name in sorting_keys}
    for database, table, name, column_type in _result_rows(
        client.execute(
            "SELECT database, table, name, type FROM system.columns "
            f"WHERE database IN ({database_list}) ORDER BY database, table, position",
            log_query=False,
        )
    ):
        qualified_name = f"{database}.{table}"
        if qualified_name in columns:
            columns[qualified_name][str(name)] = normalize_sql_fragment(str(column_type))
    return {name: (columns[name], sorting_keys[name]) for name in sorting_keys}


def compare_table_schema(
    expected: ExpectedTable, live_columns: dict[str, str], live_sorting_key: tuple[str, ...]
) -> tuple[str, ...]:
    """Return human-readable differences between a live table and its setup DDL."""
    differences: list[str] = []
    expected_columns = dict(expected.columns)
    for name, expected_type in expected.columns:
        live_type = live_columns.get(name)
        if live_type is None:
            differences.append(f"missing column {name} {expected_type}")
        elif live_type != expected_type:
            differences.append(f"column {name} is {live_type}, DDL declares {expected_type}")
    for name, live_type in live_columns.items():
        if name not in expected_columns:
            differences.append(f"column {name} {live_type} is not in the DDL")
    if live_sorting_key != expected.sorting_key:
        differences.append(
            f"ORDER BY is ({', '.join(live_sorting_key)}), "
            f"DDL declares ({', '.join(expected.sorting_key)})"
        )
    return tuple(differences)


def find_schema_drift(client: Any, expected_tables: Sequence[ExpectedTable]) -> list[TableDrift]:
    """Return drift for existing tables; tables that do not exist yet are not drift."""
    live_schemas = read_live_schemas(client, expected_tables)
    drifts: list[TableDrift] = []
    for expected in expected_tables:
        live = live_schemas.get(expected.qualified_name)
        if live is None:
            continue
        differences = compare_table_schema(expected, *live)
        if differences:
            drifts.append(TableDrift(expected=expected, differences=differences))
    return drifts


def format_drift_report(drifts: Sequence[TableDrift]) -> str:
    """Format drift for operator logs, one table per block."""
    lines: list[str] = []
    for drift in drifts:
        lines.append(f"{drift.expected.qualified_name} ({drift.expected.source_file.name}):")
        lines.extend(f"  - {difference}" for difference in drift.differences)
    return "\n".join(lines)
