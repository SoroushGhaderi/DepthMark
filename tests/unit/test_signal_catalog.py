"""Tests for the single validated signal catalog reader (ADR 0033)."""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path
from typing import Any

import pytest
import yaml

from scripts.quality import check_signal_catalogs
from src.fotmob.gold.signal_catalog import (
    INDEX_END_MARKER,
    INDEX_FILE_NAME,
    INDEX_START_MARKER,
    SIGNAL_CATALOG_DIR,
    SignalCatalogError,
    load_signal_catalog,
    render_signal_index,
    replace_signal_index,
    signal_instance_id_expression,
)
from src.warehouse.schema_drift import column_default_expression, parse_expected_tables

MATCH_SIGNAL = "sig_match_shooting_goals_goal_fest"
PLAYER_SIGNAL = "sig_player_shooting_goals_hat_trick_hero"
TEAM_IDENTITY = ["match_id", "triggered_side"]
PLAYER_IDENTITY = ["match_id", "triggered_player_id", "triggered_team_id"]


def _frontmatter(signal_id: str, **overrides: Any) -> dict[str, Any]:
    entity = signal_id.split("_")[1]
    frontmatter: dict[str, Any] = {
        "signal_id": signal_id,
        "status": "active",
        "entity": entity,
        "family": "shooting",
        "subfamily": "goals",
        "grain": "match_player" if entity == "player" else "match_team",
        "headline": "Headline",
        "trigger": "Trigger",
        "row_identity": PLAYER_IDENTITY if entity == "player" else TEAM_IDENTITY,
        "asset_paths": {
            "table": f"gold_signals.{signal_id}",
            "sql": f"clickhouse/gold/dml/signals/{entity}/{signal_id}.sql",
        },
    }
    frontmatter.update(overrides)
    return frontmatter


def _hash(signal_id: str, columns: Sequence[str]) -> str:
    components = ", '|', ".join(
        ["'v1'", f"'{signal_id}'", *[f"coalesce(toString({column}), '')" for column in columns]]
    )
    return f"lower(hex(SHA256(concat({components}))))"


