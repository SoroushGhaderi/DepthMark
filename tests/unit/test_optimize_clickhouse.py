from types import SimpleNamespace

import pytest

from scripts.maintenance.optimize_clickhouse import (
    OptimizeTarget,
    discover_targets,
    optimize_statement,
    run,
    selected_databases,
)


class FakeClickHouseClient:
    def __init__(self, rows):
        self.rows = rows
        self.queries = []

    def execute(self, sql, log_query=False):
        self.queries.append(sql)
        return SimpleNamespace(result_rows=self.rows)


def test_selected_databases_resolves_layers():
    assert selected_databases("bronze", None) == ("bronze",)
    assert selected_databases("gold", None) == ("gold_scenarios", "gold_signals", "gold")
    assert selected_databases("all", "silver") == ("silver",)


def test_selected_databases_rejects_database_outside_layer():
    with pytest.raises(ValueError, match="not part of layer"):
        selected_databases("bronze", "silver")


def test_discover_targets_reads_merge_tree_tables():
    client = FakeClickHouseClient([["bronze", "general"], ["bronze", "match_reference"]])

    targets = discover_targets(client, ("bronze",), None)

    assert targets == [
        OptimizeTarget("bronze", "general"),
        OptimizeTarget("bronze", "match_reference"),
    ]
    assert "engine LIKE '%MergeTree%'" in client.queries[0]


def test_optimize_statement_uses_final_deduplicate():
    statement = optimize_statement(OptimizeTarget("silver", "match"))

    assert statement == "OPTIMIZE TABLE silver.match FINAL DEDUPLICATE"


def test_execute_requires_explicit_scope():
    assert run(["--execute"]) == 2
