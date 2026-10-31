"""The only reader of FotMob Gold signal catalogs (ADR 0033).

Each signal is authored as one markdown file whose YAML frontmatter is the
source of truth for its metadata (ADR 0008). :func:`load_signal_catalog` reads
every catalog, checks it against the signal DML and DDL, and returns an
immutable :class:`SignalCatalog`, or raises :class:`SignalCatalogError` naming
every violation. One invalid catalog fails every consumer; a signal is never
dropped on its own.

The rules:

- Frontmatter holds exactly the keys in :data:`FRONTMATTER_KEYS`, and
  ``asset_paths`` holds exactly ``table`` and ``sql``.
- ``signal_id`` matches the file name and the grammar
  ``sig_<entity>_<family>_<subfamily>_<name>``; ``entity``, ``family``, and
  ``subfamily`` equal their id segments.
- ``status`` is ``active`` or ``deprecated``; ``grain`` is ``match_player`` for
  player signals and ``match_team`` otherwise.
- ``asset_paths.table`` is ``gold_signals.<signal_id>`` and
  ``asset_paths.sql`` is ``clickhouse/gold/dml/signals/<entity>/<signal_id>.sql``,
  which must exist and insert into ``asset_paths.table``. Every signal DML
  file and DDL table has a catalog.
- The identity chain holds: every ``row_identity`` column exists in the DDL
  table, the DDL ``signal_instance_id`` default equals
  :func:`signal_instance_id_expression`, and ``ORDER BY`` ends with
  ``signal_instance_id``.

The module performs no warehouse or MongoDB I/O.
"""

from __future__ import annotations

import copy
import re
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from types import MappingProxyType
from typing import Any

import yaml

from src.warehouse.schema_drift import (
    ExpectedTable,
    column_default_expression,
    normalize_sql_fragment,
    parse_expected_tables,
)

PROJECT_ROOT = Path(__file__).resolve().parents[3]
SIGNAL_CATALOG_RELATIVE_DIR = Path("catalogs") / "signals"
SIGNAL_CATALOG_DIR = PROJECT_ROOT / SIGNAL_CATALOG_RELATIVE_DIR
SIGNAL_DDL_RELATIVE_DIR = Path("clickhouse") / "gold" / "ddl" / "signals"
SIGNAL_DML_RELATIVE_DIR = Path("clickhouse") / "gold" / "dml" / "signals"
SIGNAL_TABLE_DATABASE = "gold_signals"
SIGNAL_IDENTITY_SCHEME_VERSION = "v1"
SIGNAL_INSTANCE_ID_COLUMN = "signal_instance_id"
INDEX_FILE_NAME = "README.md"
INSERT_TARGET_RE = re.compile(
    r"\bINSERT\s+INTO\s+`?([A-Za-z0-9_]+\.[A-Za-z0-9_]+)`?", re.IGNORECASE
)
INDEX_START_MARKER = "<!-- signal-index:start -->"
INDEX_END_MARKER = "<!-- signal-index:end -->"

SIGNAL_ENTITIES: tuple[str, ...] = ("match", "team", "player")
SIGNAL_STATUSES: tuple[str, ...] = ("active", "deprecated")
GRAIN_BY_ENTITY: Mapping[str, str] = MappingProxyType(
    {"match": "match_team", "team": "match_team", "player": "match_player"}
)
FRONTMATTER_KEYS: tuple[str, ...] = (
    "signal_id",
    "status",
    "entity",
    "family",
    "subfamily",
    "grain",
    "headline",
    "trigger",
    "row_identity",
    "asset_paths",
)
ASSET_PATH_KEYS: tuple[str, ...] = ("table", "sql")

