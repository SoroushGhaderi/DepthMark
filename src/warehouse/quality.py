"""Read-only duplicate detection and Bronze-to-Silver reconciliation."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple

import yaml

from src.warehouse.scope import WarehouseExecutionScope
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.contracts import BRONZE_REQUIRED_KEYS, SILVER_TABLE_KEYS

WAREHOUSE_DATABASES = ("bronze", "silver", "gold_scenarios", "gold_signals", "gold")
_SAFE_IDENTIFIER = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
_SCENARIO_TABLE = re.compile(
    r"CREATE TABLE IF NOT EXISTS gold_scenarios\.(scenario_[a-zA-Z0-9_]+).*?"
    r"ORDER BY\s+(\([^;]+?\)|[a-zA-Z_][a-zA-Z0-9_]*)\s*(?:PARTITION BY|;)",
    re.DOTALL,
)
_SQL_FUNCTIONS = {"assumeNotNull", "ifNull", "toDateOrZero"}


@dataclass(frozen=True)
class TableIdentity:
    """Declared row identity and temporal scope rule for one warehouse table."""

    database: str
    table: str
    columns: Tuple[str, ...]
    scope_column: Optional[str] = None
    scope_expression: Optional[str] = None
    source: str = "layer contract"

    @property
    def qualified_name(self) -> str:
        return f"{self.database}.{self.table}"


@dataclass(frozen=True)
class DuplicateResult:
    """Logical duplicate result plus physical ReplacingMergeTree version diagnostics."""

    table: str
    identity_columns: Tuple[str, ...]
    duplicate_identities: int
    duplicate_rows: int
    samples: Tuple[Tuple[Any, ...], ...] = ()
    physical_duplicate_identities: int = 0
    physical_extra_versions: int = 0
    physical_samples: Tuple[Tuple[Any, ...], ...] = ()


@dataclass(frozen=True)
class DuplicateQueries:
    """Logical and physical duplicate SQL for one table."""

    logical_count_sql: str
    logical_sample_sql: str
    physical_count_sql: str
    physical_sample_sql: str


@dataclass(frozen=True)
class SkippedTable:
    """Table that could not be duplicate-checked."""

    table: str
    reason: str


@dataclass(frozen=True)
class ReconciliationResult:
    """Bidirectional identity-set comparison for a Bronze/Silver mapping."""

    name: str
    bronze_count: int
    silver_count: int
    missing_from_silver: int
    unexpected_in_silver: int
    missing_samples: Tuple[Tuple[Any, ...], ...] = ()
    unexpected_samples: Tuple[Tuple[Any, ...], ...] = ()

    @property
    def failed(self) -> bool:
        return self.missing_from_silver > 0 or self.unexpected_in_silver > 0


@dataclass
class DataQualitySummary:
    """Structured result of a complete quality run."""

    duplicate_results: List[DuplicateResult] = field(default_factory=list)
    skipped_tables: List[SkippedTable] = field(default_factory=list)
    reconciliation_results: List[ReconciliationResult] = field(default_factory=list)

    @property
    def duplicate_failure_count(self) -> int:
        return sum(result.duplicate_identities > 0 for result in self.duplicate_results)

    @property
    def reconciliation_failure_count(self) -> int:
        return sum(result.failed for result in self.reconciliation_results)

    @property
    def has_failures(self) -> bool:
        return self.duplicate_failure_count > 0 or self.reconciliation_failure_count > 0


@dataclass(frozen=True)
class ReconciliationDefinition:
    """Identity datasets compared between Bronze and Silver."""

    name: str
    keys: Tuple[str, ...]
    bronze_sql: str
    silver_table: str


def _rows(result: Any) -> List[List[Any]]:
    if hasattr(result, "result_rows"):
        return list(result.result_rows or [])
    if isinstance(result, list):
        return result
    return []


def _scalar(client: ClickHouseClient, sql: str) -> int:
    rows = _rows(client.execute(sql, log_query=False))
    return int(rows[0][0]) if rows else 0


def _validate_identifier(value: str) -> str:
    if not _SAFE_IDENTIFIER.fullmatch(value):
        raise ValueError(f"Unsafe SQL identifier: {value}")
    return value


def _scope_predicate(identity: TableIdentity, scope: WarehouseExecutionScope) -> str:
    if scope.kind == "full-history":
        return ""
    if identity.scope_expression:
        expression = identity.scope_expression
    elif identity.scope_column:
        expression = identity.scope_column
    else:
        return ""
    if scope.kind == "date":
        date_value = scope.iso_date
        return f"toDate({expression}) = toDate('{date_value}')"
    month_value = scope.value
    return f"toYYYYMM(toDate({expression})) = {month_value}"


def _bronze_scope_expression() -> str:
    return "match_id IN (SELECT match_id FROM bronze.match_reference WHERE {predicate})"


def _base_identity_contracts() -> Dict[str, TableIdentity]:
    contracts: Dict[str, TableIdentity] = {}
    for table, keys in BRONZE_REQUIRED_KEYS.items():
        scope_column = "match_date" if table == "match_reference" else None
        scope_expression = None if table == "match_reference" else "match_id"
        contracts[f"bronze.{table}"] = TableIdentity(
            database="bronze",
            table=table,
            columns=tuple(keys),
            scope_column=scope_column,
            scope_expression=scope_expression,
            source="BRONZE_REQUIRED_KEYS",
        )
    for table, keys in SILVER_TABLE_KEYS.items():
        contracts[f"silver.{table}"] = TableIdentity(
            database="silver",
            table=table,
            columns=tuple(keys),
            scope_column="match_date",
            source="SILVER_TABLE_KEYS",
        )
    contracts["gold.signal_activations"] = TableIdentity(
        database="gold",
        table="signal_activations",
        columns=("signal_instance_id",),
        scope_column="match_date",
        source="Gold activation contract",
    )
    return contracts


def load_scenario_identity_contracts(ddl_path: Path) -> Dict[str, TableIdentity]:
    """Read scenario row identities from their declared ClickHouse ORDER BY keys."""
    sql = ddl_path.read_text(encoding="utf-8")
    contracts: Dict[str, TableIdentity] = {}
    for table, order_expression in _SCENARIO_TABLE.findall(sql):
        identifiers = re.findall(r"\b[a-zA-Z_][a-zA-Z0-9_]*\b", order_expression)
        columns = tuple(
            value
            for value in identifiers
            if value not in _SQL_FUNCTIONS and value not in {"NULL"} and not value.isdigit()
        )
        contracts[f"gold_scenarios.{table}"] = TableIdentity(
            database="gold_scenarios",
            table=table,
            columns=columns,
            scope_expression="parseDateTimeBestEffortOrNull(match_time_utc_date)",
            source="clickhouse/gold/ddl/01_create_scenario_tables.sql ORDER BY",
        )
    return contracts


def load_signal_identity_contracts(catalog_dir: Path) -> Dict[str, TableIdentity]:
    """Read Gold signal row identities from catalog frontmatter."""
    contracts: Dict[str, TableIdentity] = {}
    for path in sorted(catalog_dir.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---\n"):
            continue
        try:
            frontmatter = text.split("---", 2)[1]
            metadata = yaml.safe_load(frontmatter) or {}
        except (ValueError, yaml.YAMLError):
            continue
        table_name = (metadata.get("asset_paths") or {}).get("table")
        row_identity = metadata.get("row_identity")
        if not isinstance(table_name, str) or "." not in table_name:
            continue
        database, table = table_name.split(".", 1)
        columns = tuple(row_identity) if isinstance(row_identity, list) else ()
        contracts[table_name] = TableIdentity(
            database=database,
            table=table,
            columns=columns,
            scope_column="match_date",
            source=f"{path.name} row_identity",
        )
    return contracts


def build_identity_contracts(project_root: Path) -> Dict[str, TableIdentity]:
    """Build the repository-backed identity registry used by quality checks."""
    contracts = _base_identity_contracts()
    contracts.update(
        load_scenario_identity_contracts(
            project_root / "clickhouse/gold/ddl/01_create_scenario_tables.sql"
        )
    )
    contracts.update(load_signal_identity_contracts(project_root / "scripts/gold/signal/catalogs"))
    return contracts


def build_duplicate_queries(
    identity: TableIdentity,
    scope: WarehouseExecutionScope,
    sample_limit: int,
) -> DuplicateQueries:
    """Build logical FINAL checks and non-failing physical-version diagnostics."""
    keys_csv = ", ".join(_validate_identifier(column) for column in identity.columns)
    predicate = _scope_predicate(identity, scope)
    if (
        identity.database == "bronze"
        and scope.kind != "full-history"
        and identity.table != "match_reference"
    ):
        reference_identity = TableIdentity("bronze", "match_reference", ("match_id",), "match_date")
        reference_predicate = _scope_predicate(reference_identity, scope)
        predicate = _bronze_scope_expression().format(predicate=reference_predicate)
    where_clause = f"\nWHERE {predicate}" if predicate else ""
    final_counts = (
        f"SELECT {keys_csv}, count() AS identity_row_count\n"
        f"FROM {identity.qualified_name} FINAL{where_clause}\n"
        f"GROUP BY {keys_csv}"
    )
    raw_counts = (
        f"SELECT {keys_csv}, count() AS identity_row_count\n"
        f"FROM {identity.qualified_name}{where_clause}\n"
        f"GROUP BY {keys_csv}"
    )
    logical_grouped = f"{final_counts}\nHAVING identity_row_count > 1"
    joined_keys = ", ".join(identity.columns)
    selected_keys = ", ".join(f"r.{column}" for column in identity.columns)
    physical_grouped = (
        f"SELECT {selected_keys}, r.identity_row_count AS raw_row_count, "
        "f.identity_row_count AS final_row_count, "
        "r.identity_row_count - f.identity_row_count AS physical_extra_versions\n"
        f"FROM (\n{raw_counts}\n) AS r\n"
        f"INNER JOIN (\n{final_counts}\n) AS f USING ({joined_keys})\n"
        "WHERE r.identity_row_count > f.identity_row_count"
    )
    logical_count_sql = (
        f"/* logical_duplicate_count:{identity.qualified_name} */\n"
        "SELECT count(), ifNull(sum(identity_row_count - 1), 0)\n"
        f"FROM (\n{logical_grouped}\n)"
    )
    logical_sample_sql = (
        f"/* logical_duplicate_samples:{identity.qualified_name} */\n"
        f"{logical_grouped}\nORDER BY {keys_csv}\nLIMIT {sample_limit}"
    )
    physical_count_sql = (
        f"/* physical_version_count:{identity.qualified_name} */\n"
        "SELECT count(), ifNull(sum(physical_extra_versions), 0)\n"
        f"FROM (\n{physical_grouped}\n)"
    )
    physical_sample_sql = (
        f"/* physical_version_samples:{identity.qualified_name} */\n"
        f"{physical_grouped}\nORDER BY {keys_csv}\nLIMIT {sample_limit}"
    )
    return DuplicateQueries(
        logical_count_sql=logical_count_sql,
        logical_sample_sql=logical_sample_sql,
        physical_count_sql=physical_count_sql,
        physical_sample_sql=physical_sample_sql,
    )


def _reconciliation_definitions() -> Dict[str, ReconciliationDefinition]:
    direct = {
        "match": ("bronze.general", ("match_id",), "silver.match", ""),
        "period": ("bronze.period", ("match_id", "period"), "silver.period_stat", ""),
        "player": (
            "bronze.player",
            ("match_id", "player_id"),
            "silver.player_match_stat",
            "team_id IS NOT NULL",
        ),
        "momentum": ("bronze.momentum", ("match_id", "minute"), "silver.momentum", ""),
        "shot": ("bronze.shotmap", ("match_id", "shot_id"), "silver.shot", ""),
        "card": ("bronze.cards", ("match_id", "event_id"), "silver.card", ""),
    }
    definitions: Dict[str, ReconciliationDefinition] = {}
    for name, (bronze_table, keys, silver_table, eligibility) in direct.items():
        where = f" WHERE {eligibility}" if eligibility else ""
        definitions[name] = ReconciliationDefinition(
            name=name,
            keys=keys,
            bronze_sql=f"SELECT {', '.join(keys)} FROM {bronze_table}{where}",
            silver_table=silver_table,
        )
    definitions["personnel"] = ReconciliationDefinition(
        name="personnel",
        keys=("match_id", "team_side", "role", "person_id"),
        bronze_sql="""
