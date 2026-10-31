"""Filesystem anchors for the DepthMark source checkout."""

from pathlib import Path

# DepthMark runs from a source checkout (editable install): commands read
# clickhouse/ SQL, config/, catalogs/ and data/ relative to this root.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
