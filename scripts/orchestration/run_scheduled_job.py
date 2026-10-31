"""Run one recurring DepthMark job with its own dates and overlap lock (ADR 0030).

The host scheduler installed by ``scripts/install_schedule.sh`` calls this
command inside the scraper container, so cron lines need no date arithmetic,
``flock``, or per-server edits:

    python3 scripts/orchestration/run_scheduled_job.py fotmob-daily
    python3 scripts/orchestration/run_scheduled_job.py oddspedia-daily
    python3 scripts/orchestration/run_scheduled_job.py fotmob-daily --dry-run

Jobs:
    fotmob-daily     FotMob pipeline for yesterday (completed dates only).
    oddspedia-daily  Oddspedia pipeline for two days ago, after the FotMob run
                     has completed the following day's Silver reference window.

A job whose previous run still holds the lock is skipped with exit code 0.
Otherwise the exit code is the canonical command's exit code.
"""

from __future__ import annotations

import argparse
import fcntl
import subprocess
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.common.logging import get_logger

logger = get_logger(__name__)

LOCK_DIR = PROJECT_ROOT / "data" / "locks" / "scheduled"


@dataclass(frozen=True)
class ScheduledJob:
    """A recurring job: its canonical script and how it picks its date."""

    script: str
    target_date: Callable[[], date]
    arguments: Callable[[str], list[str]]


def _local_yesterday() -> date:
    # FotMob Historical scrapes accept only dates before the machine's local date.
    return date.today() - timedelta(days=1)


def _utc_two_days_ago() -> date:
    # Oddspedia uses UTC date boundaries and needs FotMob Silver for the following day.
    return datetime.now(UTC).date() - timedelta(days=2)


JOBS = {
    "fotmob-daily": ScheduledJob(
        script="scripts/orchestration/run_fotmob_pipeline.py",
        target_date=lambda: _local_yesterday(),
        arguments=lambda day: [day],
    ),
    "oddspedia-daily": ScheduledJob(
        script="scripts/oddspedia/run_oddspedia_pipeline.py",
        target_date=lambda: _utc_two_days_ago(),
        arguments=lambda day: ["--date", day, "--silver-reference-window-ready"],
    ),
}


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one recurring DepthMark job")
    parser.add_argument("job", choices=sorted(JOBS), help="Scheduled job to run")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log the command the job would run without taking the lock or running it",
    )
    return parser.parse_args(argv)


def build_command(job_name: str) -> list[str]:
    """Return the canonical command for a job and its computed target date."""
    job = JOBS[job_name]
    day = job.target_date().strftime("%Y%m%d")
    return [sys.executable, str(PROJECT_ROOT / job.script), *job.arguments(day)]


def run(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    command = build_command(args.job)
    if args.dry_run:
        logger.info("Dry-run scheduled job", job=args.job, command=" ".join(command[1:]))
        return 0

    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOCK_DIR / f"{args.job}.lock", "w") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            logger.warning("Scheduled job skipped: previous run still holds the lock", job=args.job)
            return 0
        logger.info("Starting scheduled job", job=args.job, command=" ".join(command[1:]))
        exit_code = subprocess.run(command, cwd=PROJECT_ROOT).returncode
        log = logger.info if exit_code == 0 else logger.error
        log("Scheduled job finished", job=args.job, exit_code=exit_code)
        return exit_code


def main() -> int:
    return run()


if __name__ == "__main__":
    raise SystemExit(main())