SELECT match_id, team_side, 'starter' AS role, player_id AS person_id
FROM bronze.starters
WHERE match_id > 0 AND player_id > 0 AND length(trim(BOTH ' ' FROM team_side)) > 0
UNION ALL
SELECT match_id, team_side, 'substitute' AS role, player_id AS person_id
FROM bronze.substitutes
WHERE match_id > 0 AND player_id > 0 AND length(trim(BOTH ' ' FROM team_side)) > 0
UNION ALL
SELECT match_id, team_side, 'coach' AS role, coach_id AS person_id
FROM bronze.coaches
WHERE match_id > 0 AND coach_id > 0 AND length(trim(BOTH ' ' FROM team_side)) > 0
""".strip(),
        silver_table="silver.match_personnel",
    )
    definitions["team_form"] = ReconciliationDefinition(
        name="team_form",
        keys=("match_id", "team_id", "form_position"),
        bronze_sql="SELECT match_id, team_id, form_position FROM bronze.team_form",
        silver_table="silver.team_form",
    )
    return definitions


def reconciliation_check_names() -> List[str]:
    return list(_reconciliation_definitions())


def _apply_reconciliation_scope(
    dataset_sql: str,
    layer: str,
    scope: WarehouseExecutionScope,
) -> str:
    if scope.kind == "full-history":
        return dataset_sql
    if layer == "bronze":
        identity = TableIdentity("bronze", "match_reference", ("match_id",), "match_date")
        predicate = _scope_predicate(identity, scope)
        return f"SELECT * FROM (\n{dataset_sql}\n) WHERE match_id IN (SELECT match_id FROM bronze.match_reference WHERE {predicate})"
    identity = TableIdentity("silver", "match", ("match_id",), "match_date")
    predicate = _scope_predicate(identity, scope)
    return f"SELECT * FROM (\n{dataset_sql}\n) WHERE {predicate}"


def build_reconciliation_queries(
    definition: ReconciliationDefinition,
    scope: WarehouseExecutionScope,
    sample_limit: int,
) -> Mapping[str, str]:
    """Build bidirectional Bronze/Silver identity-set comparison SQL."""
    keys_csv = ", ".join(definition.keys)
    b_keys = ", ".join(f"b.{key}" for key in definition.keys)
    s_keys = ", ".join(f"s.{key}" for key in definition.keys)
    bronze = _apply_reconciliation_scope(definition.bronze_sql, "bronze", scope)
    silver_raw = f"SELECT {keys_csv}, match_date FROM {definition.silver_table}"
    silver = _apply_reconciliation_scope(silver_raw, "silver", scope)
    b_set = f"(SELECT DISTINCT {keys_csv} FROM (\n{bronze}\n))"
    s_set = f"(SELECT DISTINCT {keys_csv} FROM (\n{silver}\n))"
    join_keys = ", ".join(definition.keys)
    first_key = definition.keys[0]
    missing = (
        f"FROM {b_set} AS b LEFT JOIN {s_set} AS s USING ({join_keys})\n"
        f"WHERE s.{first_key} IS NULL"
    )
    unexpected = (
        f"FROM {s_set} AS s LEFT JOIN {b_set} AS b USING ({join_keys})\n"
        f"WHERE b.{first_key} IS NULL"
    )
    name = definition.name
    return {
        "bronze_count": f"/* reconciliation:{name}:bronze_count */ SELECT count() FROM {b_set}",
        "silver_count": f"/* reconciliation:{name}:silver_count */ SELECT count() FROM {s_set}",
        "missing_count": f"/* reconciliation:{name}:missing_count */ SELECT count() {missing}",
        "unexpected_count": (
            f"/* reconciliation:{name}:unexpected_count */ SELECT count() {unexpected}"
        ),
        "missing_samples": (
            f"/* reconciliation:{name}:missing_samples */ SELECT {b_keys} {missing} "
            f"ORDER BY {b_keys} LIMIT {sample_limit}"
        ),
        "unexpected_samples": (
            f"/* reconciliation:{name}:unexpected_samples */ SELECT {s_keys} {unexpected} "
            f"ORDER BY {s_keys} LIMIT {sample_limit}"
        ),
    }


class DataQualityService:
    """Orchestrate read-only warehouse quality checks."""

    def __init__(
        self,
        client: ClickHouseClient,
        project_root: Path,
        identities: Optional[Mapping[str, TableIdentity]] = None,
    ) -> None:
        self.client = client
        self.identities = dict(
            build_identity_contracts(project_root) if identities is None else identities
        )

    def _warehouse_metadata(self) -> Tuple[List[str], Dict[str, Set[str]]]:
        databases = ", ".join(f"'{database}'" for database in WAREHOUSE_DATABASES)
        table_rows = _rows(
            self.client.execute(
                "SELECT database, name FROM system.tables "
                f"WHERE database IN ({databases}) ORDER BY database, name",
                log_query=False,
            )
        )
        column_rows = _rows(
            self.client.execute(
                "SELECT database, table, name FROM system.columns "
                f"WHERE database IN ({databases}) ORDER BY database, table, position",
                log_query=False,
            )
        )
        tables = [f"{row[0]}.{row[1]}" for row in table_rows]
        columns: Dict[str, Set[str]] = {}
        for database, table, column in column_rows:
            columns.setdefault(f"{database}.{table}", set()).add(str(column))
        return tables, columns

    def run_duplicates(
        self,
        scope: WarehouseExecutionScope,
        layers: Sequence[str],
        sample_limit: int,
    ) -> Tuple[List[DuplicateResult], List[SkippedTable]]:
        results: List[DuplicateResult] = []
        skipped: List[SkippedTable] = []
        tables, columns_by_table = self._warehouse_metadata()
        selected_databases = {
            database
            for layer in layers
            for database in (
                ("bronze",)
                if layer == "bronze"
                else ("silver",)
                if layer == "silver"
                else ("gold_scenarios", "gold_signals", "gold")
            )
        }
        for table in tables:
            database = table.split(".", 1)[0]
            if database not in selected_databases:
                continue
            if table == "gold.signal_activations_stage":
                skipped.append(
                    SkippedTable(table, "ephemeral activation staging table is not a stable target")
                )
                continue
            identity = self.identities.get(table)
            if identity is None or not identity.columns:
                skipped.append(SkippedTable(table, "grain or row identity is undefined"))
                continue
            missing_columns = sorted(set(identity.columns) - columns_by_table.get(table, set()))
            if missing_columns:
                skipped.append(
                    SkippedTable(table, f"identity columns are absent: {missing_columns}")
                )
                continue
            queries = build_duplicate_queries(identity, scope, sample_limit)
            count_rows = _rows(self.client.execute(queries.logical_count_sql, log_query=False))
            duplicate_identities = int(count_rows[0][0]) if count_rows else 0
            duplicate_rows = int(count_rows[0][1]) if count_rows else 0
            samples = ()
            if duplicate_identities:
                samples = tuple(
                    tuple(row)
                    for row in _rows(
                        self.client.execute(queries.logical_sample_sql, log_query=False)
                    )
                )
            physical_rows = _rows(self.client.execute(queries.physical_count_sql, log_query=False))
            physical_duplicate_identities = int(physical_rows[0][0]) if physical_rows else 0
            physical_extra_versions = int(physical_rows[0][1]) if physical_rows else 0
            physical_samples = ()
            if physical_duplicate_identities:
                physical_samples = tuple(
                    tuple(row)
                    for row in _rows(
                        self.client.execute(queries.physical_sample_sql, log_query=False)
                    )
                )
            results.append(
                DuplicateResult(
                    table=table,
                    identity_columns=identity.columns,
                    duplicate_identities=duplicate_identities,
                    duplicate_rows=duplicate_rows,
                    samples=samples,
                    physical_duplicate_identities=physical_duplicate_identities,
                    physical_extra_versions=physical_extra_versions,
                    physical_samples=physical_samples,
                )
            )
        return results, skipped

    def run_reconciliation(
        self,
        scope: WarehouseExecutionScope,
        checks: Iterable[str],
        sample_limit: int,
    ) -> List[ReconciliationResult]:
        definitions = _reconciliation_definitions()
        results: List[ReconciliationResult] = []
        for name in checks:
            definition = definitions[name]
            queries = build_reconciliation_queries(definition, scope, sample_limit)
            bronze_count = _scalar(self.client, queries["bronze_count"])
            silver_count = _scalar(self.client, queries["silver_count"])
            missing_count = _scalar(self.client, queries["missing_count"])
            unexpected_count = _scalar(self.client, queries["unexpected_count"])
            missing_samples: Tuple[Tuple[Any, ...], ...] = ()
            unexpected_samples: Tuple[Tuple[Any, ...], ...] = ()
            if missing_count:
                missing_samples = tuple(
                    tuple(row)
                    for row in _rows(
                        self.client.execute(queries["missing_samples"], log_query=False)
                    )
                )
            if unexpected_count:
                unexpected_samples = tuple(
                    tuple(row)
                    for row in _rows(
                        self.client.execute(queries["unexpected_samples"], log_query=False)
                    )
                )
            results.append(
                ReconciliationResult(
                    name=name,
                    bronze_count=bronze_count,
                    silver_count=silver_count,
                    missing_from_silver=missing_count,
                    unexpected_in_silver=unexpected_count,
                    missing_samples=missing_samples,
                    unexpected_samples=unexpected_samples,
                )
            )
        return results

    def run(
        self,
        scope: WarehouseExecutionScope,
        layers: Sequence[str],
        reconciliation_checks: Iterable[str],
        sample_limit: int,
    ) -> DataQualitySummary:
        duplicate_results, skipped_tables = self.run_duplicates(scope, layers, sample_limit)
        reconciliation_results = self.run_reconciliation(scope, reconciliation_checks, sample_limit)
        return DataQualitySummary(
            duplicate_results=duplicate_results,
            skipped_tables=skipped_tables,
            reconciliation_results=reconciliation_results,
        )
