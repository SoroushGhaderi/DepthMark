#!/bin/bash
# Docker entrypoint script for the DepthMark containers.
#
# Warehouse setup is an explicit operator step and never runs on container
# start (ADR 0026). Run it once, and after setup DDL changes, with:
#   docker compose exec depthmark-fotmob-scraper python scripts/fotmob/setup_fotmob_warehouse.py
#   docker compose exec depthmark-oddspedia-scraper python scripts/oddspedia/setup_oddspedia_warehouse.py
# Compose already waits for ClickHouse to report healthy before starting the
# scrapers, so the entrypoint only executes the requested command.

set -e

exec "$@"
