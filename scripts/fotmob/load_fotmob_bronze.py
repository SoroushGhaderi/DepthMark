"""Load raw FotMob bronze files into ClickHouse bronze tables."""

from src.fotmob.commands.load_bronze import main

if __name__ == "__main__":
    raise SystemExit(main())
