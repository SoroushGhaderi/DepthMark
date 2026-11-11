# ADR 0035: Let Oddspedia Scraping Opt In to S3 Upload

## Status

Accepted on 2026-11-11. Narrows the operational rule that "scraping never
uploads to S3" (stated in `README.md`, `docs/data-flow/bronze.md`,
`docs/data-flow/orchestration.md`, `docs/data-flow/infrastructure.md`, and
`docs/DEVELOPMENT_ARCHITECTURE.md`): S3 upload stays out of every default path,
but an operator may now request it explicitly on an Oddspedia scrape. Follows
[ADR 0021](0021-add-oddspedia-as-source-domain.md) and
[ADR 0034](0034-name-every-surface-after-its-source.md) on source ownership.

## Context

FotMob Bronze has an operator-invoked S3 sync,
`scripts/fotmob/sync_fotmob_s3.py`, that uploads one checksummed `tar.gz` per
completed date to ArvanCloud S3. Scraping and the pipelines never call it, so
S3 availability can never fail a scrape.

Oddspedia artifacts had no S3 path at all. An operator who wanted an off-machine
copy of completed Oddspedia dates had no command for it. The sibling project
OddsHarvest, which copied DepthMark's S3 design, gained an opt-in
`--upload-s3` flag on its pipeline run. The user decided that DepthMark's
Oddspedia scraping may do the same, as long as the upload is explicit.

## Decision

1. `scrape_oddspedia_matches.py` and `run_oddspedia_pipeline.py` accept
   `--upload-s3`. It is off by default. `discover` and `prioritize` reject it.
2. Without the flag nothing changes: no `S3_*` setting is read and no S3 client
   is built.
3. With the flag, the command builds the S3 client before any browser or scrape
   work. Missing or placeholder `S3_ENDPOINT`, `S3_ACCESS_KEY`,
   `S3_SECRET_KEY`, or `S3_BUCKET` values stop the run with exit code 1 and a
   message that names them.
4. After each date's scrape and local compression, the command uploads the date
   only when it is Historical and its manifest is terminally complete: every
   selected match is done or skipped, and none is failed, incomplete, or in
   progress. This is the same rule that triggers local compression. Live and
   incomplete dates are skipped and logged; they are not failures.
5. The upload is Oddspedia-owned (`src/oddspedia/bronze/s3_sync.py`) and reuses
   the shared `src/integrations/s3.py` client and `create_s3_client()` factory.
   There is no second S3 client and no generic provider framework.
6. The object layout mirrors FotMob's: one `tar.gz` per date at
   `{S3_BUCKET}/bronze/oddspedia/YYYYMM/YYYYMMDD.tar.gz` when a bucket name is
   known, otherwise `bronze/oddspedia/YYYYMM/YYYYMMDD.tar.gz`. The archive holds
   the Historical `daily_listings`, `link_priorities`, `manifests`, and
   `matches` directories for that date. Locks and run logs are not included.
   Each object carries its SHA-256 in the `sha256` user metadata.
7. Uploads are idempotent: an existing object under either key is skipped and
   never overwritten.
8. An upload failure never changes or deletes local data. The archive is built
   in a temporary directory. The command logs the failure, finishes the other
   dates, and exits 1. Local files are never deleted after an upload.

## Consequences

- Default scraping, scheduled jobs, and the warehouse pipelines still never
  touch S3, and still need no S3 credentials.
- An operator can back up completed Oddspedia dates in the same bucket as
  FotMob, under a source-owned prefix.
- Re-running a completed date with `--upload-s3` uploads it if it is missing
  remotely, so the flag also works as a backfill.
- Because existing objects are never overwritten, a date that later gains
  payloads from a lower priority tier keeps its first remote archive. Replacing
  it needs a deliberate operator action outside this flag.
- FotMob scraping keeps no upload flag; FotMob transfer stays with
  `sync_fotmob_s3.py`.
- There is no Oddspedia S3 download command yet.
