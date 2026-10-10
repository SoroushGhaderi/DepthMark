# ADR 0030: Automate Server Bootstrap

## Status

Accepted

## Context

Bringing DepthMark up on a new server took a hand-run sequence: copy and edit
`.env`, start Compose, run two warehouse setups, create MongoDB indexes, sync
signal catalogs, and write a crontab with server-specific paths, GNU `date`
arithmetic, and `flock`. ADR 0005 also declared the tracked Compose file a
local-development manifest, so there was no supported server deployment at
all. Each manual step was a chance to skip setup, reuse a placeholder password,
or install an overlapping schedule.

The project owner's requirement is that a new server is initialized by running
fixed commands, with nothing to customize by hand.

## Decision

1. The tracked `docker-compose.yml` is the supported deployment for servers and
   local development. Mode is selected through `.env`, not separate manifests.
2. `scripts/bootstrap.sh` is the single initialization and upgrade command. It
   is idempotent and fails on the first failing step:
   - creates `.env` from `.env.example`, adds keys a newer template introduced,
     generates the ClickHouse application, ClickHouse maintenance, and MongoDB
     passwords only when they are missing or placeholders, writes exported
     external secrets (`FOTMOB_X_MAS_TOKEN`, `TELEGRAM_*`, `S3_*`), sets
     `DEPTHMARK_ENV` (`production`, or `local` with `--local`) and
     `DEPTHMARK_UID`, and restricts `.env` to mode `600`;
   - creates `data/`, `logs/`, and an empty `credentials.json`, which Compose
     bind-mounts (Docker would otherwise create root-owned directories);
   - builds the image, starts the stack, waits for healthy databases, runs
     FotMob and Oddspedia warehouse setup, MongoDB index setup, the signal
     catalog sync, and the health check inside the scraper container;
   - installs the schedule unless `--no-schedule` is given.
3. The scraper image is built with the host user's UID (`APP_UID` from
   `DEPTHMARK_UID`) so mounted `data/` and `logs/` stay writable.
4. `scripts/install_schedule.sh` writes one marked crontab block per checkout
   and replaces it on every run. Its jobs call
   `scripts/orchestration/run_scheduled_job.py` inside the container, which
   computes the job's date and holds a non-blocking lock under
   `data/locks/scheduled/`. This replaces the host `flock` and `date` rule in
   ADR 0027.
5. Real values already in `.env` are never replaced, because the ClickHouse
   and MongoDB volumes keep the credentials they were initialized with.

## Consequences

A new server needs Docker, a checkout, and
`FOTMOB_X_MAS_TOKEN=<token> scripts/bootstrap.sh`. Upgrades are
`git pull && scripts/bootstrap.sh`; schema drift still stops setup until an
operator runs Table Recreation (ADR 0026).

Generated passwords exist only in the server's `.env`, which must be backed up
with the data volumes. Rotating the ClickHouse application password is an
`.env` edit followed by a rerun of the bootstrap, which resets it; rotating
the MongoDB root password needs a manual MongoDB user update.

Running the bootstrap without `--local` on a development machine switches it
to production checks, which reject local-default passwords. The bootstrap
modifies the invoking user's crontab by default.