class SignalProject:
    """A minimal project tree holding signal catalogs, DML, and DDL."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.catalog_dir = root / "catalogs"
        self.catalog_dir.mkdir()
        (self.catalog_dir / INDEX_FILE_NAME).write_text(
            f"# Index\n\n{INDEX_START_MARKER}\n{INDEX_END_MARKER}\n", encoding="utf-8"
        )

    def add_signal(
        self,
        signal_id: str,
        *,
        frontmatter: dict[str, Any] | None = None,
        hashed_columns: Sequence[str] | None = None,
        order_by: str | None = None,
        ddl_columns: Sequence[str] | None = None,
        write_sql: bool = True,
        write_ddl: bool = True,
        write_catalog: bool = True,
    ) -> None:
        entity = signal_id.split("_")[1]
        values = frontmatter if frontmatter is not None else _frontmatter(signal_id)
        identity = list(values.get("row_identity") or [])
        if write_catalog:
            self.write_catalog(signal_id, values)
        if write_sql:
            sql_path = self.root / "clickhouse/gold/dml/signals" / entity / f"{signal_id}.sql"
            sql_path.parent.mkdir(parents=True, exist_ok=True)
            sql_path.write_text(f"INSERT INTO gold_signals.{signal_id} SELECT 1;\n")
        if write_ddl:
            columns = list(ddl_columns if ddl_columns is not None else identity)
            hashed = hashed_columns if hashed_columns is not None else identity
            column_sql = ",\n".join(
                [f"    {column} Int32" for column in ["match_id", *columns] if column]
            )
            ddl_path = self.root / "clickhouse/gold/ddl/signals" / entity / f"{signal_id}.sql"
            ddl_path.parent.mkdir(parents=True, exist_ok=True)
            ddl_path.write_text(
                f"CREATE TABLE IF NOT EXISTS gold_signals.{signal_id} (\n"
                f"{column_sql},\n"
                f"    signal_instance_id String DEFAULT {_hash(signal_id, hashed)},\n"
                "    inserted_at DateTime DEFAULT now()\n"
                ")\nENGINE = ReplacingMergeTree(inserted_at)\n"
                f"ORDER BY ({order_by or 'match_id, signal_instance_id'});\n"
            )

    def write_catalog(self, signal_id: str, frontmatter: dict[str, Any], body: str = "") -> None:
        text = "---\n" + yaml.safe_dump(frontmatter, sort_keys=False) + "---\n"
        (self.catalog_dir / f"{signal_id}.md").write_text(
            text + (body or f"# {signal_id}\n"), encoding="utf-8"
        )

    def load(self):
        return load_signal_catalog(self.catalog_dir, project_root=self.root)

    def violations(self) -> list:
        with pytest.raises(SignalCatalogError) as raised:
            self.load()
        return [violation.describe() for violation in raised.value.violations]


@pytest.fixture
def project(tmp_path: Path) -> SignalProject:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(MATCH_SIGNAL)
    signal_project.add_signal(PLAYER_SIGNAL)
    return signal_project


def test_valid_catalog_loads_ordered_definitions(project: SignalProject) -> None:
    catalog = project.load()

    assert [definition.signal_id for definition in catalog] == [MATCH_SIGNAL, PLAYER_SIGNAL]
    match_signal = catalog.get(MATCH_SIGNAL)
    assert match_signal.entity == "match"
    assert match_signal.grain == "match_team"
    assert match_signal.name == "goal_fest"
    assert match_signal.tags == ("shooting", "goals")
    assert match_signal.table == f"gold_signals.{MATCH_SIGNAL}"
    assert match_signal.body == f"# {MATCH_SIGNAL}"
    assert match_signal.frontmatter_dict()["headline"] == "Headline"


def test_identity_fields_lead_with_match_id(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(
        PLAYER_SIGNAL,
        frontmatter=_frontmatter(PLAYER_SIGNAL, row_identity=["triggered_player_id"]),
        hashed_columns=["match_id", "triggered_player_id"],
    )

    definition = signal_project.load().get(PLAYER_SIGNAL)

    assert definition.row_identity == ("triggered_player_id",)
    assert definition.identity_fields == ("match_id", "triggered_player_id")


def test_entity_must_equal_signal_id_segment(project: SignalProject) -> None:
    project.write_catalog(MATCH_SIGNAL, _frontmatter(MATCH_SIGNAL, entity="team"))

    assert project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: entity 'team' must equal the signal_id segment 'match'"
    ]


def test_family_and_subfamily_must_equal_signal_id_segments(project: SignalProject) -> None:
    project.write_catalog(
        MATCH_SIGNAL, _frontmatter(MATCH_SIGNAL, family="passing", subfamily="crosses")
    )

    violations = project.violations()

    assert any("family 'passing' must equal" in violation for violation in violations)
    assert any("subfamily 'crosses' must equal" in violation for violation in violations)


def test_runner_asset_path_is_undeclared(project: SignalProject) -> None:
    frontmatter = _frontmatter(MATCH_SIGNAL)
    frontmatter["asset_paths"]["runner"] = "scripts/gold/run_gold_sql_jobs.py"
    project.write_catalog(MATCH_SIGNAL, frontmatter)

    assert project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: undeclared asset_paths keys ['runner']"
    ]


def test_undeclared_and_missing_frontmatter_keys_are_violations(project: SignalProject) -> None:
    frontmatter = _frontmatter(MATCH_SIGNAL, owner="analytics")
    del frontmatter["headline"]
    project.write_catalog(MATCH_SIGNAL, frontmatter)

    violations = project.violations()

    assert f"catalogs/{MATCH_SIGNAL}.md: missing frontmatter keys ['headline']" in violations
    assert f"catalogs/{MATCH_SIGNAL}.md: undeclared frontmatter keys ['owner']" in violations


@pytest.mark.parametrize("status", ["inactive", "experimental", "Active"])
def test_status_must_be_active_or_deprecated(project: SignalProject, status: str) -> None:
    project.write_catalog(MATCH_SIGNAL, _frontmatter(MATCH_SIGNAL, status=status))

    assert project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: status '{status}' must be one of ['active', 'deprecated']"
    ]


def test_grain_must_match_entity(project: SignalProject) -> None:
    project.write_catalog(PLAYER_SIGNAL, _frontmatter(PLAYER_SIGNAL, grain="match_team"))

    assert project.violations() == [
        f"catalogs/{PLAYER_SIGNAL}.md: grain 'match_team' must be 'match_player' for player signals"
    ]


def test_signal_id_must_match_file_name_and_grammar(project: SignalProject) -> None:
    project.write_catalog(MATCH_SIGNAL, _frontmatter("sig_match_goals"))

    violations = project.violations()

    assert any("does not match the file name" in violation for violation in violations)
    assert any("must match sig_<entity>_<family>" in violation for violation in violations)


def test_asset_paths_must_follow_convention_and_exist(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(MATCH_SIGNAL, write_sql=False)
    frontmatter = _frontmatter(PLAYER_SIGNAL)
    frontmatter["asset_paths"]["table"] = f"gold.{PLAYER_SIGNAL}"
    signal_project.add_signal(PLAYER_SIGNAL, frontmatter=frontmatter)

    violations = signal_project.violations()

    assert (
        f"catalogs/{MATCH_SIGNAL}.md: asset_paths.sql "
        f"'clickhouse/gold/dml/signals/match/{MATCH_SIGNAL}.sql' does not exist"
    ) in violations
    assert (
        f"catalogs/{PLAYER_SIGNAL}.md: asset_paths.table must be 'gold_signals.{PLAYER_SIGNAL}'"
    ) in violations


def test_signal_sql_must_insert_into_its_catalog_table(project: SignalProject) -> None:
    sql_path = project.root / f"clickhouse/gold/dml/signals/match/{MATCH_SIGNAL}.sql"
    sql_path.write_text(f"INSERT INTO gold.{MATCH_SIGNAL} SELECT 1;\n")

    assert project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: signal SQL must INSERT INTO "
        f"gold_signals.{MATCH_SIGNAL}, not gold.{MATCH_SIGNAL}"
    ]


def test_signal_sql_and_ddl_without_catalog_are_violations(project: SignalProject) -> None:
    orphan = "sig_team_shooting_goals_orphan"
    project.add_signal(orphan, frontmatter=_frontmatter(orphan), write_catalog=False)

    assert project.violations() == [
        f"clickhouse/gold/dml/signals/team/{orphan}.sql: signal SQL has no catalog",
        f"clickhouse/gold/ddl/signals/team/{orphan}.sql: gold_signals.{orphan} has no catalog",
    ]


def test_catalog_without_ddl_is_a_violation(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(MATCH_SIGNAL, write_ddl=False)

    assert signal_project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: gold_signals.{MATCH_SIGNAL} has no DDL"
    ]


def test_ddl_hash_must_use_row_identity_in_catalog_order(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(
        PLAYER_SIGNAL,
        hashed_columns=["match_id", "triggered_team_id", "triggered_player_id"],
    )

    assert signal_project.violations() == [
        f"catalogs/{PLAYER_SIGNAL}.md: DDL signal_instance_id default must hash v1, the "
        "signal_id, and ['match_id', 'triggered_player_id', 'triggered_team_id'] in order"
    ]


def test_row_identity_columns_must_exist_in_ddl(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(MATCH_SIGNAL, ddl_columns=[])

    assert signal_project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: row_identity columns ['triggered_side'] are not in the DDL"
    ]


def test_order_by_must_end_with_signal_instance_id(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(MATCH_SIGNAL, order_by="signal_instance_id, match_id")

    assert signal_project.violations() == [
        f"catalogs/{MATCH_SIGNAL}.md: DDL ORDER BY must end with signal_instance_id"
    ]


def test_order_by_leading_columns_need_not_match_row_identity(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)
    signal_project.add_signal(
        PLAYER_SIGNAL,
        ddl_columns=[*PLAYER_IDENTITY[1:], "triggered_side"],
        order_by="match_id, triggered_side, triggered_player_id, signal_instance_id",
    )

    assert len(signal_project.load()) == 1


def test_every_violation_is_reported_at_once(project: SignalProject) -> None:
    project.write_catalog(MATCH_SIGNAL, _frontmatter(MATCH_SIGNAL, entity="team"))
    project.write_catalog(PLAYER_SIGNAL, _frontmatter(PLAYER_SIGNAL, status="retired"))

    violations = project.violations()

    assert len(violations) == 2
    assert violations[0].startswith(f"catalogs/{MATCH_SIGNAL}.md")
    assert violations[1].startswith(f"catalogs/{PLAYER_SIGNAL}.md")


def test_malformed_frontmatter_is_a_violation(project: SignalProject) -> None:
    (project.catalog_dir / f"{MATCH_SIGNAL}.md").write_text("# no frontmatter\n")
    (project.catalog_dir / f"{PLAYER_SIGNAL}.md").write_text("---\nsignal_id: [unclosed\n---\n")

    violations = project.violations()

    assert violations[0] == f"catalogs/{MATCH_SIGNAL}.md: missing YAML frontmatter start '---'"
    assert violations[1].startswith(f"catalogs/{PLAYER_SIGNAL}.md: frontmatter is not valid YAML")


def test_empty_catalog_directory_is_a_violation(tmp_path: Path) -> None:
    signal_project = SignalProject(tmp_path)

    assert signal_project.violations() == ["catalogs: no catalogs"]


def test_select_excludes_deprecated_unless_asked(project: SignalProject) -> None:
    project.write_catalog(PLAYER_SIGNAL, _frontmatter(PLAYER_SIGNAL, status="deprecated"))
    catalog = project.load()

    assert [definition.signal_id for definition in catalog.active()] == [MATCH_SIGNAL]
    assert [definition.signal_id for definition in catalog.select(entity="player")] == []
    assert [
        definition.signal_id
        for definition in catalog.select(entity="player", include_deprecated=True)
    ] == [PLAYER_SIGNAL]


@pytest.mark.parametrize("family", ["shooting", "shooting_goals"])
def test_select_by_family_accepts_family_or_family_subfamily(
    project: SignalProject, family: str
) -> None:
    catalog = project.load()

    assert [definition.signal_id for definition in catalog.select(family=family)] == [
        MATCH_SIGNAL,
        PLAYER_SIGNAL,
    ]
    assert catalog.select(family="goals") == ()


def test_unknown_signal_id_raises_key_error(project: SignalProject) -> None:
    with pytest.raises(KeyError, match="sig_match_shooting_goals_missing"):
        project.load().get("sig_match_shooting_goals_missing")


def test_signal_instance_id_expression_with_alias(project: SignalProject) -> None:
    definition = project.load().get(MATCH_SIGNAL)

    assert signal_instance_id_expression(definition, "sig") == (
        f"lower(hex(SHA256(concat('v1', '|', '{MATCH_SIGNAL}', '|', "
        "coalesce(toString(sig.match_id), ''), '|', "
        "coalesce(toString(sig.triggered_side), '')))))"
    )


def test_index_lists_every_signal_including_deprecated(project: SignalProject) -> None:
    project.write_catalog(PLAYER_SIGNAL, _frontmatter(PLAYER_SIGNAL, status="deprecated"))

    index = render_signal_index(project.load())

    assert index.splitlines()[2] == (
        f"| `{MATCH_SIGNAL}` | match | shooting | goals | `match_team` | active | "
        f"[{MATCH_SIGNAL}.md]({MATCH_SIGNAL}.md) |"
    )
    assert f"| `{PLAYER_SIGNAL}` | player | shooting | goals | `match_player` | deprecated |" in (
        index
    )


def test_replace_index_requires_markers(project: SignalProject) -> None:
    catalog = project.load()
    replaced = replace_signal_index(
        f"intro\n{INDEX_START_MARKER}\nold\n{INDEX_END_MARKER}\n", catalog
    )

    assert replaced == (
        f"intro\n{INDEX_START_MARKER}\n{render_signal_index(catalog)}\n{INDEX_END_MARKER}\n"
    )
    with pytest.raises(ValueError, match="signal-index:start"):
        replace_signal_index("no markers", catalog)


def test_check_command_fails_on_stale_index_and_writes_it(
    project: SignalProject, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        check_signal_catalogs,
        "load_signal_catalog",
        lambda catalog_dir: load_signal_catalog(catalog_dir, project_root=project.root),
    )
    arguments = ["--catalog-dir", str(project.catalog_dir)]

    assert check_signal_catalogs.main(arguments) == 1
    assert check_signal_catalogs.main([*arguments, "--write-index"]) == 0
    assert check_signal_catalogs.main(arguments) == 0
    assert MATCH_SIGNAL in (project.catalog_dir / INDEX_FILE_NAME).read_text(encoding="utf-8")


def test_check_command_fails_on_invalid_catalog(
    project: SignalProject, monkeypatch: pytest.MonkeyPatch
) -> None:
    project.write_catalog(MATCH_SIGNAL, _frontmatter(MATCH_SIGNAL, entity="team"))
    monkeypatch.setattr(
        check_signal_catalogs,
        "load_signal_catalog",
        lambda catalog_dir: load_signal_catalog(catalog_dir, project_root=project.root),
    )

    assert (
        check_signal_catalogs.main(["--catalog-dir", str(project.catalog_dir), "--write-index"])
        == 1
    )


def test_column_default_expression_reads_normalized_default(project: SignalProject) -> None:
    ddl_file = project.root / "clickhouse/gold/ddl/signals/match" / f"{MATCH_SIGNAL}.sql"
    table = parse_expected_tables([ddl_file])[0]

    assert column_default_expression(table, "inserted_at") == "now()"
    assert column_default_expression(table, "match_id") is None
    assert column_default_expression(table, "signal_instance_id").startswith(
        "lower(hex(SHA256(concat('v1','|',"
    )


def test_repository_signal_catalog_is_valid() -> None:
    catalog = load_signal_catalog()

    assert len(catalog) == 344
    assert {definition.entity for definition in catalog} == {"match", "team", "player"}
    assert all(definition.signal_id.split("_")[1] == definition.entity for definition in catalog)


def test_repository_signal_index_is_current() -> None:
    index_text = (SIGNAL_CATALOG_DIR / INDEX_FILE_NAME).read_text(encoding="utf-8")

    assert replace_signal_index(index_text, load_signal_catalog()) == index_text
