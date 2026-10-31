"""Explicit ClickHouse table optimization for operator-invoked maintenance."""

from src.warehouse.commands.optimize import main

if __name__ == "__main__":
    raise SystemExit(main())
