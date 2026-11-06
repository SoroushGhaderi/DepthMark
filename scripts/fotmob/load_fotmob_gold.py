"""Run scope-aware FotMob Gold orchestration in ClickHouse."""

from src.fotmob.commands.load_gold import main

if __name__ == "__main__":
    raise SystemExit(main())
