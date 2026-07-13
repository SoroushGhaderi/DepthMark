import re
from pathlib import Path
from types import SimpleNamespace

import yaml

from scripts.quality.check_data_quality import strict_exit_code
from src.warehouse.quality import (
    DataQualityService,
    DataQualitySummary,
    DuplicateResult,
    ReconciliationResult,
    TableIdentity,
    build_duplicate_queries,
    build_identity_contracts,
)
from src.warehouse.scope import WarehouseExecutionScope


DEFAULT_SIGNAL_COLUMNS = {"signal_instance_id", "inserted_at"}


class FakeClickHouseClient:
    def __init__(self, tables, columns, responses=None):
        self.tables = tables
        self.columns = columns
        self.responses = responses or {}
        self.queries = []

    def execute(self, sql, log_query=False):
        self.queries.append(sql)
        if "FROM system.tables" in sql:
            return SimpleNamespace(result_rows=[table.split(".", 1) for table in self.tables])
        if "FROM system.columns" in sql:
            rows = []
            for table, table_columns in self.columns.items():
                database, table_name = table.split(".", 1)
                rows.extend([database, table_name, column] for column in table_columns)
            return SimpleNamespace(result_rows=rows)
        for marker, rows in self.responses.items():
            if marker in sql:
                return SimpleNamespace(result_rows=rows)
        return SimpleNamespace(result_rows=[])


def _parenthesized_body(sql: str, open_paren_index: int) -> str:
    depth = 0
    for index, character in enumerate(sql[open_paren_index:], open_paren_index):
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return sql[open_paren_index + 1 : index]
    raise ValueError("Unclosed parenthesized SQL body")


def _split_top_level_csv(value: str) -> list[str]:
    items: list[str] = []
    buffer: list[str] = []
    depth = 0
    quoted_by = ""
    for character in value:
        if quoted_by:
            buffer.append(character)
            if character == quoted_by:
                quoted_by = ""
        elif character in ("'", '"', "`"):
            quoted_by = character
            buffer.append(character)
        elif character == "(":
            depth += 1
            buffer.append(character)
        elif character == ")":
            depth -= 1
            buffer.append(character)
        elif character == "," and depth == 0:
            items.append("".join(buffer).strip())
            buffer = []
        else:
            buffer.append(character)
    trailing = "".join(buffer).strip()
    if trailing:
        items.append(trailing)
    return items


def _signal_ddl_columns(project_root: Path) -> dict[str, tuple[str, ...]]:
    contracts: dict[str, tuple[str, ...]] = {}
    table_pattern = re.compile(
        r"CREATE TABLE IF NOT EXISTS\s+gold_signals\.(sig_[a-z0-9_]+)\s*\(",
        re.IGNORECASE,
    )
    for path in (project_root / "clickhouse/gold/ddl/signals").rglob("create_table_*.sql"):
        sql = path.read_text(encoding="utf-8")
        for match in table_pattern.finditer(sql):
            body = _parenthesized_body(sql, sql.find("(", match.end() - 1))
            columns = []
            for item in _split_top_level_csv(body):
                if not item or item.startswith("--"):
                    continue
                column = item.split()[0].strip("`")
                if column.upper() not in {"INDEX", "CONSTRAINT", "PRIMARY", "ORDER", "PARTITION"}:
                    columns.append(column)
            contracts[match.group(1)] = tuple(columns)
    return contracts


def _signal_insert_columns(sql: str) -> tuple[str, tuple[str, ...]]:
    match = re.search(r"INSERT\s+INTO\s+gold\.(sig_[a-z0-9_]+)\s*\(", sql, re.IGNORECASE)
    if not match:
        raise ValueError("Signal SQL must insert into gold.sig_*")
    body = _parenthesized_body(sql, sql.find("(", match.end() - 1))
    columns = tuple(item.strip().strip("`") for item in _split_top_level_csv(body))
    return match.group(1), columns


def test_table_without_duplicates_passes():
    identity = TableIdentity("bronze", "general", ("match_id",))
    client = FakeClickHouseClient(
        ["bronze.general"],
        {"bronze.general": {"match_id"}},
        {
            "logical_duplicate_count:bronze.general": [[0, 0]],
            "physical_version_count:bronze.general": [[0, 0]],
        },
    )
    service = DataQualityService(client, Path.cwd(), {"bronze.general": identity})

    results, skipped = service.run_duplicates(
        WarehouseExecutionScope.full_history(), ["bronze"], 10
    )

    assert not skipped
    assert results[0].duplicate_identities == 0
    assert results[0].duplicate_rows == 0


