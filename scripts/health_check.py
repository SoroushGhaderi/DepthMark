"""Run system health checks for ClickHouse, storage, and disk space."""

from src.operations.commands.health_check import main

if __name__ == "__main__":
    raise SystemExit(main())
