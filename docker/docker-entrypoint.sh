#!/bin/bash
# Docker entrypoint script for the DepthMark containers.
#
# Warehouse setup is an explicit operator step and never runs on container
# start (ADR 0026). Run it once, and after setup DDL changes, with:
#   docker compose exec depthmark-scraper python scripts/orchestration/setup_fotmob_warehouse.py
# Compose already waits for ClickHouse to report healthy before starting the
# scraper, so the entrypoint only executes the requested command.

set -e

exec "$@"
