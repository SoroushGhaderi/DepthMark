#!/usr/bin/env bash
# Install DepthMark's recurring jobs in this user's crontab (ADR 0027, ADR 0030).
#
#   scripts/install_schedule.sh            install or refresh the managed block
#   scripts/install_schedule.sh --remove   remove the managed block
#
# The block is keyed by this checkout's path and replaced on every run, so
# rerunning never duplicates jobs. Each job runs
# scripts/orchestration/run_scheduled_job.py inside the scraper container,
# which computes its own date and takes its own overlap lock. Times use the
# host's local clock.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOVE=0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  "") ;;
  --remove) REMOVE=1 ;;
  -h | --help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "Unknown option: $1" ;;
esac

case "$ROOT" in
  *"'"*) die "The checkout path must not contain a single quote: $ROOT" ;;
esac
command -v crontab > /dev/null || die "crontab is required to install the schedule."

BEGIN_MARK="# >>> depthmark schedule: $ROOT >>>"
END_MARK="# <<< depthmark schedule: $ROOT <<<"

existing="$(crontab -l 2> /dev/null || true)"
without_block="$(printf '%s\n' "$existing" | BEGIN_MARK="$BEGIN_MARK" END_MARK="$END_MARK" awk '
  $0 == ENVIRON["BEGIN_MARK"] { skipping = 1; next }
  $0 == ENVIRON["END_MARK"] { skipping = 0; next }
  !skipping { print }')"

if [ "$REMOVE" = 1 ]; then
  printf '%s\n' "$without_block" | crontab -
  echo "Removed the DepthMark schedule for $ROOT"
  exit 0
fi

DOCKER="$(command -v docker)" || die "Docker is required to install the schedule."
mkdir -p "$ROOT/logs/scheduler"

job_line() { # MINUTE HOUR JOB
  printf "%s %s * * * cd '%s' && '%s' compose exec -T depthmark-scraper python3 scripts/orchestration/run_scheduled_job.py %s >> '%s/logs/scheduler/%s.log' 2>&1" \
    "$1" "$2" "$ROOT" "$DOCKER" "$3" "$ROOT" "$3"
}

{
  if [ -n "$without_block" ]; then
    printf '%s\n\n' "$without_block"
  fi
  printf '%s\n' "$BEGIN_MARK"
  printf '%s\n' "# FotMob: yesterday through Bronze, Silver, and Gold."
  job_line 0 3 fotmob-daily
  printf '\n%s\n' "# Oddspedia: two days ago, after its FotMob Silver window is complete."
  job_line 0 5 oddspedia-daily
  printf '\n%s\n' "$END_MARK"
} | crontab -

echo "Installed the DepthMark schedule for $ROOT:"
echo "  03:00 fotmob-daily, 05:00 oddspedia-daily (logs in logs/scheduler/)"
