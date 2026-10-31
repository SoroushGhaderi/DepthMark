"""Run discovery, prioritization, and scraping in order."""

from src.oddspedia.scraping.entrypoints import run_main as main

if __name__ == "__main__":
    raise SystemExit(main())
