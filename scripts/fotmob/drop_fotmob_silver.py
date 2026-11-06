"""Drop every table of one FotMob warehouse layer (bronze or silver) in ClickHouse."""

from src.warehouse.commands.drop_tables import main

if __name__ == "__main__":
    raise SystemExit(main(layer="silver"))