_FRONTMATTER_START = "---\n"
_FRONTMATTER_END = "\n---\n"
_SIGNAL_ID_PATTERN = re.compile(
    r"^sig_(?P<entity>match|team|player)_(?P<family>[a-z0-9]+)_(?P<subfamily>[a-z0-9]+)"
    r"_(?P<name>[a-z0-9]+(?:_[a-z0-9]+)*)$"
)
_IDENTIFIER_PATTERN = re.compile(r"^[a-z_][a-z0-9_]*$")


@dataclass(frozen=True)
class CatalogViolation:
    """One catalog rule broken by one source file or asset."""

    source: str
    rule: str

    def describe(self) -> str:
        return f"{self.source}: {self.rule}"


class SignalCatalogError(RuntimeError):
    """Raised when the signal catalog breaks any rule; lists every violation."""

    def __init__(self, violations: Sequence[CatalogViolation]) -> None:
        self.violations = tuple(violations)
        details = "".join(f"\n  - {violation.describe()}" for violation in self.violations)
        super().__init__(
            f"Signal catalog is invalid ({len(self.violations)} violation(s)):{details}"
        )


@dataclass(frozen=True)
class SignalDefinition:
    """One validated signal catalog."""

    signal_id: str
    entity: str
    family: str
    subfamily: str
    name: str
    status: str
    grain: str
    headline: str
    trigger: str
    row_identity: tuple[str, ...]
    table: str
    sql_path: Path
    source_path: Path
    frontmatter: Mapping[str, Any] = field(compare=False, repr=False)
    body: str = field(compare=False, repr=False)

    @property
    def is_active(self) -> bool:
        return self.status == "active"

    @property
    def prefix(self) -> str:
        return "sig"

    @property
    def tags(self) -> tuple[str, str]:
        return (self.family, self.subfamily)

    @property
    def identity_fields(self) -> tuple[str, ...]:
        """Columns hashed into ``signal_instance_id``: ``row_identity`` led by ``match_id``."""
        if "match_id" in self.row_identity:
            return self.row_identity
        return ("match_id", *self.row_identity)

    def frontmatter_dict(self) -> dict[str, Any]:
        """Return a mutable deep copy of the authored frontmatter."""
        return copy.deepcopy(dict(self.frontmatter))

    def matches_family(self, family: str) -> bool:
        """Match ``family`` or ``family_subfamily`` selectors."""
        return family in (self.family, f"{self.family}_{self.subfamily}")


@dataclass(frozen=True)
class SignalCatalog:
    """Every validated signal definition, ordered by ``signal_id``."""

    definitions: tuple[SignalDefinition, ...]
    catalog_dir: Path

    def __iter__(self) -> Iterator[SignalDefinition]:
        return iter(self.definitions)

    def __len__(self) -> int:
        return len(self.definitions)

    def active(self) -> tuple[SignalDefinition, ...]:
        return tuple(definition for definition in self.definitions if definition.is_active)

    def get(self, signal_id: str) -> SignalDefinition:
        """Return one definition; raise ``KeyError`` naming an unknown signal."""
        for definition in self.definitions:
            if definition.signal_id == signal_id:
                return definition
        raise KeyError(f"No signal catalog for {signal_id}")

    def select(
        self,
        *,
        entity: str | None = None,
        family: str | None = None,
        include_deprecated: bool = False,
    ) -> tuple[SignalDefinition, ...]:
        """Return definitions matching the selectors; active only unless asked."""
        return tuple(
            definition
            for definition in self.definitions
            if (include_deprecated or definition.is_active)
            and (entity is None or definition.entity == entity)
            and (family is None or definition.matches_family(family))
        )


def signal_instance_id_expression(definition: SignalDefinition, table_alias: str = "") -> str:
    """Return the ClickHouse expression that hashes a signal row's identity.

    Signal DDL declares this as the ``signal_instance_id`` default, and the
    activation builder computes it for tables that predate the column.
    """
    prefix = f"{table_alias}." if table_alias else ""
    components = [
        f"'{SIGNAL_IDENTITY_SCHEME_VERSION}'",
        f"'{definition.signal_id}'",
        *[f"coalesce(toString({prefix}{column}), '')" for column in definition.identity_fields],
    ]
    hashed = ", '|', ".join(components)
    return f"lower(hex(SHA256(concat({hashed}))))"


