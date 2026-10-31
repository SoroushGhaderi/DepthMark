"""Validate signal catalogs against their SQL and DDL, and keep the index current."""

from src.fotmob.commands.check_signal_catalogs import main

if __name__ == "__main__":
    raise SystemExit(main())
