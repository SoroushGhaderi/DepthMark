"""Prioritize discovered Oddspedia events against the Silver reference."""

from src.oddspedia.scraping.entrypoints import prioritize_main as main

if __name__ == "__main__":
    raise SystemExit(main())
