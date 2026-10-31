"""FotMob warehouse pipeline: scrape, Bronze load, Silver, and Gold for one scope.

The pipeline is built as data before anything runs. :func:`build_plan` turns a
:class:`RunScope` and the selected stages into chains of phases; :func:`run_plan`
executes them, running a phase only when every earlier phase of its chain
succeeded. Each step is a subprocess call to the stage's script (ADR 0002),
bounded by a timeout and cancelled as a whole process group.

- A date or range runs one chain per date: scrape, load, Silver, Gold.
- A month scrapes every date, then loads, builds Silver, and builds Gold once
  for the month; any failed scrape stops the month.
- Full history skips scraping and runs the warehouse stages with
  ``--full-history``.

Usage:
    python3 scripts/orchestration/run_fotmob_pipeline.py 20251113
    python3 scripts/orchestration/run_fotmob_pipeline.py --date 20251113
    python3 scripts/orchestration/run_fotmob_pipeline.py --start-date 20251101 --end-date 20251107
    python3 scripts/orchestration/run_fotmob_pipeline.py --month 202511
    python3 scripts/orchestration/run_fotmob_pipeline.py --full-history
    python3 scripts/orchestration/run_fotmob_pipeline.py 20251113 --silver-only
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field

from src.common.deprecation import warn_deprecated
from src.common.logging import get_logger, setup_logging
from src.common.paths import PROJECT_ROOT
from src.common.run_scope import RunScope, ScopeError
from src.fotmob.commands.support import format_elapsed_time
from src.integrations.telegram import ErrorAlertData, TelegramClient

logger = get_logger("pipeline")

# A step that runs longer than this is cancelled (0 disables the limit).
DEFAULT_STAGE_TIMEOUT_MINUTES = 360
# Grace period between SIGTERM and SIGKILL when cancelling a step.
CANCEL_GRACE_SECONDS = 30
TIMEOUT_EXIT_CODE = 124


@dataclass(frozen=True)
class Stage:
    """One pipeline stage and the script that runs it."""

    key: str
    label: str
    script: str


SCRAPE = Stage("scrape", "FotMob Bronze scrape", "scripts/bronze/scrape_fotmob.py")
BRONZE = Stage("bronze", "Bronze load", "scripts/bronze/load_fotmob_bronze.py")
SILVER = Stage("silver", "Silver", "scripts/silver/load_fotmob_silver.py")
GOLD = Stage("gold", "Gold", "scripts/gold/load_fotmob_gold.py")
STAGES: tuple[Stage, ...] = (SCRAPE, BRONZE, SILVER, GOLD)
WAREHOUSE_STAGES: tuple[Stage, ...] = (BRONZE, SILVER, GOLD)


@dataclass(frozen=True)
class PipelineOptions:
    """Which stages run and the flags they receive."""

    stages: frozenset[str] = frozenset(stage.key for stage in STAGES)
    force: bool = False
    debug: bool = False
    timeout_seconds: float | None = DEFAULT_STAGE_TIMEOUT_MINUTES * 60


@dataclass(frozen=True)
class Step:
    """One script invocation for one stage and scope label."""

    stage: Stage
    scope_label: str
    argv: tuple[str, ...]

    @property
    def name(self) -> str:
        return f"{self.stage.label} - {self.scope_label}"


# A chain is a list of phases; a phase runs only if every earlier phase succeeded.
Phase = list[Step]
Chain = list[Phase]


@dataclass
class StepOutcome:
    step: Step
    exit_code: int
    elapsed_seconds: float

    @property
    def success(self) -> bool:
        return self.exit_code == 0


@dataclass
class PipelineReport:
    """What ran, what failed, and which steps were skipped behind a failure."""

    outcomes: list[StepOutcome] = field(default_factory=list)
    skipped: list[Step] = field(default_factory=list)

    @property
    def exit_code(self) -> int:
        return 0 if all(outcome.success for outcome in self.outcomes) else 1


def _step(stage: Stage, scope: RunScope, options: PipelineOptions) -> Step:
    if scope.kind == "full-history":
        argv = ["--full-history"]
    elif scope.kind == "month":
        argv = ["--month", scope.start]
    elif stage is SCRAPE:
        argv = [scope.start]
    else:
        argv = ["--date", scope.start]
    if options.force and stage in (SCRAPE, BRONZE):
        argv.append("--force")
    if options.debug and stage is SCRAPE:
        argv.append("--debug")
    return Step(stage, scope.label, tuple(argv))


def build_plan(scope: RunScope, options: PipelineOptions) -> list[Chain]:
    """Return the chains of phases the pipeline runs for ``scope``. Pure: no I/O."""
    selected = [stage for stage in STAGES if stage.key in options.stages]
    if scope.kind == "full-history":
        warehouse = [stage for stage in selected if stage is not SCRAPE]
        chain = [[_step(stage, scope, options)] for stage in warehouse]
        return [chain] if chain else []
    if scope.kind == "month":
        chain: Chain = []
        if SCRAPE in selected:
            chain.append(
                [_step(SCRAPE, RunScope.for_date(date), options) for date in scope.dates()]
            )
        chain.extend([_step(stage, scope, options)] for stage in selected if stage is not SCRAPE)
        return [chain] if chain else []
    chains = []
    for date in scope.dates():
        chain = [[_step(stage, RunScope.for_date(date), options)] for stage in selected]
        if chain:
            chains.append(chain)
    return chains


StepRunner = Callable[[Step, "float | None"], int]


def run_step_subprocess(step: Step, timeout_seconds: float | None) -> int:
    """Run a step's script in its own process group, cancelling it on timeout."""
    command = [sys.executable, str(PROJECT_ROOT / step.stage.script), *step.argv]
    process = subprocess.Popen(command, cwd=PROJECT_ROOT, start_new_session=True)
    try:
        return process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        logger.error("[ERROR] Step timed out; cancelling it", step=step.name)
        _cancel(process)
        return TIMEOUT_EXIT_CODE
    except KeyboardInterrupt:
        _cancel(process)
        raise