def test_duplicate_row_identities_include_counts_and_samples():
    identity = TableIdentity("silver", "shot", ("match_id", "shot_id"), "match_date")
    client = FakeClickHouseClient(
        ["silver.shot"],
        {"silver.shot": {"match_id", "shot_id", "match_date"}},
        {
            "logical_duplicate_count:silver.shot": [[1, 2]],
            "logical_duplicate_samples:silver.shot": [[123, 7, 3]],
            "physical_version_count:silver.shot": [[1, 2]],
            "physical_version_samples:silver.shot": [[123, 7, 3]],
        },
    )
    service = DataQualityService(client, Path.cwd(), {"silver.shot": identity})

    results, _ = service.run_duplicates(WarehouseExecutionScope.for_month("202601"), ["silver"], 10)

    assert results[0].duplicate_identities == 1
    assert results[0].duplicate_rows == 2
    assert results[0].samples == ((123, 7, 3),)
    assert results[0].physical_extra_versions == 2
    assert "toYYYYMM(toDate(match_date)) = 202601" in client.queries[2]


def test_physical_versions_are_diagnostic_not_logical_duplicates():
    identity = TableIdentity("bronze", "general", ("match_id",))
    client = FakeClickHouseClient(
        ["bronze.general"],
        {"bronze.general": {"match_id"}},
        {
            "logical_duplicate_count:bronze.general": [[0, 0]],
            "physical_version_count:bronze.general": [[1, 3]],
            "physical_version_samples:bronze.general": [[123, 4]],
        },
    )
    service = DataQualityService(client, Path.cwd(), {"bronze.general": identity})

    result = service.run_duplicates(WarehouseExecutionScope.full_history(), ["bronze"], 10)[0][0]

    assert result.duplicate_identities == 0
    assert result.physical_duplicate_identities == 1
    assert result.physical_extra_versions == 3
    assert result.physical_samples == ((123, 4),)


def test_missing_or_undefined_row_identity_is_reported():
    client = FakeClickHouseClient(
        ["gold_scenarios.scenario_without_contract"],
        {"gold_scenarios.scenario_without_contract": {"match_id"}},
    )
    service = DataQualityService(client, Path.cwd(), {})

    results, skipped = service.run_duplicates(WarehouseExecutionScope.full_history(), ["gold"], 10)

    assert results == []
    assert skipped[0].table == "gold_scenarios.scenario_without_contract"
    assert "undefined" in skipped[0].reason


def test_declared_identity_with_missing_columns_is_reported():
    table = "gold_signals.sig_drifted"
    identity = TableIdentity(
        "gold_signals", "sig_drifted", ("match_id", "triggered_team_id"), "match_date"
    )
    client = FakeClickHouseClient([table], {table: {"match_id", "match_date"}})
    service = DataQualityService(client, Path.cwd(), {table: identity})

    results, skipped = service.run_duplicates(WarehouseExecutionScope.full_history(), ["gold"], 10)

    assert results == []
    assert "triggered_team_id" in skipped[0].reason


def test_bronze_to_silver_count_and_key_mismatches_fail_reconciliation():
    responses = {
        "reconciliation:shot:bronze_count": [[3]],
        "reconciliation:shot:silver_count": [[3]],
        "reconciliation:shot:missing_count": [[1]],
        "reconciliation:shot:unexpected_count": [[1]],
        "reconciliation:shot:missing_samples": [[100, 4]],
        "reconciliation:shot:unexpected_samples": [[100, 9]],
    }
    client = FakeClickHouseClient([], {}, responses)
    service = DataQualityService(client, Path.cwd(), {})

    result = service.run_reconciliation(WarehouseExecutionScope.for_date("20260102"), ["shot"], 10)[
        0
    ]

    assert result.failed
    assert result.bronze_count == result.silver_count == 3
    assert result.missing_from_silver == 1
    assert result.unexpected_in_silver == 1
    assert result.missing_samples == ((100, 4),)
    assert result.unexpected_samples == ((100, 9),)
    assert all("gold" not in query.lower() for query in client.queries)


