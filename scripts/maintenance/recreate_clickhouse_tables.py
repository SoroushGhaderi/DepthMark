"""Explicit Table Recreation: drop selected warehouse tables and recreate them empty."""

from src.warehouse.commands.recreate_tables import main

if __name__ == "__main__":
    raise SystemExit(main())