def _cancel(process: subprocess.Popen) -> None:
    """Terminate the step's whole process group, then kill it after a grace period."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=CANCEL_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    except ProcessLookupError:
        pass


def run_plan(
    plan: list[Chain],
    options: PipelineOptions,
    runner: StepRunner = run_step_subprocess,
    on_failure: Callable[[StepOutcome], None] | None = None,
) -> PipelineReport:
    """Run every chain; within a chain, stop at the first phase with a failure."""
    report = PipelineReport()
    for chain in plan:
        for index, phase in enumerate(chain):
            failed = False
            for step in phase:
                logger.info(
                    "Running step", step=step.name, script=step.stage.script, argv=step.argv
                )
                started = time.monotonic()
                outcome = StepOutcome(
                    step, runner(step, options.timeout_seconds), time.monotonic() - started
                )
                report.outcomes.append(outcome)
                if outcome.success:
                    logger.info(
                        "[OK] Step completed",
                        step=step.name,
                        seconds=round(outcome.elapsed_seconds, 1),
                    )
                    continue
                failed = True
                logger.error("[ERROR] Step failed", step=step.name, exit_code=outcome.exit_code)
                if on_failure is not None:
                    on_failure(outcome)
            if failed:
                remaining = [step for later in chain[index + 1 :] for step in later]
                if remaining:
                    logger.error(
                        "Skipping downstream steps after a failure",
                        skipped=[step.name for step in remaining],
                    )
                report.skipped.extend(remaining)
                break
    return report


def send_failure_alert(outcome: StepOutcome) -> None:
    """Send the Telegram alert for one failed step."""
    TelegramClient().render_and_send(
        "error_alert.html.j2",
        ErrorAlertData(
            level="ERROR",
            title=f"Pipeline Step Failed: {outcome.step.name}",
            message=(
                f"Step '{outcome.step.name}' failed with exit code {outcome.exit_code}.\n\n"
                f"Elapsed time: {outcome.elapsed_seconds:.1f}s"
            ),
            context={
                "step_name": outcome.step.name,
                "exit_code": str(outcome.exit_code),
                "elapsed_time": f"{outcome.elapsed_seconds:.1f}s",
                "date": outcome.step.scope_label,
                "error_output": "Check logs for details",
            },
        ),
    )


def log_summary(report: PipelineReport, elapsed_seconds: float) -> None:
    """Log one summary line per stage plus the skipped steps."""
    logger.info("PIPELINE SUMMARY", total_time=format_elapsed_time(elapsed_seconds))
    for stage in STAGES:
        outcomes = [outcome for outcome in report.outcomes if outcome.step.stage is stage]
        if not outcomes:
            continue
        logger.info(
            "Stage results",
            stage=stage.label,
            successful=sum(outcome.success for outcome in outcomes),
            total=len(outcomes),
            failed_scopes=[o.step.scope_label for o in outcomes if not o.success],
            seconds=round(sum(outcome.elapsed_seconds for outcome in outcomes), 1),
        )
    if report.skipped:
        logger.info("Skipped steps", steps=[step.name for step in report.skipped])


def create_argument_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Run the FotMob pipeline: Bronze scrape, Bronze load, Silver, and Gold",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/orchestration/run_fotmob_pipeline.py 20251113
  python3 scripts/orchestration/run_fotmob_pipeline.py --start-date 20251101 --end-date 20251107
  python3 scripts/orchestration/run_fotmob_pipeline.py --month 202511
  python3 scripts/orchestration/run_fotmob_pipeline.py --full-history
  python3 scripts/orchestration/run_fotmob_pipeline.py 20251113 --silver-only
  python3 scripts/orchestration/run_fotmob_pipeline.py 20251113 --skip-bronze --force
        """,
    )
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("date", nargs="?", help="Date to process (YYYYMMDD)")
    scope.add_argument("--single-date", help="Alias for the positional date (YYYYMMDD)")
    scope.add_argument("--date", dest="named_date", help="Date to process (YYYYMMDD)")
    scope.add_argument("--start-date", help="First date of an inclusive range (YYYYMMDD)")
    scope.add_argument("--month", help="Process a whole month (YYYYMM)")
    scope.add_argument(
        "--full-history",
        action="store_true",
        help="Load all Historical Bronze files and rebuild Silver and Gold (no scraping)",
    )
    parser.add_argument("--end-date", help="Last date of the range (YYYYMMDD)")

    only = parser.add_mutually_exclusive_group()
    only.add_argument("--bronze-only", action="store_true", help="Run the Bronze scrape only")
    only.add_argument("--silver-only", action="store_true", help="Run Silver only")
    only.add_argument("--gold-only", action="store_true", help="Run Gold only")
    parser.add_argument("--skip-bronze", action="store_true", help="Skip the Bronze scrape")
    parser.add_argument("--skip-clickhouse", action="store_true", help="Skip the Bronze load")
    parser.add_argument("--skip-silver", action="store_true", help="Skip Silver")
    parser.add_argument("--skip-gold", action="store_true", help="Skip Gold")
    parser.add_argument("--skip-fotmob", action="store_true", help=argparse.SUPPRESS)

    parser.add_argument(
        "--force", action="store_true", help="Re-scrape and reload even if data exists"
    )
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument(
        "--stage-timeout-minutes",
        type=float,
        default=DEFAULT_STAGE_TIMEOUT_MINUTES,
        help=(
            "Cancel any single step that runs longer than this "
            f"(default: {DEFAULT_STAGE_TIMEOUT_MINUTES}; 0 disables)"
        ),
    )
    return parser


