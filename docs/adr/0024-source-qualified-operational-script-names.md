# ADR 0024: Use Source-Qualified Operational Script Names

## Status

Accepted on 2026-08-12. The status/report portion is amended by
[ADR 0025](0025-unify-scraping-status-and-reports.md).

## Context

DepthMark has two explicit source domains, but its command surface used two
different naming strategies. FotMob combined one source-qualified script with
generic layer and orchestration names such as `load_clickhouse.py` and
`pipeline.py`. Oddspedia relied on its directory for ownership and used phase
names such as `discover_events.py` and `load_bronze.py`.

The package CLI amplified the inconsistency. Its four short FotMob commands
targeted nonexistent files directly under `scripts/`, while its Oddspedia
commands used a different source-first grammar. Existing tests did not verify
that registry targets existed.

The raw contracts and phases are intentionally different. A naming convention
must make ownership discoverable without introducing a generic provider
framework or inventing equivalent phases across sources.

## Decision

Canonical source-owned workflow scripts use:

```text
<verb>_<source>[_<layer-or-entity>].py
```

The equivalent package commands use hyphens. The canonical registry lives in
`src/cli.py`, and contract tests verify its complete mapping and target
existence.

The primary command surface is:

| Workflow | Canonical script | Package command |
| --- | --- | --- |
| FotMob scrape | `scripts/bronze/scrape_fotmob.py` | `scrape-fotmob` |
| FotMob Bronze load | `scripts/bronze/load_fotmob_bronze.py` | `load-fotmob-bronze` |
| FotMob Silver load | `scripts/silver/load_fotmob_silver.py` | `load-fotmob-silver` |
| FotMob Gold load | `scripts/gold/load_fotmob_gold.py` | `load-fotmob-gold` |
| FotMob pipeline | `scripts/orchestration/run_fotmob_pipeline.py` | `run-fotmob-pipeline` |
| FotMob warehouse setup | `scripts/orchestration/setup_fotmob_warehouse.py` | `setup-fotmob-warehouse` |
| Oddspedia discovery | `scripts/oddspedia/discover_oddspedia_events.py` | `discover-oddspedia-events` |
| Oddspedia priority | `scripts/oddspedia/prioritize_oddspedia_events.py` | `prioritize-oddspedia-events` |
| Oddspedia scrape | `scripts/oddspedia/scrape_oddspedia_matches.py` | `scrape-oddspedia-matches` |
| Oddspedia pipeline | `scripts/oddspedia/run_oddspedia_pipeline.py` | `run-oddspedia-pipeline` |
| Cross-source scraping report | `scripts/report_scraping.py` | `report-scraping` |
| Oddspedia warehouse setup | `scripts/oddspedia/setup_oddspedia_warehouse.py` | `setup-oddspedia-warehouse` |
| Oddspedia Bronze load | `scripts/oddspedia/load_oddspedia_bronze.py` | `load-oddspedia-bronze` |
| Oddspedia resolution | `scripts/oddspedia/resolve_oddspedia_events.py` | `resolve-oddspedia-events` |

Source-neutral quality, maintenance, catalog, health, and cross-source
reporting utilities may keep responsibility-based names without a source
token. Reporting selects an explicit source at runtime; this exception does
not make source-owned mutating workflows generic.

Earlier script paths and package commands remain compatibility adapters. Each
adapter must:

1. preserve its arguments and exit code unless a later ADR explicitly changes
   the behavior contract;
2. delegate to the same implementation as the canonical entry point;
3. emit a deprecation warning to stderr naming the canonical replacement; and
4. remain absent from current runbooks, orchestration, and generated guidance.

Adapters are removed in DepthMark 3.0.0 (see the 2026-10-31 update below).

## Consequences

Benefits:

- operators can identify action, source, and owned output from the command;
- FotMob and Oddspedia use one grammar while retaining their real phases;
- the package CLI no longer dispatches to missing files;
- internal orchestration uses canonical paths and cannot produce deprecation
  warnings during normal operation; and
- registry drift has a focused regression test.

Costs:

- both canonical wrappers and compatibility adapters exist during migration;
- direct filesystem discovery shows more entry-point files; and
- command changes require coordinated registry, test, and documentation work.

## Rejected Alternatives

- A generic provider CLI was rejected because FotMob and Oddspedia have
  intentionally isolated contracts and different workflows.
- Moving every source script under new `scripts/fotmob/` and
  `scripts/oddspedia/` hierarchies was deferred. It has a larger path migration
  cost and is not required to make the public command grammar consistent.
- Breaking removal of old paths was rejected because existing automation is
  part of the operational interface.

## Follow-up Constraints

- New source-owned workflow entry points follow the accepted grammar.
- `docs/SCRIPTS_CONTRACT.md`, `scripts/README.md`, package registry tests, and
  runbooks change together with the command surface.
- Source-specific phase differences remain explicit; naming symmetry must not
  become a provider abstraction.

## Update (2026-10-31): removal version

Compatibility scripts and `depthmark` aliases are removed in DepthMark 3.0.0.
`src.common.deprecation.REMOVAL_VERSION` holds that version, and every adapter
prints it through `run_deprecated_script()` or `warn_deprecated()`, so callers
see the deadline. Before the 3.0.0 release, audit downstream automation for
adapter paths; the release removes the adapters and their CLI aliases together.

