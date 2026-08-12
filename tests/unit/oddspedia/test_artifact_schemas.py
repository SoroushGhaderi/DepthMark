"""Read-only compatibility tests for real Oddspedia JSON artifacts."""

import json
from pathlib import Path

import jsonschema
import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[3]
SCHEMA_ROOT = PROJECT_ROOT / "schemas" / "oddspedia"
DATA_ROOT = PROJECT_ROOT / "data" / "oddspedia" / "historical"


def _load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _assert_files_match(schema_name: str, pattern: str) -> None:
    schema = _load(SCHEMA_ROOT / schema_name)
    validator = jsonschema.Draft202012Validator(schema)
    paths = sorted(DATA_ROOT.glob(pattern))
    if not paths:
        pytest.skip(f"no local Oddspedia artifacts matched {pattern}")
    for path in paths:
        validator.validate(_load(path))


def test_every_existing_match_link_inventory_matches_the_external_contract():
    _assert_files_match("match_links.schema.json", "daily_listings/*/*/match_links.json")


def test_every_existing_plain_match_payload_matches_the_external_contract():
    _assert_files_match("match_payload.schema.json", "matches/*/*/*.json")


def test_every_existing_manifest_matches_the_external_contract():
    _assert_files_match("scrape_manifest.schema.json", "manifests/*/*/manifest.json")
