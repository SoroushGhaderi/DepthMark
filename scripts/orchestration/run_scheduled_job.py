"""Run one recurring DepthMark job with its own dates and overlap lock (ADR 0030)."""

from src.operations.commands.run_scheduled_job import main

if __name__ == "__main__":
    raise SystemExit(main())
