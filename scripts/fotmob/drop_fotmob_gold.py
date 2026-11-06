"""Drop FotMob gold scenario and/or signal tables in ClickHouse."""

from src.warehouse.commands.drop_gold import main

if __name__ == "__main__":
    raise SystemExit(main())
