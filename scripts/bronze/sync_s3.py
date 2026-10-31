"""Upload or download FotMob Bronze artifacts independently of scraping."""

from src.fotmob.commands.sync_s3 import main

if __name__ == "__main__":
    raise SystemExit(main())
