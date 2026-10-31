"""Run unified, read-only warehouse data-quality checks."""

from src.warehouse.commands.check_data_quality import main

if __name__ == "__main__":
    raise SystemExit(main())
