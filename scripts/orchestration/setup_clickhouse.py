"""Create the FotMob bronze, silver, and gold ClickHouse layers."""

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from clickhouse_setup_common import LAYER_ORDER, run_clickhouse_layers


def main(argv: Sequence[str] | None = None) -> int:
    """Create each FotMob warehouse layer in dependency order."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    return run_clickhouse_layers(LAYER_ORDER)


if __name__ == "__main__":
    print(
        "Warning: scripts/orchestration/setup_clickhouse.py is deprecated; use "
        "scripts/orchestration/setup_fotmob_warehouse.py instead.",
        file=sys.stderr,
    )
    sys.exit(main())
