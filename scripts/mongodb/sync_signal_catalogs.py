"""Mirror validated signal catalogs into the MongoDB signals collection."""

from src.fotmob.commands.sync_signal_catalogs import main

if __name__ == "__main__":
    raise SystemExit(main())
