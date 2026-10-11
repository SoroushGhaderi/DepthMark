# DepthMark Repository Review

Review date: 2026-10-11
Branch reviewed: `fix/non-destructive-warehouse-setup`
Supersedes: every earlier review under `docs/` (see [Review history](#review-history)).

This is the single current review. It replaces the production-readiness report
and the five architecture reviews that previously lived in `docs/` and
`docs/reviews/`. Resolved findings are recorded once, with the ADR that closed
them; everything open is in [Open findings](#open-findings).

## Summary

DepthMark has two source-isolated medallion pipelines (FotMob and Oddspedia)
with explicit raw contracts and one audited cross-source edge. Every P0 and P1
finding raised since June 2026 is resolved. What remains is automation and
hardening work: no CI, floating dependencies, a lint/type baseline that is not
clean, and a few query-cost and retention decisions.

| Check | Result (2026-10-11) |
| --- | --- |
| `pytest -q` | 334 passed |
| Open P0 | 0 |
| Open P1 | 0 |
| Open P2 | 6 |
| Open P3 | 3 |

## Resolved since the earlier reviews

| Finding | Origin | Resolution |
| --- | --- | --- |
| Setup ran `OPTIMIZE ... FINAL DEDUPLICATE` | 2026-06 readiness review | ADR 0020; compaction is the explicit `optimize_clickhouse.py` command |
| Setup dropped populated Gold tables on every run | 2026-10-02 (P0) | ADR 0026: create-only setup, fail-closed schema drift, explicit Table Recreation |
| Container entrypoint waited on the wrong host and ran setup | 2026-10-02 | ADR 0026: containers no longer run setup |
| Compose defaulted to predictable DB credentials on all interfaces | 2026-10-02 | ADR 0005 update: required secrets, loopback bind |
| Application identity could drop/truncate/optimize | 2026-10-02 | ADR 0029: `warehouse_stage` plus a separate maintenance user |
| Scoped publication not atomic across tables | 2026-08-24, 2026-10-02 | ADR 0028: per-partition publication status; readers fail closed |
| Scheduler profile never ran a scheduler | 2026-10-02 | ADR 0027: external scheduler under `flock -n` |
| Wheel omitted most runtime packages | 2026-10-02 | Package discovery plus a test; editable checkout install is the supported mode |
| No one-command server setup | 2026-10-10 | ADR 0030: `scripts/bootstrap.sh` |
| Pipeline continued after upstream failures | 2026-06 readiness review | Downstream stages gated in daily, monthly, and full-history modes |
| Bronze truncate had no dry-run | 2026-06 readiness review | `--truncate --dry-run` implemented |
| Pytest collection broken from repo root | 2026-06 readiness review | Fixed; root `pytest -q` collects and passes |
| Mixed generic and source-qualified script names; broken CLI aliases | 2026-08-11 | ADR 0024; registry test asserts targets exist |
| Scraping status split across source-specific tools | 2026-08-11 | ADR 0025: `report_scraping.py` |
| Oddspedia artifact writer guessed types and dropped fields; manifests lost future fields | 2026-08-12 | Explicit contracts, unknown-field round trip, 1,055 artifacts validated read-only |
| No bounded date-range interface for Oddspedia | 2026-08-12 | `--start-date/--end-date` across intake, Bronze load, and resolution |
| Oddspedia partial discovery, partial loads, cross-process races | 2026-08-08 | Checksummed inventories, audit gates, date locks, staged Bronze with `published` gate |
| Bronze loader was a 1,300-line script; two config systems | 2026-06 architecture review | ADR 0010 and ADR 0016 |

## Open findings

### P2 — This quarter

1. **No CI or automated gates.** There is no `.github/workflows`, GitLab, or
   Jenkins config. Tests, formatting, SQL parsing, setup idempotence, and secret
   scanning depend on manual runs. Add a PR gate for build/import, Ruff, Black,
   tests, and SQL parsing, then a small ClickHouse integration suite.
2. **No SQL logic or setup-idempotence integration test.** The sentinel-row
   behavior of ADR 0026 and the grant model of ADR 0029 were verified manually
   against a throwaway ClickHouse 24.10. Automate both.
3. **Static quality baseline is not clean and coverage is unenforced.** The
   2026-10-02 run reported Ruff 162 errors, Black 33 files, mypy 205 errors, and
   52% coverage with no `fail-under`. These figures were not re-measured on
   2026-10-11. Stage the cleanup: typing and import paths, then formatting and
   lint, then targeted coverage for ingestion, staging, and publication.
4. **Dependencies are floating.** `pyproject.toml` and `requirements.txt` use
   `>=` and the image installs latest-at-build. Add a hashed lock file and build
   from it.
5. **`SELECT *` and repeated `FINAL` in production paths.** `SELECT *` remains in
   two Gold signal SQL files, `src/warehouse/scoped_replace.py`,
   `src/warehouse/quality.py`, and `src/oddspedia/bronze/loader.py`. Replace with
   explicit projections; reserve `FINAL` for controlled reconciliation.
6. **Source protocols drift from implementations.** `src/core/interfaces.py`
   declares methods the FotMob classes do not implement (the cause of the mypy
   abstract-class errors). Define interfaces around real workflow behavior or
   drop the inheritance.

### P3 — Nice to have

7. **Retention is implicit.** No ClickHouse DDL declares a TTL. Bronze files are
   retained indefinitely by ADR 0012; decide and document the warehouse policy.
8. **Subprocess and query timeouts.** Not re-verified on 2026-10-11. The
   2026-08-24 review found the orchestrator's subprocesses had no timeout or
   process-group cancellation and queries had no shared query ID or retry
   policy. Confirm and, if still true, add a bounded run controller.
9. **Large Oddspedia intake modules.** `cli.py`, `match_scraper.py`, and
   `match_collector.py` were 2,100, 3,500, and 1,800 lines at review time.
   Split along the inventory → scrape → audit → manifest workflow only when the
   next Oddspedia change touches them.

### Deliberately open (scope, not defects)

- Oddspedia Silver entities beyond `silver.oddspedia_match_resolution`, and all
  Oddspedia Gold outputs, are follow-up work under ADR 0023.
- Commits to Silver/Gold remain table by table; ADR 0028 makes the mixed window
  durable and visible rather than eliminating it.
- Date-scoped Silver/Gold runs still compute full-history context. Reusable
  date/season bases are a performance option, not a correctness issue.
- Source folder migration to `scripts/fotmob` and `scripts/oddspedia` was
  considered in the 2026-08-11 review and deferred (high migration cost).
- Gold signal catalogs generating DDL identity checks was proposed and not
  scheduled.
- FotMob Bronze admission fail-closed behavior (zero-row tables treated as
  success) was raised on 2026-08-24; it was not re-verified here.

## Verified strengths

- Source isolation is explicit and tested; no generic provider framework.
- Setup SQL is create-only and a unit test rejects `DROP`, `ALTER`, `TRUNCATE`,
  and `RENAME`.
- Oddspedia intake has checksummed inventories, audit gates, date locks, and a
  `published` gate before resolution.
- No hardcoded credentials in tracked files; `.env` and `credentials.json` are
  ignored.

## Remediation order

1. CI gate with tests, Ruff/Black, SQL parsing (finding 1).
2. Setup-idempotence and grant integration tests (finding 2).
3. Lock file and pinned image build (finding 4).
4. Remove `SELECT *` (finding 5), then clean typing and protocols (findings 3, 6).
5. Retention, timeouts, and Oddspedia module splits as separate decisions
   (findings 7–9).

## Review history

The following documents were merged into this file and removed. They remain
available in git history.

| Removed file | Date | Subject |
| --- | --- | --- |
| `docs/PRODUCTION_READINESS_REVIEW.md` | 2026-06 to 2026-10-10 | Data-engineering production readiness |
| `docs/reviews/architecture-review.html` | 2026-06-15 | Source pipelines, Bronze service, config, tests |
| `docs/reviews/architecture-review-depthmark-20260811.html` | 2026-08-11 | Script naming |
| `docs/reviews/architecture-review-oddspedia-artifacts-20260812.html` | 2026-08-12 | Oddspedia artifacts and manifests |
| `docs/architecture-review-depthmark-20260824.html` | 2026-08-24 | Publication module, ingestion, run control |
| `docs/reviews/architecture-review-depthmark-20261002.html` | 2026-10-02 | Whole-repository review |
