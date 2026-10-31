from src.warehouse.commands import recreate_tables as recreate_clickhouse_tables
from src.warehouse.commands.recreate_tables import RELOAD_HINTS, run


class _RecreationClient:
    """Fake ClickHouse client serving live schemas/row counts and recording mutations."""

    def __init__(self, live_tables, row_counts):
        self.live_tables = live_tables
        self.row_counts = row_counts
        self.mutations = []

    def execute(self, query, *args, **kwargs):
        if "FROM system.columns" in query:
            rows = [
                (database, table, name, column_type)
                for (database, table), (columns, _) in self.live_tables.items()
                for name, column_type in columns
            ]
        elif "total_rows" in query:
            rows = [(database, table, rows) for (database, table), rows in self.row_counts.items()]
        elif "FROM system.tables" in query:
            rows = [
                (database, table, sorting_key)
                for (database, table), (_, sorting_key) in self.live_tables.items()
            ]
        else:
            self.mutations.append(query)
            rows = []
        return type("Result", (), {"result_rows": rows})()

    def disconnect(self):
        pass


def _drifted_bronze_general():
    """Live bronze.general with one column retyped; every other table is absent."""
    inventory = recreate_clickhouse_tables.setup_inventory(
        recreate_clickhouse_tables.resolve_clickhouse_root()
    )
    general = next(t.expected for t in inventory if t.qualified_name == "bronze.general")
    columns = [
        (name, "Int64" if name == "match_id" else column_type)
        for name, column_type in general.columns
    ]
    return {("bronze", "general"): (columns, ", ".join(general.sorting_key))}


def test_execute_without_scope_is_refused():
    assert run(["--execute"]) == 2


def test_dry_run_never_mutates():
    client = _RecreationClient({}, {("bronze", "general"): 10})

    assert run(["--layer", "bronze", "--table", "general"], client=client) == 0
    assert client.mutations == []


def test_execute_drifted_recreates_only_drifted_tables():
    client = _RecreationClient(_drifted_bronze_general(), {("bronze", "general"): 10})

    assert run(["--drifted", "--execute"], client=client) == 0
    assert client.mutations[0] == "DROP TABLE IF EXISTS bronze.general"
    assert client.mutations[1].startswith("CREATE TABLE IF NOT EXISTS bronze.general")
    assert len(client.mutations) == 2


def test_drifted_without_drift_does_nothing():
    client = _RecreationClient({}, {})

    assert run(["--drifted", "--execute"], client=client) == 0
    assert client.mutations == []


def test_unknown_table_selection_is_rejected():
    assert run(["--table", "does_not_exist"], client=_RecreationClient({}, {})) == 2


def test_reload_hints_cover_every_layer():
    assert set(RELOAD_HINTS) == set(recreate_clickhouse_tables.LAYER_CHOICES)
