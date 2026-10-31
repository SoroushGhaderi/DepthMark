"""Create the FotMob bronze, silver, and gold ClickHouse layers."""

import argparse
from collections.abc import Sequence

from src.warehouse.setup import LAYER_ORDER, run_clickhouse_layers


def main(argv: Sequence[str] | None = None) -> int:
    """Create each FotMob warehouse layer in dependency order."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    return run_clickhouse_layers(LAYER_ORDER)


if __name__ == "__main__":
    raise SystemExit(main())