def split_frontmatter(content: str) -> tuple[dict[str, Any], str]:
    """Split catalog markdown into its frontmatter mapping and body text."""
    if not content.startswith(_FRONTMATTER_START):
        raise ValueError("missing YAML frontmatter start '---'")
    head, separator, body = content.partition(_FRONTMATTER_END)
    if not separator:
        raise ValueError("missing YAML frontmatter end '---'")
    yaml_block = head[len(_FRONTMATTER_START) :]
    try:
        frontmatter = yaml.safe_load(yaml_block) or {}
    except yaml.YAMLError as error:
        raise ValueError(f"frontmatter is not valid YAML: {error}") from error
    if not isinstance(frontmatter, dict):
        raise ValueError("frontmatter is not a mapping")
    return frontmatter, body.strip()


def catalog_files(catalog_dir: Path) -> list[Path]:
    """Return the catalog markdown files in a directory, excluding its index."""
    return sorted(
        path for path in catalog_dir.glob("*.md") if path.name.lower() != INDEX_FILE_NAME.lower()
    )


def load_signal_catalog(
    catalog_dir: Path = SIGNAL_CATALOG_DIR,
    *,
    project_root: Path = PROJECT_ROOT,
) -> SignalCatalog:
    """Read and validate every signal catalog, or raise naming every violation."""
    violations: list[CatalogViolation] = []
    catalog_dir = catalog_dir.resolve()
    project_root = project_root.resolve()
    if not catalog_dir.is_dir():
        raise SignalCatalogError(
            [CatalogViolation(str(catalog_dir), "catalog directory does not exist")]
        )

    files = catalog_files(catalog_dir)
    if not files:
        violations.append(CatalogViolation(_display(catalog_dir, project_root), "no catalogs"))
    definitions: list[SignalDefinition] = []
    for path in files:
        definition = _read_definition(path, project_root, violations)
        if definition is not None:
            definitions.append(definition)

    catalogued_ids = {path.stem for path in files}
    _check_dml_coverage(catalogued_ids, project_root, violations)
    _check_ddl_identity(definitions, catalogued_ids, project_root, violations)

    if violations:
        raise SignalCatalogError(violations)
    return SignalCatalog(
        definitions=tuple(sorted(definitions, key=lambda definition: definition.signal_id)),
        catalog_dir=catalog_dir,
    )


def _display(path: Path, project_root: Path) -> str:
    try:
        return str(path.relative_to(project_root))
    except ValueError:
        return str(path)


