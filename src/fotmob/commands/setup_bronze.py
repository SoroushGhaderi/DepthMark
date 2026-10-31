"""Create the FotMob bronze layer in ClickHouse."""

import argparse
from collections.abc import Sequence

from src.warehouse.setup import run_clickhouse_layer_setup


def main(argv: Sequence[str] | None = None) -> int:
    """Create the FotMob bronze layer in ClickHouse."""
    argparse.ArgumentParser(description=main.__doc__).parse_args(argv)
    return run_clickhouse_layer_setup("bronze")


if __name__ == "__main__":
    raise SystemExit(main())
