# ADR 0027: Use an External Scheduler

## Status

Accepted

## Context

The tracked Compose file had an optional `scheduler` profile. It mounted a
`./crontab` file that does not exist, never started a cron process, did not
mount the `clickhouse/` SQL tree that Silver and Gold loads need, and ran the
image default `python -m src.cli --help`. Starting it produced a container that
scheduled nothing, while the docs implied scheduling was handled. The
2026-10-02 review rated this P1.

The options were to make the profile real (a tracked schedule, a cron runner in
the image, SQL baked into the image, a FotMob run lock, health checks) or to
keep scheduling outside the repository.

## Decision

DepthMark does not ship a scheduler. The `scheduler` Compose service is
removed. Recurring runs are owned by an external scheduler on the host (cron,
systemd timers, or a deployment platform's job runner) that invokes the
canonical pipeline commands, for example through
`docker compose exec -T depthmark-scraper ...`.

The repository owns the contract the scheduler relies on:

- canonical commands with fail-closed, non-zero exit codes;
- the documented run order and dates: FotMob for yesterday, then Oddspedia for
  the day before, once its FotMob Silver reference window is complete;
- an overlap rule: every scheduled job runs under `flock -n`, in addition to
  Oddspedia's own per-date locks;
- the runbook and example crontab in `docs/data-flow/infrastructure.md`.

## Consequences

The Compose stack no longer contains a misleading service, and there is no
scheduler code, image variant, or schedule file to keep in sync with the
command surface.

Deployments must configure the schedule, its logging, and failure alerting
themselves. FotMob runs rely on the scheduler's `flock` for overlap protection
because the FotMob orchestrator has no process lock of its own.

If DepthMark later needs a self-contained schedule, a new ADR should define the
runner, schedule file, locks, and health behavior together.

## Update (2026-10-10)

ADR 0030 automates this contract. `scripts/install_schedule.sh` (run by
`scripts/bootstrap.sh`) installs the jobs as one marked crontab block, and each
job runs `scripts/orchestration/run_scheduled_job.py` inside the container,
which computes the date and takes a non-blocking lock under
`data/locks/scheduled/`. That replaces the host `flock` and `date` arithmetic
described above; the scheduler is still external to the Compose stack.
