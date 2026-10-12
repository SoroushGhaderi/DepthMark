"""Shared test doubles for the FotMob Bronze loader, removal, and rebuild tests."""

import copy
import gzip
import io
import json
import re
import tarfile
from pathlib import Path

from src.fotmob.bronze.source import get_matches_dir

FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "fotmob" / "match_payload.json"
DATE = "20251208"


def load_payload():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


class FakeClickHouse:
    """A tiny in-memory Bronze warehouse answering the calls the Bronze services make."""

    MATCH_ID_FILTER = re.compile(r"WHERE match_id IN \(([^)]*)\)")

    def __init__(self, specs, *, fail_insert=None, missing=(), fail_truncate=False):
        self.specs = specs
        self.fail_insert = fail_insert
        self.missing = set(missing)
        self.fail_truncate = fail_truncate
        self.rows = {table: [] for table in specs}
        self.stage = {}
        self.stage_source = {}
        self.has_staging_database = True
        self.inserted = {}
        self.truncated = []
        self.statements = []

    @classmethod
    def _match_ids(cls, query):
        found = cls.MATCH_ID_FILTER.search(query)
        return {int(value) for value in found.group(1).split(",")} if found else None

    def _table(self, query):
        found = re.search(r"(?:FROM|TABLE) bronze\.(\w+)", query)
        return found.group(1) if found else None

    def execute(self, query, *args, **kwargs):
        self.statements.append(query)
        live = {name: spec for name, spec in self.specs.items() if name not in self.missing}
        match_ids = self._match_ids(query)
        table = self._table(query)
        if "FROM system.columns" in query:
            rows = [
                ("bronze", name, column, kind)
                for name, spec in live.items()
                for column, kind in spec.expected.columns
            ]
        elif "sorting_key" in query:
            rows = [
                ("bronze", name, ", ".join(spec.expected.sorting_key))
                for name, spec in live.items()
            ]
        elif "FROM system.tables" in query:
            rows = [(1,)]
        elif query.startswith("CREATE TABLE warehouse_stage."):
            if not self.has_staging_database:
                raise RuntimeError("Code: 81. Database warehouse_stage does not exist")
            stage, source = re.match(
                r"CREATE TABLE warehouse_stage\.(\w+) AS bronze\.(\w+)", query
            ).groups()
            self.stage[stage] = []
            self.stage_source[stage] = source
            rows = []
        elif query.startswith("EXCHANGE TABLES"):
            table, stage = re.match(
                r"EXCHANGE TABLES bronze\.(\w+) AND warehouse_stage\.(\w+)", query
            ).groups()
            self.rows[table], self.stage[stage] = self.stage[stage], self.rows[table]
            rows = []
        elif query.startswith("DROP TABLE IF EXISTS warehouse_stage."):
            self.stage.pop(query.rsplit(".", 1)[1], None)
            rows = []
        elif query.startswith("ALTER TABLE") and "DELETE" in query:
            self.rows[table] = [r for r in self.rows[table] if r["match_id"] not in match_ids]
            rows = []
        elif "toString(match_date)" in query:
            dates = {
                str(r["match_date"])
                for r in self.rows["match_reference"]
                if r["match_id"] in match_ids
            }
            rows = [(value,) for value in sorted(dates)]
        elif query.startswith("SELECT count()") and match_ids is not None:
            rows = [(sum(1 for r in self.rows[table] if r["match_id"] in match_ids),)]
        elif query.startswith("SELECT count()") and " WHERE " not in query:
            rows = [(len(self.rows[table]),)]
        else:
            rows = [(0,)]
        return type("Result", (), {"result_rows": rows})()

    def insert_dataframe_qualified_table(self, table, frame, database=None):
        if self.fail_insert is not None and self.fail_insert in (
            table,
            self.stage_source.get(table),
        ):
            raise RuntimeError("Code: 53. Type mismatch")
        if database == "warehouse_stage":
            self.stage[table].extend(frame.to_dict("records"))
            return len(frame)
        self.rows[table].extend(frame.to_dict("records"))
        self.inserted.setdefault(table, []).append(frame)
        return len(frame)

    def truncate_table(self, table, database=None):
        if self.fail_truncate:
            raise RuntimeError("Not enough privileges")
        self.truncated.append(table)
        self.rows[table] = []

    def match_rows(self, table, match_id):
        return [r for r in self.rows[table] if r["match_id"] == match_id]


def write_archive(root: Path, payloads, date_str=DATE, corrupt_member=False) -> Path:
    matches_dir = get_matches_dir(root, date_str)
    matches_dir.mkdir(parents=True)
    archive_path = matches_dir / f"{date_str}_matches.tar"
    with tarfile.open(archive_path, "w") as archive:
        for index, payload in enumerate(payloads):
            data = gzip.compress(json.dumps(payload).encode("utf-8"))
            if corrupt_member and index == len(payloads) - 1:
                data = data[:20]
            member = tarfile.TarInfo(f"match_{index}.json.gz")
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
    return archive_path


def second_match(payload):
    other = copy.deepcopy(payload)
    other["data"]["general"]["matchId"] = 4800002
    return other