def _read_definition(
    path: Path, project_root: Path, violations: list[CatalogViolation]
) -> SignalDefinition | None:
    source = _display(path, project_root)
    file_violations: list[CatalogViolation] = []

    def violate(rule: str) -> None:
        file_violations.append(CatalogViolation(source, rule))

    try:
        frontmatter, body = split_frontmatter(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as error:
        violations.append(CatalogViolation(source, str(error)))
        return None

    missing = [key for key in FRONTMATTER_KEYS if key not in frontmatter]
    unknown = sorted(str(key) for key in frontmatter if key not in FRONTMATTER_KEYS)
    if missing:
        violate(f"missing frontmatter keys {missing}")
    if unknown:
        violate(f"undeclared frontmatter keys {unknown}")

    text_values: dict[str, str] = {}
    for key in FRONTMATTER_KEYS:
        if key in ("row_identity", "asset_paths") or key not in frontmatter:
            continue
        value = frontmatter[key]
        if not isinstance(value, str) or not value.strip():
            violate(f"{key} must be a non-empty string")
        else:
            text_values[key] = value

    signal_id = text_values.get("signal_id", "")
    id_parts = _SIGNAL_ID_PATTERN.match(signal_id)
    if signal_id and signal_id != path.stem:
        violate(f"signal_id '{signal_id}' does not match the file name '{path.stem}'")
    if signal_id and id_parts is None:
        violate(f"signal_id '{signal_id}' must match sig_<entity>_<family>_<subfamily>_<name>")

    entity = id_parts.group("entity") if id_parts else ""
    if id_parts:
        for key in ("entity", "family", "subfamily"):
            if key in text_values and text_values[key] != id_parts.group(key):
                violate(
                    f"{key} '{text_values[key]}' must equal the signal_id segment "
                    f"'{id_parts.group(key)}'"
                )

    status = text_values.get("status")
    if status is not None and status not in SIGNAL_STATUSES:
        violate(f"status '{status}' must be one of {list(SIGNAL_STATUSES)}")

    grain = text_values.get("grain")
    if grain is not None and entity and grain != GRAIN_BY_ENTITY[entity]:
        violate(f"grain '{grain}' must be '{GRAIN_BY_ENTITY[entity]}' for {entity} signals")

    row_identity = frontmatter.get("row_identity")
    if "row_identity" in frontmatter and (
        not isinstance(row_identity, list)
        or not row_identity
        or not all(isinstance(column, str) for column in row_identity)
    ):
        violate("row_identity must be a non-empty list of column names")
        row_identity = None
    elif row_identity is not None:
        unsafe = [column for column in row_identity if not _IDENTIFIER_PATTERN.match(column)]
        duplicates = sorted({column for column in row_identity if row_identity.count(column) > 1})
        if unsafe:
            violate(f"row_identity has invalid column names {unsafe}")
        if duplicates:
            violate(f"row_identity repeats columns {duplicates}")

    asset_paths = frontmatter.get("asset_paths")
    sql_path: Path | None = None
    if "asset_paths" in frontmatter and not isinstance(asset_paths, dict):
        violate("asset_paths must be a mapping")
    elif isinstance(asset_paths, dict):
        missing_assets = [key for key in ASSET_PATH_KEYS if key not in asset_paths]
        unknown_assets = sorted(str(key) for key in asset_paths if key not in ASSET_PATH_KEYS)
        if missing_assets:
            violate(f"missing asset_paths keys {missing_assets}")
        if unknown_assets:
            violate(f"undeclared asset_paths keys {unknown_assets}")
        if signal_id and "table" in asset_paths:
            expected_table = f"{SIGNAL_TABLE_DATABASE}.{signal_id}"
            if asset_paths["table"] != expected_table:
                violate(f"asset_paths.table must be '{expected_table}'")
        if signal_id and entity and "sql" in asset_paths:
            expected_sql = (SIGNAL_DML_RELATIVE_DIR / entity / f"{signal_id}.sql").as_posix()
            if asset_paths["sql"] != expected_sql:
                violate(f"asset_paths.sql must be '{expected_sql}'")
            elif not (project_root / expected_sql).is_file():
                violate(f"asset_paths.sql '{expected_sql}' does not exist")
            else:
                sql_path = project_root / expected_sql
                insert_target = _insert_target(sql_path.read_text(encoding="utf-8"))
                expected_target = f"{SIGNAL_TABLE_DATABASE}.{signal_id}"
                if insert_target != expected_target:
                    violate(f"signal SQL must INSERT INTO {expected_target}, not {insert_target}")

    violations.extend(file_violations)
    if file_violations or sql_path is None or row_identity is None:
        return None
    return SignalDefinition(
        signal_id=signal_id,
        entity=entity,
        family=text_values["family"],
        subfamily=text_values["subfamily"],
        name=id_parts.group("name") if id_parts else "",
        status=text_values["status"],
        grain=text_values["grain"],
        headline=text_values["headline"],
        trigger=text_values["trigger"],
        row_identity=tuple(row_identity),
        table=f"{SIGNAL_TABLE_DATABASE}.{signal_id}",
        sql_path=sql_path,
        source_path=path,
        frontmatter=MappingProxyType(copy.deepcopy(frontmatter)),
        body=body,
    )


def _insert_target(sql: str) -> str | None:
    """Return the first ``INSERT INTO <database>.<table>`` target in ``sql``."""
    match = INSERT_TARGET_RE.search(sql)
    return match.group(1) if match else None


def _check_dml_coverage(
    catalogued_ids: set[str],
    project_root: Path,
    violations: list[CatalogViolation],
) -> None:
    for sql_file in sorted((project_root / SIGNAL_DML_RELATIVE_DIR).rglob("sig_*.sql")):
        if sql_file.stem not in catalogued_ids:
            violations.append(
                CatalogViolation(_display(sql_file, project_root), "signal SQL has no catalog")
            )


def _check_ddl_identity(
    definitions: Sequence[SignalDefinition],
    catalogued_ids: set[str],
    project_root: Path,
    violations: list[CatalogViolation],
) -> None:
    ddl_files = sorted((project_root / SIGNAL_DDL_RELATIVE_DIR).rglob("*.sql"))
    tables: dict[str, ExpectedTable] = {
        table.qualified_name: table
        for table in parse_expected_tables(ddl_files)
        if table.database == SIGNAL_TABLE_DATABASE
    }
    for name, table in sorted(tables.items()):
        if table.table not in catalogued_ids:
            violations.append(
                CatalogViolation(
                    _display(table.source_file, project_root), f"{name} has no catalog"
                )
            )

    for definition in definitions:
        source = _display(definition.source_path, project_root)
        table = tables.get(definition.table)
        if table is None:
            violations.append(CatalogViolation(source, f"{definition.table} has no DDL"))
            continue
        columns = {name for name, _ in table.columns}
        missing = [column for column in definition.identity_fields if column not in columns]
        if missing:
            violations.append(
                CatalogViolation(source, f"row_identity columns {missing} are not in the DDL")
            )
        expected = normalize_sql_fragment(signal_instance_id_expression(definition))
        if column_default_expression(table, SIGNAL_INSTANCE_ID_COLUMN) != expected:
            violations.append(
                CatalogViolation(
                    source,
                    f"DDL {SIGNAL_INSTANCE_ID_COLUMN} default must hash "
                    f"{SIGNAL_IDENTITY_SCHEME_VERSION}, the signal_id, and "
                    f"{list(definition.identity_fields)} in order",
                )
            )
        if not table.sorting_key or table.sorting_key[-1] != SIGNAL_INSTANCE_ID_COLUMN:
            violations.append(
                CatalogViolation(source, f"DDL ORDER BY must end with {SIGNAL_INSTANCE_ID_COLUMN}")
            )


def render_signal_index(catalog: SignalCatalog) -> str:
    """Render the catalog index table, deprecated signals included."""
    lines = [
        "| Signal ID | Entity | Family | Subfamily | Grain | Status | Catalog |",
        "|---|---|---|---|---|---|---|",
    ]
    for definition in catalog:
        file_name = definition.source_path.name
        lines.append(
            f"| `{definition.signal_id}` | {definition.entity} | {definition.family} | "
            f"{definition.subfamily} | `{definition.grain}` | {definition.status} | "
            f"[{file_name}]({file_name}) |"
        )
    return "\n".join(lines)


def replace_signal_index(index_text: str, catalog: SignalCatalog) -> str:
    """Return the index document with the generated table between its markers."""
    start = index_text.find(INDEX_START_MARKER)
    end = index_text.find(INDEX_END_MARKER)
    if start < 0 or end < start:
        raise ValueError(f"Index must contain {INDEX_START_MARKER} followed by {INDEX_END_MARKER}")
    return (
        index_text[: start + len(INDEX_START_MARKER)]
        + "\n"
        + render_signal_index(catalog)
        + "\n"
        + index_text[end:]
    )