def parse_arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse and validate command-line arguments; ``args.scope`` holds the RunScope."""
    parser = create_argument_parser()
    args = parser.parse_args(argv)
    named_date = args.single_date or args.named_date
    if named_date:
        if args.date:
            parser.error("Use either the positional date or a named date selector, not both")
        args.date = named_date
    try:
        args.scope = RunScope.from_args(args)
    except ScopeError as error:
        parser.error(str(error))
    if args.full_history and args.bronze_only:
        parser.error("--full-history cannot use --bronze-only because scraping is excluded")
    if args.stage_timeout_minutes < 0:
        parser.error("--stage-timeout-minutes cannot be negative")
    return args


def options_from_args(args: argparse.Namespace) -> PipelineOptions:
    """Translate the stage flags into the selected stages."""
    if args.bronze_only:
        stages = {SCRAPE.key}
    elif args.silver_only:
        stages = {SILVER.key}
    elif args.gold_only:
        stages = {GOLD.key}
    else:
        skipped = {
            SCRAPE.key: args.skip_bronze,
            BRONZE.key: args.skip_clickhouse,
            SILVER.key: args.skip_silver,
            GOLD.key: args.skip_gold,
        }
        stages = {key for key, skip in skipped.items() if not skip}
    if args.skip_fotmob:
        warn_deprecated("--skip-fotmob", "the --skip-* stage flags (it skips every stage)")
        stages = set()
    timeout = args.stage_timeout_minutes * 60 or None
    return PipelineOptions(
        stages=frozenset(stages), force=args.force, debug=args.debug, timeout_seconds=timeout
    )


def run_pipeline(args: argparse.Namespace, runner: StepRunner = run_step_subprocess) -> int:
    """Plan and run the pipeline for parsed arguments; return the exit code."""
    setup_logging(name="pipeline", log_dir="logs", log_level="DEBUG" if args.debug else "INFO")
    options = options_from_args(args)
    plan = build_plan(args.scope, options)
    logger.info(
        "Starting FotMob pipeline",
        scope=args.scope.label,
        stages=[stage.key for stage in STAGES if stage.key in options.stages],
        steps=sum(len(phase) for chain in plan for phase in chain),
        timeout_seconds=options.timeout_seconds,
    )
    if args.scope.kind == "full-history":
        logger.info("Scraping is intentionally excluded from full-history pipeline mode")
    started = time.monotonic()
    report = run_plan(plan, options, runner=runner, on_failure=send_failure_alert)
    log_summary(report, time.monotonic() - started)
    if report.exit_code == 0:
        logger.info("[OK] Pipeline completed successfully")
    else:
        logger.warning("[WARN] Pipeline completed with failures")
    return report.exit_code


def main(argv: Sequence[str] | None = None) -> int:
    """Run the pipeline with stable CLI-level error handling."""
    try:
        return run_pipeline(parse_arguments(argv))
    except KeyboardInterrupt:
        logger.warning("Pipeline interrupted by user")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
