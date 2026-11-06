from types import SimpleNamespace

import pytest

from src.warehouse.commands.optimize import (
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
    assert selected_databases("bronze", None) == ("fotmob_bronze",)
    assert selected_databases("gold", None) == (
        "fotmob_gold_scenarios",
        "fotmob_gold_signals",
        "fotmob_gold",
    )
    assert selected_databases("all", "fotmob_silver") == ("fotmob_silver",)


def test_selected_databases_rejects_database_outside_layer():
    with pytest.raises(ValueError, match="not part of layer"):
        selected_databases("bronze", "fotmob_silver")


def test_discover_targets_reads_merge_tree_tables():
    client = FakeClickHouseClient(
        [["fotmob_bronze", "general"], ["fotmob_bronze", "match_reference"]]
    )

    targets = discover_targets(client, ("fotmob_bronze",), None)

    assert targets == [
        OptimizeTarget("fotmob_bronze", "general"),
        OptimizeTarget("fotmob_bronze", "match_reference"),
    ]
    assert "engine LIKE '%MergeTree%'" in client.queries[0]


def test_optimize_statement_uses_final_deduplicate():
    statement = optimize_statement(OptimizeTarget("fotmob_silver", "match"))

    assert statement == "OPTIMIZE TABLE fotmob_silver.match FINAL DEDUPLICATE"


def test_execute_requires_explicit_scope():
    assert run(["--execute"]) == 2