def test_gold_duplicates_are_checked_without_reconciliation():
    table = "gold_signals.sig_example"
    identity = TableIdentity(
        "gold_signals", "sig_example", ("match_id", "triggered_team_id"), "match_date"
    )
    client = FakeClickHouseClient(
        [table],
        {table: {"match_id", "triggered_team_id", "match_date"}},
        {
            f"logical_duplicate_count:{table}": [[1, 1]],
            f"logical_duplicate_samples:{table}": [[5, 9, 2]],
            f"physical_version_count:{table}": [[1, 1]],
            f"physical_version_samples:{table}": [[5, 9, 2]],
        },
    )
    service = DataQualityService(client, Path.cwd(), {table: identity})

    summary = service.run(
        WarehouseExecutionScope.full_history(),
        layers=["gold"],
        reconciliation_checks=[],
        sample_limit=10,
    )

    assert summary.duplicate_failure_count == 1
    assert summary.reconciliation_results == []
    assert not any("reconciliation:" in query for query in client.queries)


def test_strict_mode_exit_behavior():
    clean = DataQualitySummary(
        duplicate_results=[DuplicateResult("bronze.general", ("match_id",), 0, 0)]
    )
    failed = DataQualitySummary(reconciliation_results=[ReconciliationResult("match", 2, 1, 1, 0)])
    duplicate_failed = DataQualitySummary(
        duplicate_results=[DuplicateResult("bronze.general", ("match_id",), 1, 1)]
    )
    physical_only = DataQualitySummary(
        duplicate_results=[
            DuplicateResult(
                "bronze.general",
                ("match_id",),
                0,
                0,
                physical_duplicate_identities=1,
                physical_extra_versions=2,
            )
        ]
    )

    assert strict_exit_code(clean, strict=True) == 0
    assert strict_exit_code(failed, strict=False) == 0
    assert strict_exit_code(failed, strict=True) == 1
    assert strict_exit_code(duplicate_failed, strict=True) == 1
    assert strict_exit_code(physical_only, strict=True) == 0


def test_repository_contracts_cover_all_declared_warehouse_outputs():
    contracts = build_identity_contracts(Path.cwd())

    assert len([name for name in contracts if name.startswith("bronze.")]) == 15
    assert len([name for name in contracts if name.startswith("silver.")]) == 8
    assert len([name for name in contracts if name.startswith("gold_scenarios.")]) == 48
    assert len([name for name in contracts if name.startswith("gold_signals.")]) == 344
    assert contracts["gold.signal_activations"].columns == ("signal_instance_id",)


def test_signal_dml_insert_columns_match_ddl_and_catalog_identity():
    project_root = Path.cwd()
    ddl_columns_by_signal = _signal_ddl_columns(project_root)

    assert len(ddl_columns_by_signal) == 344

    for path in sorted((project_root / "clickhouse/gold/dml/signals").rglob("sig_*.sql")):
        signal_id, insert_columns = _signal_insert_columns(path.read_text(encoding="utf-8"))
        ddl_columns = tuple(
            column
            for column in ddl_columns_by_signal[signal_id]
            if column not in DEFAULT_SIGNAL_COLUMNS
        )

        assert insert_columns == ddl_columns, signal_id

    for path in sorted((project_root / "scripts/gold/signal/catalogs").glob("sig_*.md")):
        text = path.read_text(encoding="utf-8")
        frontmatter = yaml.safe_load(text.split("---", 2)[1])
        sql_path = project_root / frontmatter["asset_paths"]["sql"]
        signal_id, insert_columns = _signal_insert_columns(sql_path.read_text(encoding="utf-8"))

        assert signal_id == frontmatter["signal_id"]
        assert set(frontmatter["row_identity"]).issubset(set(insert_columns))


def test_bronze_date_duplicate_query_scopes_through_match_reference():
    identity = TableIdentity(
        "bronze", "player", ("match_id", "player_id"), scope_expression="match_id"
    )

    queries = build_duplicate_queries(identity, WarehouseExecutionScope.for_date("20260102"), 10)

    assert "FROM bronze.player FINAL" in queries.logical_count_sql
    assert "FROM bronze.player\n" in queries.physical_count_sql
    assert "r.identity_row_count - f.identity_row_count" in queries.physical_count_sql
    assert "match_id IN (SELECT match_id FROM bronze.match_reference" in queries.logical_count_sql
    assert "toDate(match_date) = toDate('2026-01-02')" in queries.logical_count_sql
