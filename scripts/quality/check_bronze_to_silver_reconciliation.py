"""Backward-compatible entry point for the unified warehouse quality workflow."""

from src.warehouse.commands.check_reconciliation import main

if __name__ == "__main__":
    raise SystemExit(main())
