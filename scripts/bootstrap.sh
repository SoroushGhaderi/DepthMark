#!/usr/bin/env bash
# DepthMark one-command bootstrap (ADR 0030).
#
# Brings a new server, or a local machine with --local, to a running and
# initialized DepthMark stack. Safe to rerun, for example after `git pull`.
#
#   scripts/bootstrap.sh                 server: production mode
#   scripts/bootstrap.sh --local         local development mode
#   scripts/bootstrap.sh --no-schedule   do not install the host crontab
#   scripts/bootstrap.sh --env-only      only prepare .env and local files (no Docker)
#
# Steps: .env with generated secrets -> local files -> image build -> stack start
# -> wait for healthy databases -> FotMob and Oddspedia warehouse setup -> MongoDB indexes
# and signal catalogs -> health check -> host schedule.
#
# External secrets cannot be generated. Export any of FOTMOB_X_MAS_TOKEN,
# TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, S3_ACCESS_KEY, or S3_SECRET_KEY before
# running and bootstrap writes them into .env.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="production"
INSTALL_SCHEDULE=1
ENV_ONLY=0
HEALTH_TIMEOUT_SECONDS=300
GENERATED_SECRETS="CLICKHOUSE_PASSWORD CLICKHOUSE_MAINTENANCE_PASSWORD MONGODB_PASSWORD"
PASSED_THROUGH_SECRETS="FOTMOB_X_MAS_TOKEN TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID S3_ACCESS_KEY S3_SECRET_KEY"

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }
step() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --local) MODE="local" ;;
    --no-schedule) INSTALL_SCHEDULE=0 ;;
    --env-only) ENV_ONLY=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

# Value of KEY in a dotenv file (last assignment wins), or empty.
dotenv_get() {
  KEY="$1" awk 'index($0, ENVIRON["KEY"] "=") == 1 { value = substr($0, length(ENVIRON["KEY"]) + 2) } END { print value }' "$2"
}

# Replace KEY in .env, or append it, without interpreting the value.
env_set() {
  local tmp
  tmp="$(mktemp "$ROOT/.env.tmp.XXXXXX")"
  KEY="$1" VALUE="$2" awk '
    index($0, ENVIRON["KEY"] "=") == 1 { if (!done) print ENVIRON["KEY"] "=" ENVIRON["VALUE"]; done = 1; next }
    { print }
    END { if (!done) print ENVIRON["KEY"] "=" ENVIRON["VALUE"] }' .env > "$tmp"
  mv "$tmp" .env
}

is_placeholder() {
  case "$1" in
    "" | your_* | *_here) return 0 ;;
    *) return 1 ;;
  esac
}

generate_secret() { od -An -N24 -tx1 /dev/urandom | tr -d ' \n'; }

prepare_env() {
  local key value
  if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
  fi

  # Add keys introduced by newer versions of .env.example.
  for key in $(grep -E '^[A-Z][A-Z0-9_]*=' .env.example | cut -d= -f1); do
    if ! grep -qE "^${key}=" .env; then
      env_set "$key" "$(dotenv_get "$key" .env.example)"
      echo "Added missing key $key"
    fi
  done

  # Generate database secrets only when they are missing or still placeholders,
  # so existing ClickHouse and MongoDB users keep matching credentials.
  for key in $GENERATED_SECRETS; do
    if is_placeholder "$(dotenv_get "$key" .env)"; then
      env_set "$key" "$(generate_secret)"
      echo "Generated $key"
    fi
  done
  case "$(dotenv_get MONGODB_URI .env)" in
    "" | *your_*)
      env_set MONGODB_URI "mongodb://$(dotenv_get MONGODB_USER .env):$(dotenv_get MONGODB_PASSWORD .env)@$(dotenv_get MONGODB_HOST .env):$(dotenv_get MONGODB_PORT .env)/$(dotenv_get MONGODB_DATABASE .env)?authSource=$(dotenv_get MONGODB_AUTH_SOURCE .env)"
      echo "Set MONGODB_URI from the MongoDB credentials"
      ;;
  esac

  for key in $PASSED_THROUGH_SECRETS; do
    value="$(printenv "$key" || true)"
    if [ -n "$value" ]; then
      env_set "$key" "$value"
      echo "Wrote $key from the environment"
    fi
  done

  env_set DEPTHMARK_ENV "$MODE"
  # Build the image with the host UID so mounted data/ and logs/ stay writable.
  value="$(id -u)"
  [ "$value" = "0" ] && value=1000
  env_set DEPTHMARK_UID "$value"
  chmod 600 .env

  if is_placeholder "$(dotenv_get FOTMOB_X_MAS_TOKEN .env)"; then
    echo "WARNING: FOTMOB_X_MAS_TOKEN is not set; FotMob scraping fails until it is in .env."
  fi
}

wait_healthy() {
  local container="$1" waited=0 status
  while :; do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo missing)"
    [ "$status" = "healthy" ] && return 0
    if [ "$waited" -ge "$HEALTH_TIMEOUT_SECONDS" ]; then
      die "$container is not healthy after ${HEALTH_TIMEOUT_SECONDS}s (status: $status). Inspect: docker compose logs $container"
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

run_in_scraper() { docker compose exec -T depthmark-scraper "$@"; }

# Compose bind-mounts these paths. A missing source would be created by Docker as
# a root-owned directory (credentials.json is a file), so create them first.
prepare_local_files() {
  mkdir -p data logs/scheduler
  if [ -d credentials.json ] && [ -z "$(ls -A credentials.json)" ]; then
    rmdir credentials.json
  fi
  if [ -d credentials.json ]; then
    die "credentials.json is a non-empty directory; remove it and rerun."
  fi
  if [ ! -e credentials.json ]; then
    printf '{"cookies": {}}\n' > credentials.json
    echo "Created an empty credentials.json (scripts/refresh_turnstile.py fills it)"
  fi
  chmod 600 credentials.json
  if [ "$(id -u)" = "0" ]; then
    chown -R 1000:1000 data logs credentials.json
  fi
}

step "Preparing .env ($MODE mode)"
prepare_env
step "Preparing local files"
prepare_local_files
if [ "$ENV_ONLY" = 1 ]; then
  echo "Done: .env and local files are ready."
  exit 0
fi

command -v docker > /dev/null || die "Docker is required: https://docs.docker.com/engine/install/"
docker compose version > /dev/null 2>&1 || die "Docker Compose v2 is required (docker compose)."

step "Building the DepthMark image"
docker compose build

step "Starting the stack"
docker compose up -d

step "Waiting for ClickHouse and MongoDB"
wait_healthy depthmark-clickhouse
wait_healthy depthmark-mongodb

step "Setting up the FotMob warehouse"
run_in_scraper python3 scripts/orchestration/setup_fotmob_warehouse.py

step "Setting up the Oddspedia warehouse"
run_in_scraper python3 scripts/oddspedia/setup_oddspedia_warehouse.py

step "Creating MongoDB indexes"
run_in_scraper python3 scripts/mongodb/init_indexes.py

step "Syncing signal catalogs to MongoDB"
run_in_scraper python3 scripts/mongodb/sync_signal_catalogs.py

step "Running the health check"
run_in_scraper python3 scripts/health_check.py

if [ "$INSTALL_SCHEDULE" = 1 ]; then
  step "Installing the host schedule"
  "$ROOT/scripts/install_schedule.sh"
fi

step "DepthMark is ready ($MODE mode)"
echo "Stack: docker compose ps"
echo "Run a pipeline: docker compose exec depthmark-scraper python3 scripts/orchestration/run_fotmob_pipeline.py --date YYYYMMDD"
