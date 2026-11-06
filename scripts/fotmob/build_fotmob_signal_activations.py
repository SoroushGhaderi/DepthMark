"""Build and scope-replace enriched signal activation rows in ClickHouse."""

from src.fotmob.commands.build_signal_activations import main

if __name__ == "__main__":
    raise SystemExit(main())
